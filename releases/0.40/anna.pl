#!/usr/bin/perl
use strict;
use warnings;

## Anna^ IRC Bot

# Version 0.30. Copyright (C) 2006-2007 Anders Ossowicki <and@vmn.dk>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Anna^ is a versatile IRC bot written in perl. Utilizing POE along with the 
# IRC extension, Anna^ has a multitude of functions, including the ability to 
# save small notes, quotes, haikus and more. She can also interact with various
# websites, like google and bash.org. For more information, please see the 
# included documentation, or read the comments in this file.

# The name Anna^ comes from the horrible song, 'Boten Anna' by 
# BassHunter. The correct name of the bot (according to the music video
# is Anna^, and this is the name the bot will try to connect with. If 
# that fails, she will try a number of variations of the name.
# A number of functions are from an old, unreleased bot named kanako. 
# Kanako was basically just a bunch of perlscripts for the IRC client irssi.

# Questions, comments, general bitching, nude pics and beer goes to 
# Anders Ossowicki <and@vmn.dk>.



## Set basic stuff like vars and the like up

## Trap signals
$SIG{'INT'} = 'ABORT';

## Global vars

# Locales for the script
use constant STARTTIME		=> time;
use constant SCRIPT_NAME 	=> "Anna^ IRC Bot";
use constant SCRIPT_VERSION 	=> "0.40-svn";
use constant SCRIPT_RELEASE 	=> "hu May 17 17:02:20 CEST 2007";
use constant SCRIPT_SYSTEM 	=> `uname -sr`;
use constant DB_VERSION 	=> 2;

# Server information
our %server;
$server{'server'} = "irc.blitzed.org";
$server{'nick'}	= "Anna^";
$server{'username'} = "anna";
$server{'port'} = "6667";
$server{'channel'} = "#frokostgruppen";
$server{'name'} = "Boten Anna";
$server{'nspasswd'} = "";


# Misc settings
our $dbfile = $ENV{'HOME'}."/.anna/anna.db"; # Database location
our $colour = 1; # Print colours to the terminal?
our $silent = 0; # Suppress all but critical output
our $verbose = 0; # Print a lot of information
our $trigger = "!"; # Trigger to prefix commands with
our $debug = 0; # Enable or disable debugging
our @bannedwords; # Array of banned words
our $log = 1; # If true, make anna^ log activity
our $voice_auth = 0; # If true, Anna^ will set +v on users that auths with her
# The following two are used to determine rights to add stuff to Anna^'s 
# database. require_ops takes precedence over require_voice, if both are set to
# true.
#our $require_ops = 0; # Require operator privs for some commands
#our $require_voice = 0; # Require voice for some commands 

## Read config-file (overrides default)
# By making two seperate if-conditions, the values of /etc/anna.conf will be
# overridden _if_, and only if, they are also set in ~/.anna/config. This 
# seems to be the most failsafe method.
if (-r "/etc/anna.conf") {
	parse_configfile("/etc/anna.conf");
}
if (-r $ENV{'HOME'}."/.anna/config") {
	parse_configfile($ENV{'HOME'}."/.anna/config");
} 

# Default values. These doesn't change during runtime
my %default = %server;

## Read command-line arguments (overrides config-file)
use Getopt::Long qw(:config bundling);
GetOptions(
	'verbose|v!' => \$verbose,
	'color!' => \$colour,
	'server|s=s' => \$server{'server'},
	'channel|c=s' => \$server{'channel'},
	'nick|n=s' => \$server{'nick'},
	'name|a=s' => \$server{'name'},
	'username|u=s' => \$server{'username'},
	'port|p=i' => \$server{'port'},
	'nspasswd|P=s' => \$server{'nspasswd'},
	'silent!' => \$silent,
	'debug|d!' => \$debug,
	'dbfile|D=s' => \$dbfile,
	'version|V' => \&version,
	'help|h|?' => sub { usage(0) }
) or die( usage(1) );

# Enable debug stuff
if ($debug) {
	use Data::Dumper;
#	sub POE::Kernel::ASSERT_DEFAULT () { 1 }
	sub POE::Kernel::TRACE_SIGNALS ()  { 1 }
}

# Make verbose override silent
if (($verbose) && ($silent)) {
	$silent = undef;
}

# use the rest of the modules
use File::Copy;
use Term::ReadKey;
use POE;
use POE::Component::IRC;
use DBI;
use LWP::UserAgent;
use HTML::Entities;

## Done with basic setup

# Print welcome
if (!$silent) {
	printf "%s version %s, Copyright (C) 2006 Anders Ossowicki\n", 
		SCRIPT_NAME, SCRIPT_VERSION;
	printf "%s comes with ABSOLUTELY NO WARRANTY; for details, see LICENSE.\n", SCRIPT_NAME;
	printf "This is free software, and you are welcome to redistribute it under certain conditions\n";
}
if ($server{'nspasswd'} ne $default{'nspasswd'}) {
	# nspasswd was changed from commandline, warn user and correct default 
	# values
	print warning("Warning: Typing your NickServ password on the command-line is unsafe!\n") if (!$silent);
	$default{'nspasswd'} = $server{'nspasswd'};
}

# Check for first-run
if (!(-e $dbfile)) {
	# First run
	print "This seems to be the first time you're running Anna^... welcome!\n";
	print "Creating ~/.anna directory to store information... " if ($verbose);
	mkdir $ENV{'HOME'}."/.anna" or die(error("\nFailed to create ~/.anna/ directory. $!"));
	print "done!\n" if ($verbose);
	# Copy database to home
	print "Creating database for Anna^ and filling it... " if ($verbose);
	copy("/usr/local/share/anna/anna.db", $dbfile) or die(error("\nFailed to copy /usr/local/share/anna/anna.db to $dbfile: $!"));
	print "done\n" if ($verbose);
	# Copy config to locale
	print "Creating standard configuration file in ~/.anna/config... " if($verbose);
	copy("/etc/anna.conf", $ENV{'HOME'}."/.anna/config") or die(error("Failed to copy /etc/anna.conf to ~/.anna/config: $!"));
	print "done\n" if ($verbose);
	create_rootuser();
	print "You're all set!\n";
}

print "Creating connection to irc server: $server{'server'}... "  if ($verbose);
my $irc = POE::Component::IRC->spawn(ircname 	=> $server{'name'},
				     port	=> $server{'port'},
				     username	=> $server{'username'},
				     server	=> $server{'server'},
				     nick	=> $server{'nick'},
				     debug	=> $debug
				    ) or die(error("\nCan't create connection to $server{'server'}"));
print "done!\n" if ($verbose);

print "Connecting to SQLite database $dbfile... " if ($verbose);
# Test if database exists
if (!(-e $dbfile)) {
	# We _could_ recover by copying over the default database, but that 
	# might not be what the user wants 
	die(error("\nCouldn't find SQLite database file: ".$dbfile.".\nPlease check that the file exists and is readable\n"));

}
my $dbh = DBI->connect("dbi:SQLite:dbname=".$dbfile, 
			undef, 
			undef, 
			{
				PrintError	=> 0, 
				PrintWarn	=> 0,
				RaiseError	=> 0,
				AutoCommit	=> 1 
			}
		      ) or die(error("Can't connect to SQLite database $dbfile: $DBI::errstr"));
print "done!\n" if ($verbose);

# Syncronize the database (update if version doesn't match script)
sync_db();

# Create POE Session
POE::Session->create(
	inline_states => {
		_start 			=> \&_start,
		_default		=> \&_default,

		connect			=> \&do_connect,
		reconnect		=> \&do_reconnect,
		autoping		=> \&do_autoping,

		irc_error		=> \&on_error,
		irc_socketerr		=> \&on_socketerr,
		irc_disconnected	=> \&on_disconnected,

		irc_001 		=> \&on_connect,
		irc_connected		=> \&on_connected,
		irc_join		=> \&on_join,
#		irc_invite 		=> \&on_invite, # Not handled yet!
		irc_kick		=> \&on_kick,
		irc_mode		=> \&on_mode,
		irc_msg			=> \&on_msg,
		irc_nick		=> \&on_nick,
		irc_kill		=> \&on_kill,
		irc_notice		=> \&on_notice,
		irc_part		=> \&on_part,
		irc_public 		=> \&on_public,
		irc_quit		=> \&on_quit,
		irc_topic		=> \&on_topic,
#		irc_whois		=> \&on_whois, # Not handled yet!
#		irc_whowas		=> \&on_whowas, # Ditto

		irc_324			=> \&on_324,	# channelmodeis
		irc_329			=> \&on_329,	# channelcreate
		irc_332			=> \&on_332,
		irc_333			=> \&on_333,
		irc_353			=> \&on_namreply,

		# CTCP stuff
		irc_ctcp_ping		=> \&on_ctcp_ping,
		irc_ctcpreply_ping	=> \&on_ctcpreply_ping,
		irc_ctcp_version	=> \&on_ctcp_version,
		irc_ctcpreply_version	=> \&on_ctcpreply_version,
		irc_ctcp_time		=> \&on_ctcp_time,
		irc_ctcp_finger		=> \&on_ctcp_finger,

		# Error handling
		irc_401			=> \&err_4xx_default, # nosuchnick
		irc_402			=> \&err_4xx_default, # nosuchserver
		irc_403			=> \&err_4xx_default, # nosuchchannel
		irc_404			=> \&err_4xx_default, # cannotsendtochan
		irc_405			=> \&err_4xx_default, # toomanychannels
		irc_406			=> \&err_4xx_default, # wasnosuchnick
		irc_407			=> \&err_4xx_default, # toomanytargets
		irc_433			=> \&err_nick_taken,  # nicknameinuse

		# Dummy stuff (we don't care about)
		irc_isupport		=> sub { "DUMMY" },
		irc_ping		=> sub { "DUMMY" },
		irc_registered		=> sub { "DUMMY" },
	},
);

## Go for it!
$poe_kernel->run();

# Sayoonara
print "[%s] Closing down... ", print_time() if (!$silent);

# Disconnect from database
$dbh->disconnect or warn("Couldn't disconnect from database: $dbh->errstr") if ($dbh);

print "sayoonara\n" if (!$silent);
exit(0);

## _start
# Called when POE start the session. Take care of connecting, joining and the like
sub _start {
	my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
	irclog('status' => sprintf "-!- Log opened %s", scalar localtime);
	printf "[%s] %s!%s Registering for all events... ", print_time(), 
		colour('-', '94'), colour('-', '94') if (!$silent);
	$irc->yield(register => 'all');
	printf "done\n" if (!$silent);
#	irclog('status' => sprintf "-!- Connecting to irc server: %s:%d...", $server{'server'}, $server{'port'});
#	printf "[%s] %s!%s Connecting to irc server: %s:%d...\n", print_time(), 
#		colour('-', '94'), colour('-', '94'), $server{'server'}, 
#		$server{'port'} if (!$silent);
	# Connect
	$kernel->yield("connect");
}

## _default 
# Handler for all unhandled events. This produces some debug info
# Don't ask about "@{$args->[2]}"
# NOT TO BE INCLUDED IN RELEASES!
sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	
	$_[HEAP]->{seen_traffic} = 1 if ($event =~ /irc_.+/);
	return 0 if (!$debug);	
	# Handle numeric events. These seems to follow a certain syntax.
	if ($event =~ /irc_(\d\d\d)/) {
		irclog('status' => sprintf "(%s) %s", $1, "@{$args->[2]}");
		printf "[%s] ".colour('-', 94)."!".colour('-', 94)." (%s) %s\n",
			print_time(), $1, "@{$args->[2]}" if ($verbose);
		return 0;
	}
	
	my @output = ( "$event: " );
	print "\n\n========================DEBUG INFO===========================\n";
	foreach my $arg ( @$args ) {
		if ( ref($arg) eq 'ARRAY' ) {
			push( @output, "[" . join(" ,", @$arg ) . "]" );
		} else {
			push ( @output, "'$arg'" );
		}
	}
	irclog('status' => join ' ', @output);
	print STDOUT join ' ', @output, "\n";
	print "\n=================WE NOW RETURN TO SCHEDULE===================\n\n";
	return 0;
}

## version
# Print version and exit
sub version {
	printf "%s version %s. Released under the GNU GPL\n", SCRIPT_NAME, SCRIPT_VERSION;
        exit(0);
}

sub create_rootuser {
	print "You will need a root user to control Anna^ from within IRC: Please create one now:\n";
	my $newroot;
	do {
		print "Username: ";
		chomp($newroot = ReadLine(0));
	} while (!$newroot);
	ReadMode(2); # No echo
	my ($newpasswd, $newpasswd2, $i);
	do {
		print "\nPassword mismatch - try again\n" if ($i);
		print "Password: ";
		chomp($newpasswd = ReadLine(0));
		print "\nRetype password: ";
		chomp($newpasswd2 = ReadLine(0));
		$i++;
	} while ($newpasswd ne $newpasswd2);
	ReadMode(1); # Restore
	# The additional \n's are for ReadMode-restoration
	print "\nCreating root user... ";
	my $db_conn = DBI->connect("dbi:SQLite:dbname=".$dbfile,undef,undef, {AutoCommit => 1}) 
			or die("Error - couldn't connect to database $dbfile: $DBI::errstr");
	my $query = "INSERT INTO users (username, password, admin) VALUES (?, ?, 1)";
	my @salt_chars = ('a'..'z','A'..'Z','0'..'9');
	my $salt = $salt_chars[rand(63)] . $salt_chars[rand(63)];
	die error("\nFailed to create root user:".$DBI::errstr."\n") unless $db_conn->do($query, undef, $newroot, crypt($newpasswd, $salt),);
	$db_conn->disconnect() or warn("Error - couldn't disconnect from database $dbfile: $DBI::errstr");
	print "done\n";
}

## sync_db
# Syncronize database with script version
sub sync_db {
	# Check database version. sqlite_master contains a list of all tables.
	my $query = "SELECT * FROM sqlite_master WHERE type = ? AND name = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute("table", "admin");
	if ($sth->fetchrow()) {
		# Okay, admin table exists, fetch database version
		$query = "SELECT * FROM admin WHERE option = ?";
		$sth = $dbh->prepare($query);
		$sth->execute("db_version");
		my @row = $sth->fetchrow();
		return if ($row[1] == DB_VERSION);
		if ($row[1] eq "1") {
			# Upgrades from 1->DB_VERSION
			printf "Upgrading database from version 1 to %s\n", DB_VERSION if ($verbose);
			copy($dbfile, $dbfile."_bak") or die("Failed during backup of database: $!");
			$query = "ALTER TABLE users ADD COLUMN op INT";
			$sth = $dbh->prepare($query);
			$sth->execute();
			$query = "ALTER TABLE users ADD COLUMN admin INT";
			$sth = $dbh->prepare($query);
			$sth->execute();
			create_rootuser();
			$query = "UPDATE admin SET value = ? WHERE option = ?";
			$sth = $dbh->prepare($query);
			$sth->execute('2', 'db_version');
			# Upgrade succeded, delete backup
			unlink($dbfile."_bak") or warn("Failed to unlink database backup: $!");
		}
	} else {
		# System is too old... we only support 0.2x, so update from 
		# that (version 0 -> 2)
		printf "Your database is out of date. Performing updates... \n" if ($verbose);
		# Make a backup copy
		copy($dbfile, $dbfile."_bak") or die("Failed during backup of database: $!");
		# TODO: Inform user of backup copy in case of failure and delete it in case of success

		# Create admin table
		$query = "CREATE TABLE admin (option VARCHAR(255), value VARCHAR(255))";
		$sth = $dbh->prepare($query);
		$sth->execute();

		# Create notes table
		$query = "CREATE TABLE notes (id INTEGER PRIMARY KEY UNIQUE, word TEXT, answer TEXT, author TEXT, date INTEGER)";
		$sth = $dbh->prepare($query);
		$sth->execute();

		# Create orders table
		$query = "CREATE TABLE orders (id INTEGER PRIMARY KEY UNIQUE, key TEXT, baka_order TEXT)";
		$sth = $dbh->prepare($query);
		$sth->execute();
		
		my @order_keys = ("coffee", "chimay", "pepsi", "ice cream", "beer", "peanuts", "ice");
		my @order_values = (
			"hands ## a steaming cup of coffee",
			"hands ## a glass of Chimay",
			"gives ## a can of Star Wars pepsi",
			"gives ## a chocolate ice cream with lots of cherries",
			"slides a beer down the bar counter to ##",
			"slides the bowl of peanuts down the bar counter to ##",
			"slips two ice cubes down ##'s neck",
		);
		$query = "INSERT INTO orders (key, baka_order) VALUES (?, ?)";
		$sth = $dbh->prepare($query);
		# FIXME: We ought to check the tuples... oh well
		$sth->execute_array({ ArrayTupleStatus => undef}, \@order_keys, \@order_values);

		# Create roulette_stats
		$query = "CREATE TABLE roulette_stats (id INTEGER PRIMARY KEY UNIQUE, user TEXT UNIQUE, shots INTEGER, hits INTEGER, deathrate TEXT, liverate TEXT)";
		$sth = $dbh->prepare($query);
		$sth->execute();
		
		# Add op & admin columns to users table
		$query = "ALTER TABLE users ADD COLUMN op INT";
		$sth = $dbh->prepare($query);
		$sth->execute();
		$query = "ALTER TABLE users ADD COLUMN admin INT";
		$sth = $dbh->prepare($query);
		$sth->execute();
		create_rootuser();
		# Update db_version field
		$query = "INSERT INTO admin (option, value) VALUES (?, ?)";
		$sth = $dbh->prepare($query);
		$sth->execute("db_version", 2);
		# Upgrade succeded, delete backup
		unlink($dbfile."_bak") or warn("Failed to unlink database backup: $!");
		printf "Your database is up to speed again!\n" if ($verbose);
	}
}
	
## usage
# Print usage information
sub usage {
my $sig = shift;
print <<EOUSAGE;
Anna^ IRC Bot version @{[ SCRIPT_VERSION ]} 
Usage: anna [OPTION]...

Mandatory arguments to long options are mandatory for short options too.
  -a, --name <name>             set the realname of the bot. This is not the
				nickname!
  -c, --channel <channel>	set the channel to join.
  -s, --server <server>		set the server to connect to.
  -n, --nick <nick>		set the nickname of the bot. Default is Anna^
  -u, --username <user>		set the username of the bot.
  -p, --port <port>		set the port to connect to. Default is 6667
  -P, --nspasswd <passwd>	authorize with nickserv using <passwd> upon
				successful connection.

      --no-color		don't use colours in terminal.
  -D, --dbfile <file>		specify the SQLite3 database-file.
  -v, --verbose			print verbose information.
      --silent			print nothing except critical errors.
  -V, --version			print version information and exit.
  -h, --help			show this message.

Note:   specifying your nickserv password on the command-line is unsafe. You
	should set it in the file instead.
All options listed here can be set within the file or from the configuration 
file as well.

Anna^ IRC Bot is a small and versatile IRC-bot with various functionality.
Please report bugs to and\@vmn.dk

EOUSAGE
	exit($sig);
}

## parse_configfile
# Parse the configfile (given as argument)
sub parse_configfile {
	return if (!($_[0]));
	my $file = shift;
	open(CFG, "<".$file) or die(error("Can't open configuration file ".$file.": ".$!));
	while(<CFG>) {
		next if (/^#/);
		next if (/^\[/);
		next if (/^$/);
		if (/^(.*?)\s*=\s*(.*)$/) {

			# Server part
			$server{'server'} = $2 if (lc($1) eq 'server');
			$server{'port'} = $2 if (lc($1) eq 'port');
			$server{'nick'} = $2 if (lc($1) eq 'nickname');
			$server{'username'} = $2 if (lc($1) eq 'username');
			$server{'channel'} = $2 if (lc($1) eq 'channel');
			$server{'name'} = $2 if (lc($1) eq 'ircname');
			$server{'nspasswd'} = $2 if (lc($1) eq 'nspasswd');

			# Script part
			$dbfile = $2 if (lc($1) eq 'dbfile');
			$colour = $2 if (lc($1) eq 'colour');
			$silent = $2 if (lc($1) eq 'silent');
			$verbose = $2 if (lc($1) eq 'verbose');
			$log = $2 if (lc($1) eq 'log');

			# Bot part
			$trigger = $2 if (lc($1) eq 'trigger');
			@bannedwords = split(' ', $2) if (lc($1) eq 'bannedwords');
			$voice_auth = $2 if (lc($1) eq 'voice_auth');
#			$require_ops = $2 if (lc($1) eq 'require op');
#			$require_voice = $2 if (lc($1) eq 'require voice');
		} else {
			print warning("Syntax error in configuration file (".$file.") line ".$.) unless ($silent);
		}
	}
	close(CFG);
}

## error
# Return the colour-coded error message
sub error {
	my $error = shift;
	# TODO: NOT a good solution, but worksfornow
	return $error if (!-t STDERR);
	return colour($error, "91");
}

## warning
# Return the colour-coded warning
sub warning {
	my $warning = shift;
	return colour($warning, "93");
}

## irclog
# Manages logging. Takes two params, the level of what is being logged and the
# actual message to log. Two level are possible, #channel and 'status'. 
# #channel is for everything said in channel and status is for everything 
# printed in the status window.
sub irclog {
	return if (@_ != 2);
	my ($target, $msg) = @_;

	if (!(-e $ENV{'HOME'}."/.anna/logs")) {
		mkdir $ENV{'HOME'}."/.anna/logs" or die("Can't create directory: $!");
	}
	
	# Use lowercase
	$target = lc($target);

	if ($target eq 'status') {
		open(LOG, ">> $ENV{'HOME'}/.anna/logs/anna.log") or die("Can't open logfile: $!");
		printf LOG "%s %s\n", print_time(), $msg;
		close(LOG);
	} else {
		my $network = $server{'server'};
		$network =~ s/.*\.(.*)\..*/$1/;
		if (!(-e $ENV{'HOME'}."/.anna/logs/".$network)) {
			mkdir $ENV{'HOME'}."/.anna/logs/".$network or die("Can't create directory: $!");
		}
		open(LOG, ">> $ENV{'HOME'}/.anna/logs/$network/$target.log") or die("Can't open logfile: $!");
		printf LOG "%s %s\n", print_time(), $msg;
		close(LOG);
	}
}

## trim
# Trims whitespace from start and end of input
sub trim {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

## ltrim
# Trim leading whitespace from input
sub ltrim {
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}

## rtrim
# Trim trailing whitespace from input
sub rtrim {
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}

## colour
# Colourize a string if $colour is set.
# Takes two arguments, the string to be coloured and the colourcode
sub colour {
	return if ((!$_[1]) or (!$_[0]));
	# Check if stdout is a tty. We probably need something better than this
	return $_[0] if (!-t STDOUT);
	return "\e[" . $_[1] . "m" . $_[0] . "\e[00m" if ($colour);
	return $_[0];
}

## print_time
# This returns a nicely formatted string with the current time. Useful 
# to attach a timestamp to output.
sub print_time {
	my ($sec,$min,$hour,$mday,$mon,$year,
	          $wday,$yday,$isdst) = localtime time;
	if (length($hour) == 1) {
		$hour = "0".$hour;
	}
	if (length($min) == 1) {
		$min = "0".$min;
	}
	if (length($sec) == 1) {
		$sec = "0".$sec;
	}
	
	my $time = $hour . ":" . $min . ":" . $sec;
	return $time;
}

## calc_diff
# Calculates the difference between two unix times and returns
# a string like '15d 23h 42m 15s.'
sub calc_diff {
	my ($when) = @_;
	my $diff = (time() - $when);
	my $day = int($diff / 86400); $diff -= ($day * 86400);
	my $hrs = int($diff / 3600); $diff -= ($hrs * 3600);
	my $min = int($diff / 60); $diff -= ($min * 60);
	my $sec = $diff;
	
	return "${day}d ${hrs}h ${min}m ${sec}s";
}

## escape_shell
# Escape a string for shell output
sub escape_shell {
	my $out = shift;
	return if (!$out);
	$out =~ s/([;<>\*\|`&\$!#\(\)\[\]\{\}:'"])/\\$1/g;
	return $out;
}

## parse_message
# This is where everything take place. Both on_msg (privmsgs) and 
# on_public (privmsgs to channels) send the message along with 
# important information to this subroutine.
# parse_message should return either text to be printed, or nothing.
# The subroutines called from within parse_message may print stuff, but
# should return 'FALSE' in that case, to avoid printing things twice.
sub parse_message {
	my ($kernel, $heap, $from, $to, $msg, $type) = @_;
	my ($nick, $host) = split(/!/, $from);
	# Trim whitespace. This shouldn't give any trouble.
	$msg = trim($msg);
	
	my $out = 'FALSE';

	if ($type eq "public") {
		# Public message (to a channel)
		# This part is meant for things that _only_ should
		# be monitored in channels
		
		# Lastseen part
		if ($msg !~ /^!seen .*$/) {
			bot_lastseen_newmsg($nick, $msg);
		}
		# Only follow karma in channels
		if ($msg =~ /^(.*)(\+\+|\-\-)$/) {
			$out = bot_karma_update($1, $2, $nick);
		}
		foreach (@bannedwords) {
			if ($msg =~ /($_)/i) {
				$irc->yield(kick => $server{'channel'} => $nick => $1);
			}
		}
	} elsif ($type eq "msg") {
		# Private message (p2p)
		# This is meant for things that anna should _only_
		# respond to in private (ie. authentications).
		if ($msg =~ /^(\Q$trigger\E|)auth\s+(.*)$/) {
			$out = bot_auth($2, $from, $heap);
		} elsif ($msg =~ /^(\Q$trigger\E|)register\s+(.*?)\s+(.*)$/) {
			$out = bot_register($2, $3, $from, $heap);
		} elsif ($msg =~ /^(\Q$trigger\E|)op$/i) {
			$out = bot_op($from, $heap);
		} elsif ($msg =~ /^(\Q$trigger\E|)addop\s+(.*)$/) {
			$out = bot_addop($2, $from, $heap);
		} elsif ($msg =~ /^(\Q$trigger\E|)rmop\s+(.*)$/) {
			$out = bot_rmop($2, $from, $heap);
		}
	}
	
	## This part reacts to special words/phrases in the messages
	if ($msg =~ /^\Q$server{'nick'}\E[ :,-].*poke/i) {
		$out = "Do NOT poke the bot!";
		return $out;
	}

	if ($msg =~ /^n., anime$/) {
		$out = $nick . ": get back to work, loser!";
		return $out;
	}
	if ($msg =~ /dumb bot/i) {
		$out = "Stupid human!";
		return $out;
	}
	if ($msg =~ /dance/i) {
		$irc->delay(['ctcp' => $server{'channel'} => 'ACTION dances o//'], 1);
		$irc->delay(['ctcp' => $server{'channel'} => 'ACTION dances \\\\o'], 2);
		$irc->delay(['ctcp' => $server{'channel'} => 'ACTION DANCES \\o/'], 3);
		return;
	}
		
	if ($msg =~ /^\Q$trigger\Edice (\d+d\d+)$/i) {
		$out = bot_dice($1, $nick);
		return $out;
	}
	if ($msg =~ /^(\d+d\d+)$/i) {
		$out = bot_dice($1, $nick);
		return $out;
	}
	
	if ($msg =~ /^\Q$server{'nick'}\E[ :,-]+(.*)\s+or\s+(.*)\?$/) {
		my @rep = ($1,$2);
		return $nick . ": ".$rep[rand scalar @rep]."!";
	}

	if ($msg =~ /^\Q$server{'nick'}\E[ :,-]+.*\?$/) {
		$out = $nick . ": ".bot_answer();
		return $out;
	}

	# Return now, unless there's a trigger
	# In case of a trigger, trim it and parse the remaining message
	return $out if ($msg !~ /^(\Q$trigger\E|\Q$server{'nick'}\E[ :,-]+)/);
	my $cmd = $msg;
	$cmd =~ s/^(\Q$trigger\E|\Q$server{'nick'}\E[ :,-]+\s*)//;

	## Bot commands
	if ($cmd =~ /^mynotes$/) {
		$out = bot_mynotes($nick, $type);
	} elsif ($cmd =~ /^voice(me|)$/) {
		$out = bot_voice($from, $heap);
	} elsif ($cmd =~ /^rstats$/) {
		$out = bot_roulette_stats();
	} elsif ($cmd =~ /^search\s+(.*)$/) {
		$out = bot_search($1);
	} elsif ($cmd =~ /^rot13\s+(.*)$/i) {
		$out = bot_rot13($1);
	} elsif ($cmd =~ /^note(\s+(.*)|)$/i) {
		$out = bot_note($2, $nick);
	} elsif ($cmd =~ /^google\s+(.*)$/i) {
		$out = bot_googlesearch($1);
	} elsif ($cmd =~ /^fortune(\s+.*|)$/i) {
		$out = bot_fortune($1);
	} elsif ($cmd =~ /^karma\s+(.*)$/i) {
		$out = bot_karma($1);
	} elsif ($cmd =~ /^quote$/i) {
		$out = bot_quote();
	} elsif ($cmd =~ /^addquote\s+(.*)$/i) {
		$out = bot_addquote($nick, $1);
	} elsif ($cmd =~ /^bash(\s+(\#|)([0-9]+|random)|)$/i) {
		$out = bot_bash($3);
	} elsif ($cmd =~ /^roulette$/i) {
		$out = bot_roulette($nick);
	} elsif ($cmd =~/^reload$/i) {
		$out = bot_reload();
	} elsif ($cmd =~ /^question\s+.*$/i) {
		$out = $nick . ": ".bot_answer();
	} elsif ($cmd =~ /^addanswer\s+(.*)$/i) {
		$out = bot_addanswer($1, $nick);
	} elsif ($cmd =~ /^up(time|)$/i) {
		$out = bot_uptime();
	} elsif ($cmd =~ /^lart\s+(.*)$/i) {
		$out = bot_lart($nick, $1);
	} elsif ($cmd =~ /^addlart\s+(.*)$/i) {
		$out = bot_addlart($1);
	} elsif ($cmd =~ /^haiku$/i) {
		$out = bot_haiku();
	} elsif ($cmd =~ /^addhaiku\s+(.*)$/i) {
		$out = bot_addhaiku($1, $nick);
	} elsif ($cmd =~ /^addorder\s+(.*)$/i) {
		$out = bot_addorder($1, $nick);
	} elsif ($cmd =~ /^order\s+(.*)$/i) {
		$out = bot_order($nick, $1);
	} elsif ($cmd =~ /^seen\s+(.*)$/i) {
		$out = bot_lastseen($nick, $1, $type);
	} elsif ($cmd =~ /^meh$/i) {
		$out = "meh~";
	} elsif ($cmd =~ /^op$/i) {
		$out = bot_op($from, $heap);
	}

	return $out;
}

## Bot-routines
# These are the various subs for the bot's commands.

## bot_addanswer
# Add an answer to the database
sub bot_addanswer {
	my ($answer, $nick) = @_;

	my $query = "INSERT INTO answers (answer) VALUES (?)";
	my $sth = $dbh->prepare($query);
	$sth->execute($answer);
	return "Answer added to database, thanks $nick!";
}

## bot_addhaiku
# This subroutine adds a haiku poem to the database
# params is the poem to be added and $nick (to get the author)
sub bot_addhaiku {
	my ($haiku, $nick) = @_;
	
	if ($haiku =~ /.* ## .* ## .*/){
		my $query = "INSERT INTO haiku (poem, author) 
				VALUES (?, ?)";
		my $sth = $dbh->prepare($query);
		$sth->execute($haiku, $nick);
		return 'Haiku inserted, thanks '.$nick;
	}
	return "Wrong syntax for haiku. Should be '<line1> ## <line2> ## <line3>'";
}

## bot_addlart
# This subroutine adds a lart to the database.
# LART syntax is !lart <lart>. <lart> _must_ contain a "##"-string 
# which in substituted for the attacked's nick
sub bot_addlart {
	my ($lart) = @_;
	if ($lart !~ /##/) {
		return "Invalid LART. A Lart must contain '##' which is replaced by the luser's nick";
	}
	my $query = "INSERT INTO larts (lart) VALUES (?)";
	my $sth = $dbh->prepare($query);
	$sth->execute($lart);
	return "LART inserted!";
}

## bot_addop
# Takes params: username to give op rights, the hostmask of the sender and the 
# heap
# Modifies the op-value in the users table.
sub bot_addop {
	return "Error - you must supply a username to op" if (!$_[0]);
	return "Error - invalid argument count - this is likely a software bug"
		if (!$_[1] || !$_[2]);

	my ($user, $from, $heap) = @_;
	$user = trim($user);
	my ($nick, $host) = split(/!/, $from);
	
	return "Error - you must be authenticated first" 
		if (!$heap->{$host}->{auth});

	my $query = "SELECT admin FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($heap->{$host}->{user});

	if (my @row = $sth->fetchrow()) {
		return "Error - you are not an admin!" if (!$row[0]);

		# User is admin - proceed
		$query = "SELECT id, op FROM users WHERE username = ?";
		$sth = $dbh->prepare($query);
		$sth->execute($user);
		@row = $sth->fetchrow();
		return sprintf "Error - no such user exists: %s!", $user 
			if (!@row);
		return sprintf "%s is already an op!", $user 
			if ($row[1] == 1);

		$query = "UPDATE users SET op = ? WHERE username = ?";
		$sth = $dbh->prepare($query);
		$sth->execute(1, $user);
		return sprintf "User %s successfully added to list of opers", $user;
	}
	return "Error - couldn't verify your rights - this is probably a bug"
}

## bot_addorder
# Insert a new order into the database
# syntax is !addorder <key> <order>
sub bot_addorder {
	my ($order) = shift;
	if ($order =~ /^(.*)\s*=\s*(.*\#\#.*)$/) {
		my $key = trim($1);
		my $order = trim($2);
		
		my $query = "SELECT * FROM orders WHERE key = ?";
		my $sth = $dbh->prepare($query);
		$sth->execute($key);
		return sprintf "I already have %s on my menu", $key
			if ($sth->fetchrow());
		$query = "INSERT INTO orders (key, baka_order)
			     VALUES (?,?)";
		$sth = $dbh->prepare($query);
		$sth->execute($key, $order);
		return sprintf "Master, I am here to serve (%s)", $key;
	} else {
		return "Wrong syntax for ".$trigger."addorder, Use ".$trigger."addorder <key> = <order>. <order> must contain '##* which is substituted for the user's nick";
	}
}

## bot_addquote 
# This is used to add a quote to the database
sub bot_addquote {
	my ($nick, $quote) = @_;
	my $query = "INSERT INTO quotes (quote, author) VALUES (?, ?)";
	my $sth = $dbh->prepare($query);
	$sth->execute($quote, $nick);
	return "Quote inserted. Thanks ".$nick;
}

## bot_answer
# Return a random answer
sub bot_answer {
	my $query = "SELECT * FROM answers";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	
	my $i = 0;
	my (@rows, @answers);
	while (@rows = $sth->fetchrow()) {
		$answers[$i] = $rows[1];
		$i++;
	}
	return $answers[rand scalar @answers];
}

## bot_auth
# takes four arguments - a username, a password, a host and the heap
# Authenticates a user with anna and perform auto-op-check
sub bot_auth {
	my ($auth, $from, $heap) = @_;
	return "Error - auth takes two parameters: username & password"
		if (!$auth);
	return "Error - couldn't access the heap. This is most likely a bug" 
		if (!$heap);
	return "Error - couldn't read your current host. This is most likely a software bug"
		if (!$from);
	
	my ($nick, $host) = split(/!/, $from);

	my ($user, $pass);
	# Accept auth <nick> <pass> as well as auth <pass> (use $nick in last 
	# case)
	if (trim($auth) =~ / /) {
		($user, $pass) = split(/ /, trim($auth));
	} else {
		($user, $pass) = ($nick, trim($auth));
	}
	
	return "Error - auth takes two parameters: username & password"
		if (!$user || !$pass);
	my $query = "SELECT * FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($user);
	if (my @row = $sth->fetchrow()) {
		if (crypt($pass, substr($row[2], 0, 2)) eq $row[2]) {
			# We have a match! Light it
			$heap->{$host}->{auth} = 1;
			$heap->{$host}->{user} = $user;
			$heap->{$host}->{nick} = $nick;

			# Attempt to op the user (but do not print errors)
			my $rv = bot_op($from, $heap);
			if ($rv) {
				# bot_op returned text, so we didn't get op.
				bot_voice($from, $heap) if ($voice_auth);
			}
			return sprintf "Welcome back %s", $user;
		}
	}
	return "Error: wrong username or password";
}

## bot_bash
# Takes one argument, the number of the bash quote.
# Returns the quote.
sub bot_bash {
	my $nr = shift;

	my $ua = new LWP::UserAgent;
	$ua->agent("Mozilla/5.0" . $ua->agent);
	my $request;
	if (!$nr) {
		$request = new HTTP::Request GET => "http://bash.org/?random";
	} else {
		$request = new HTTP::Request GET => "http://bash.org/?$nr";
	}
	my $get = $ua->request($request);
	my $content = $get->content;
	$content =~ s/\n//g;
	# Find the quote. If this function stops working, the problem 
	# lies here. (? makes sure we don't gobble up the whole page 
	# on random quotes. Been there, done that)
	$content =~ /\<p class\=\"qt\"\>(.*?)\<\/p\>/;
	if (!$1) {
		return "No quote found. Please check the number";
	}
	my @lines = split(/<br \/>.{1}/, $1);

	my $quote = "";
	foreach (@lines){
		$_ = decode_entities($_);	
		$quote .= $_."\n";
	}
	return $quote;
}

## bot_dice
# This returns the result of a die roll (or several)
# Syntax is '!dice <amount>d<sides>' or just <int>d<int>
#### TODO: Truncate throws on more than 50 dice instead of removing it
sub bot_dice {
	my ($dieroll, $nick) = @_;
	
	if ($dieroll =~ /(\d+)d(\d+)/i) {
		my $dice = $1;
		my $sides = $2;

		return 'It seems ' . $nick . ' smoked too much pot. Or has anyone ever seen a die without sides?' if ($sides < 1);
		return $nick . ' will soon show us something wondrous - the first die with only one side!' if ($sides == 1);
		return $nick . ' needs to trap down on the sides. Seriously, try fewer sides!' if ($sides >= 1000);
		$dice = 1 if ($dice < 1);
		return 'Is ' . $nick . ' going to take a bath in dice? Seriously, try fewer dice!' if ($dice >= 300);
		
		# Here we go
		my ($i, $rnd, $value, $throws);
		$value = 0;
		for ($i = 1; $i <= $dice; $i++) {
			$rnd = int(rand($sides)) + 1;
			$value = $value + $rnd;
			
			if ($i != $dice){
				$throws .= $rnd . ", ";
			} else {
				$throws .= $rnd;
			}
		}
		
		return $nick . ': ' . $value . ' (' . $throws . ')' if ($dice <= 50);
		return $nick . ': ' . $value . ' (too many throws to show)';
	}
	# It shouldn't be possible to end up here, but anyway
	return 'Syntax error in diceroll. Correct syntax is <int>d<int>';
}

## bot_fortune
# Prints a fortune, if fortune is installed
sub bot_fortune {
	my $args = shift;
	
	my @path = split(':', $ENV{'PATH'});
	foreach (@path) {
		if (-x "$_/fortune") {
			my $fortune_app = $_."/fortune";
			
			# Parse arguments
			my $cmd_args = "";
			$cmd_args .= " -a" if ($args =~ s/\W-a\W//);
			$cmd_args .= " -e" if ($args =~ s/\W-e\W//);
			$cmd_args .= " -o" if ($args =~ s/\W-o\W//);
			$cmd_args .= " " . $1 if ($args =~ /(.+)/);
			
			my $fortune = qx($fortune_app -s $cmd_args 2>/dev/null);
			return "No fortunes found" if $fortune eq '';
			$fortune =~ s/^\t+/   /gm;
			return $fortune;
		}
	}
	irclog('status' => "Failed to fetch fortune - make sure fortune is installed, and in your \$PATH\n");
	print warning("Failed to fetch fortune - make sure fortune is installed, and in your \$PATH\n")
		if ($verbose);
	return "No fortune, sorry :-(";
}

## bot_googlesearch
# Search google. Returns the first hit
sub bot_googlesearch {
	my $query = shift;
	return 'FALSE' if ($query eq '');
	$query = trim($query);

	# Check if user wants specific number of results. 
	# We're geeks, so we count from zero
	my $results = 0;
	
	if ($query =~ /^(\d+)\s+(.*)$/) {
		# -1 because we prefer to count from zero
		$results = $1 - 1;
		$query = $2;
	}
	
	# Print a max of twenty results 
	# TODO: Make it configurable once the admin iface exists
	$results = 19 if ($results >= 20);

	# Format query-string
	$query =~ s/\s/\+/g;
	
	# Initiate useragent
	my $ua = new LWP::UserAgent;
	$ua->agent("Mozilla/5.0" . $ua->agent);
	
	# Search
	my $request = new HTTP::Request GET => "http://www.google.com/search?hl=en&ie=ISO-8859-1&q=".$query;
	my $get = $ua->request($request);
	my $content = $get->content;

	# Format results. Replace <br> with newlines and remove tags
	$content =~ s/\<br\>/\n/g;
	$content =~ s/\<.+?\>//sg;
	$content =~ s/#//s;

	# Make array with all results
	my @lines = split('\n', $content);
	my @pages = grep(/Similar( |&nbsp;)pages/, @lines);
	
	return "Sorry - google didn't return any results :(" if (scalar(@pages) == 0);
	
	# Remove empty results and decode entities.
	my $i;
	for ($i = 0; $i < scalar(@pages); $i++) {
		$pages[$i] =~ s/\s+.*//g;
		$pages[$i] = decode_entities($pages[$i]);
		if ($pages[$i] =~ /(^\n|\s+\n)/){ splice(@pages, $i, 1) };
		if ($pages[$i] !~ /\./){ splice(@pages, $i, 1) };
	}
	
	my $out;
	for ($i = 0; $i <= $results; $i++) {
		# Return if no more results were returned
		return $out if (!$pages[$i]);
		$out .= "http://".$pages[$i]."\n";
	}
	return $out;
}

## bot_haiku
# This returns a haiku
sub bot_haiku {
	my (@rows, @haiku);
	my $query = "SELECT * FROM haiku";
	my $sth = $dbh->prepare($query);
	$sth->execute();

	my $i = 0;
	while (@rows = $sth->fetchrow()) {
		$haiku[$i] = $rows[1];
		$i++;
	}
	my $out = $haiku[rand scalar @haiku];
	$out =~ s/ ## /\n/g;
	return $out;
}

# bot_karma
# Returns the current karma for a word
sub bot_karma {
	my $word = shift;

	my $query = "SELECT * FROM karma WHERE word = ? LIMIT 1";
	my $sth = $dbh->prepare($query);
	$sth->execute($word);
	my @row;
	if (@row = $sth->fetchrow()) {
		return "Karma for '".$word."': ".$row[2];
	}
	return "Karma for ".$word.": 0";
}

## bot_karma_update
# This is used to update the karma-stats in the database
# Takes three arguments - word, karma change and user
sub bot_karma_update {
	my ($word, $karma, $nick) = @_;
	if ($word eq '') {
		# This should NOT happen lest there's a bug in the 
		# script
		return "Karma not updated (Incorrect word)";
	}

	my $query = "SELECT * FROM karma WHERE word = ? LIMIT 1";
	my $sth = $dbh->prepare($query);
	$sth->execute($word);
	my @row;
	if (@row = $sth->fetchrow()) {
		if ($karma eq "++") {
			$karma = $row[2] + 1;
		} elsif ($karma eq "--") {
			$karma = $row[2] - 1;
		} else {
			# This should NOT happen lest there's a bug in
			# the script
			return "Karma not updated (Incorrect modifier)";
		}
		$query = "UPDATE karma 
			SET karma = ?, user = ? 
			WHERE id = ?";
		$sth = $dbh->prepare($query);
		$sth->execute($karma, $nick, $row[0]);
		return 'FALSE';
	} else {
		# Word does not exist
		if ($karma eq "++") {
			$karma = 1;
		} elsif ($karma eq "--") {
			$karma = -1;
		} else {
			# This should NOT happen lest there's a bug in
			# the script
			return "Karma not updated (Incorrect modifier)";
		}
		$query = "INSERT INTO karma (word, karma, user) 
			VALUES (?, ?, ?)";
		$sth = $dbh->prepare($query);
		$sth->execute($word, $karma, $nick);
		# No need to inform of the karma-change
		return 'FALSE';
	}
}

## bot_lart
# This subroutine takes one argument (the nick to be lart'ed) and
# returns a random insult
sub bot_lart {
	my ($nick, $luser) = @_;
	
	if (lc($luser) eq lc($server{'nick'})) {
		return $nick . ": NAY THOU!";
	}
	
	my $query = "SELECT * FROM larts";
	my $sth = $dbh->prepare($query);
	$sth->execute();

	my $i = 0;
	my (@rows, @larts);
	while (@rows = $sth->fetchrow()) {
		$larts[$i] = $rows[1];
		$i++;
	}
	my $lart = $larts[rand scalar @larts];
	if ($luser eq 'me') {
		$luser = $nick;
	}
	$lart =~ s/##/$luser/;
	
	$irc->yield(ctcp => $server{'channel'} => 'ACTION '.$lart);
	return 'FALSE';
}

## bot_lastseen
# This returns information on when a nick last was seen
sub bot_lastseen {
	my ($nick, $queried_nick, $type) = @_;
	my ($query, $sth);

	if ($type eq 'public') {
		# Update lastseen table
		$query = "DELETE FROM lastseen WHERE nick = ?";
		$sth = $dbh->prepare($query);
		$sth->execute($nick);
		my $newmsg = $nick . ' last queried information about ' . $queried_nick;
		$query = "INSERT INTO lastseen (nick, msg, time) 
				VALUES (?, ?, ".time.")";
		$sth = $dbh->prepare($query);
		$sth->execute($nick, $newmsg);
	}

	if (lc($queried_nick) eq lc($server{'nick'})) {
		return "I'm right here, dumbass";
	}
	if (lc($queried_nick) eq lc($nick)) {
		return "Just look in the mirror, okay?";
	}
	if (lc($queried_nick) =~ /^(me|myself|I)$/) {
		return "Selfcentered, eh?";
	}
	if (lc($queried_nick) eq "jimmy hoffa") {
		return "I don't know either, try the Piranha Club";
	}
	if (lc($queried_nick) =~ /^dokuro(-chan|)$/) {
		return "I don't know either, try the Wood Glue Club";
	}
	if (lc($queried_nick) eq "the answer to life, the universe and everything") {
		return "42";
	}

	$query = "SELECT * FROM lastseen 
			WHERE nick = ? LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($queried_nick));
	
	my @row;
	if (@row = $sth->fetchrow()) {
		my ($out, $time, $msg);
		$msg = $row[2];
		$time = $row[3];
		$time = calc_diff($time);
		$out = $msg . ' ' . $time . ' ago.';
		return $out;
	} 

	return "Sorry, I couldn't find any information for $queried_nick";
}

## bot_lastseen_newmsg
# This handles new messages in the channel, stores them in sqlite db
# for later retrieval with !seen command.
sub bot_lastseen_newmsg {
	my ($nick, $msg) = @_;
	my $time = time;

	# Delete previous (if any) messages
	my $query = "DELETE FROM lastseen WHERE nick = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute(lc($nick));
	
	# Insert new quote
	$msg = $nick .' last said \''.$msg.'\'';
	
	$query = "INSERT INTO lastseen (nick, msg, time) 
			VALUES (?, ?, ?)";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick), $msg, $time);
	return;
}

## bot_mynotes
# Return all notes belonging to a user
# Takes one param: username to search for
sub bot_mynotes {
	my ($nick, $type) = @_;
	return if (!$nick or !$type);
	
	my $query = "SELECT word FROM notes WHERE author = ? ORDER BY word ASC";
	my $sth = $dbh->prepare($query);
	$sth->execute($nick);
	my (@row, @words);
	my $i = 0;
	while (@row = $sth->fetchrow()) {
		$words[$i] = $row[0];
		$i++;
	}

	if ((scalar(@words) > 15) && ($type eq 'public')) {
		# Will not display more than 15 notes in 'public' (channels)
		my $out = sprintf("%s: Too many notes. Displaying 15 first (message me to see all):", $nick);
		for (my $j = 0; $j <= 15; $j++) {
			$out .= " '".$words[$j]."',";
		}
		return $out;
	}

	return sprintf("%s: you haven't taken any notes yet... better get starting soon!", $nick) if (scalar(@words) == 0);
	
	my $words;
	foreach (@words) {
		$words .= "'$_', "
	}
	$words =~ s/(.*), /$1/;
	return $nick.": your notes: $words";
}

## bot_note
# This manages calc-stuff. Calc is a small system to associate a word or 
# little sentence with a longer sentence, answer, solution, retort, whatever.
sub bot_note {
	my ($note, $nick) = @_;
	
	# Print random note if nothing is specified
	if (!$note) {
		my $query = "SELECT * FROM notes";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		
		my (@row, @words, @answers, @authors);
		my $i = 0;
		while (@row = $sth->fetchrow()) {
			$words[$i] = $row[1];
			$answers[$i] = $row[2];
			$authors[$i] = $row[3];
			$i++;
		}
		if ($i == 0) {
			return "No notes found in database. You better start taking some notes!";
		}
		my $num = rand scalar @words;
		return "* ".$words[$num]." = ".$answers[$num]." [added by ".$authors[$num]."]";
	}
	
	# Find out what to do
	if ($note =~ /^(.+?)\s*=\s*(.+)$/) {
		# User want to insert a new quote
		# Test if word exists
		my $word = trim($1);
		my $answer = trim($2);
		return 'FALSE' if (($word eq '') or ($answer eq ''));

		my $query = "SELECT * FROM notes WHERE word = ?";
		my $sth = $dbh->prepare($query);
		$sth->execute($word);
		my @row;
		if (@row = $sth->fetchrow()) {
			if ($nick eq $row[3]) {
				$query = "UPDATE notes SET answer = ? WHERE word = ?";
				my $sth = $dbh->prepare($query);
				$sth->execute($answer, $word);
				return "'".$word."' updated, thanks ".$nick."!";
			}
			return "Sorry ".$nick." - the word '".$word."' already exists in my database";
		}
		
		# Insert new note
		$query = "INSERT INTO notes (word, answer, author, date)
			     VALUES (?, ?, ?, ".(int time).")";
		$sth = $dbh->prepare($query);
		$sth->execute($word, $answer, $nick);
		return "'".$word."' added to the database, thanks ".$nick."!";
	}
	
	$note = trim($note);
	my $query = "SELECT * FROM notes WHERE word = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($note);
	my @row = '';
	if (@row = $sth->fetchrow()) {
		return "* ".$row[1]." = ".$row[2]." [added by ".$row[3]."]";	
	} else {
		return "'".$note."' was not found, sorry";
	}
	
	return 'FALSE';
}

## bot_op
# Takes two parameters (the hostmask of the user and the heap)
# Ops the user is he/she has the rights
sub bot_op {
	return "Error - no hostmask or heap supplied. This is probably a bug"
		if (!$_[0] || !$_[1]);
	my ($from, $heap) = @_;

	my ($nick, $host) = split(/!/, $from);
	if (!$heap->{$host}->{auth}) {
		return "Error - you must authenticate first";
	}
	my $query = "SELECT op FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($heap->{$host}->{user});
	if (my @row = $sth->fetchrow()) {
		if ($row[0]) {
			$irc->yield(mode => $server{'channel'} => "+o" => $nick);
			return;
		}
	}
	return "I am not allowed to op you!";
}

## bot_order
# Your very own bar!
# This sub should just return FALSE and then instead send an action
sub bot_order {
	my ($nick, $order) = @_;
	
	# Discover syntax
	my ($out, $key);
	if ($order =~ /(.*) for (.*)/i) {
		$key = $1;
		$nick = $2;
	} else {
		$key = $order;
	}

	my $query = "SELECT * FROM orders WHERE key = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($key);
	
	my @row;
	if (@row = $sth->fetchrow()) {
		$out = $row[2];
		$out =~ s/##/$nick/;
	} else {
		# Key wasn't in database
		$out = 'hands ' . $nick . ' ' . $key;
	}

	$irc->yield(ctcp => $server{'channel'} => 'ACTION '.$out);
	return 'FALSE';
}

## bot_quote
# This returns a random quote from a local quote database
sub bot_quote {
	my $query = "SELECT * FROM quotes";
	my $sth = $dbh->prepare($query);
	$sth->execute;

	my (@rows, @quotes);
	my $i = 0;
	while (@rows = $sth->fetchrow()) {
		$quotes[$i] = $rows[1];
		$i++;
	}
	if ($i == 0) {
		return "No quotes were found. You're a boring lot!";
	}
	my $quote = $quotes[rand scalar @quotes];
	# Yes, it's ugly but we need this to get proper linebreaking...
	$quote =~ s/\Q\n\E/\n/g;
	return $quote;
}

## bot_reload
# Reloads the roulette gun (only for weenies)
# TODO: add number of reloads to !rstats
sub bot_reload {
	my $query = "DELETE FROM roulette_shots";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	$irc->yield(ctcp => $server{'channel'} => 'ACTION reloads...');
	return 'FALSE';
}

## bot_register
# Register a new user. Takes two vars - username and password
sub bot_register {
	return "Error - you must supply a username and a password" 
		if (!$_[0] || !$_[1]);
	return "Error - missing heap or hostmask in register arguments. This is likely a bug"
		if (!$_[2] || !$_[3]);
	
	my ($user, $pass) = @_;
	my $query = "SELECT id FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($user);
	return "Error - username already exists" if ($sth->fetchrow());
	
	$query = "INSERT INTO users (username, password) VALUES (?, ?)";
	$sth = $dbh->prepare($query);
	my @salt_chars = ('a'..'z','A'..'Z','0'..'9');
	my $salt = $salt_chars[rand(63)] . $salt_chars[rand(63)];
	$sth->execute($user, crypt($pass, $salt));
	bot_auth($user, $pass, $_[2], $_[3]);
	return "You were succesfully registered and are already logged in. Welcome aboard"
}

## bot_rmop
# Removes a user from list of opers. Takes three params - username to remove, 
# sender and the heap
sub bot_rmop {
	return "Error - you must supply a username" if (!$_[0]);
	return "Error - invalid argument count - this is likely a software bug"
		if (!$_[1] || !$_[2]);

	my ($user, $from, $heap) = @_;
	$user = trim($user);
	my ($nick, $host) = split(/!/, $from);
	
	return "Error - you must be authenticated first" 
		if (!$heap->{$host}->{auth});

	my $query = "SELECT admin FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($heap->{$host}->{user});

	if (my @row = $sth->fetchrow()) {
		return "Error - you are not an admin!" if (!$row[0]);

		# User is admin - proceed
		$query = "SELECT id FROM users WHERE username = ?";
		$sth = $dbh->prepare($query);
		$sth->execute($user);
		return sprintf "Error - no such user exists: %s!", $user 
			if (!$sth->fetchrow());

		$query = "UPDATE users SET op = ? WHERE username = ?";
		$sth = $dbh->prepare($query);
		$sth->execute(0, $user);
		return sprintf "User %s successfully removed from list of opers", $user;
	}
	return "Error - couldn't verify your rights - this is probably a bug"
}
	
## bot_rot13
# Encrypts and decrypts rot13-strings
sub bot_rot13 {
	my $string = $_[0];

	$string =~ y/A-Za-z/N-ZA-Mn-za-m/;
	return $string;
}

## bot_roulette
# Random chance of getting killed (kicked)
# Do you feel lucky?
sub bot_roulette {
	my $nick = $_[0];
	
	my ($shot, $hit, $out);
	my $query = "SELECT * FROM roulette_shots";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my @row;
	if (@row = $sth->fetchrow()) {
		$shot = $row[0];
		$hit = $row[1];
	} else {
		$shot = 0;
		$hit = int(rand(6));
		$hit = 6 if ($hit == 0);
	}
	$shot += 1;
	$query = "DELETE FROM roulette_shots";
	$sth = $dbh->prepare($query);
	$sth->execute();
	if ($shot == $hit) {
		# Bang, you're dead
		$out = $nick . ": chamber " . $shot . " of 6 => *bang*";
		$shot = 0;
	} else {
		$out = $nick . ": chamber " . $shot . " of 6 => *click*";
		$query = "INSERT INTO roulette_shots (shot, hit) 
			  VALUES (?, ?)";
		$sth = $dbh->prepare($query);
		$sth->execute($shot, $hit);
	}
	
	# Update roulette_stats
	$query = "SELECT * FROM roulette_stats WHERE user = ?";
	$sth = $dbh->prepare($query);
	$sth->execute($nick);
	if (@row = $sth->fetchrow()) {
		# Update
		if ($out =~ /\*bang\*/) {
			# User is dead
			$query = "UPDATE roulette_stats SET shots = ?, hits = ?, deathrate = ?, liverate = ? 
				  WHERE user = ?";
			$sth = $dbh->prepare($query);
			$sth->execute($row[2] + 1, $row[3] + 1, sprintf("%.1f", (($row[3] + 1) / ($row[2] + 1)) * 100), sprintf("%.1f", (100 - ((($row[3] + 1) / ($row[2] + 1)) * 100))), $nick);
		} else {
			# User lives
			$query = "UPDATE roulette_stats SET shots = ?, deathrate = ?, liverate = ?
				  WHERE user = ?";
			$sth = $dbh->prepare($query);
			$sth->execute($row[2] + 1, sprintf("%.1f", (($row[3] / ($row[2] + 1)) * 100)), sprintf("%.1f", (100 - (($row[3] / ($row[2] + 1)) * 100))), $nick);
		}
	} else {
		# Insert
		if ($out =~ /\*bang\*/) {
			# User is dead
			$query = "INSERT INTO roulette_stats (user, shots, hits, deathrate, liverate)
				  VALUES (?, ?, ?, ?, ?)";
			$sth = $dbh->prepare($query);
			$sth->execute($nick, 1, 1, 100, 0);
		} else {
			# User lives
			$query = "INSERT INTO roulette_stats (user, shots, hits, deathrate, liverate)
				  VALUES (?, ?, ?, ?, ?)";
			$sth = $dbh->prepare($query);
			$sth->execute($nick, 1, 0, 0, 100);
		}
	}

	return $out;
}

# bot_roulette_stats
# Print statistical information for roulette games
sub bot_roulette_stats {
	# Most hits
	my $query = "SELECT * FROM roulette_stats ORDER BY hits DESC LIMIT 1";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my @row;
	my $most_hits;
	if (@row = $sth->fetchrow()) {
		$most_hits = $row[1] . " (".$row[3]." hits)";
	} else {
		return "You haven't played any roulette yet!";
	}

	# Most shots
	$query = "SELECT * FROM roulette_stats ORDER BY shots DESC LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute();
	@row = $sth->fetchrow();
	my $most_shots = $row[1] . " (".$row[2]." shots)";

	# Highest deathrate
	$query = "SELECT * FROM roulette_stats ORDER BY deathrate DESC LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute();
	@row = $sth->fetchrow();
	my $highest_deathrate = $row[1] . " (".$row[4]."%)";

	# Highest liverate
	$query = "SELECT * FROM roulette_stats ORDER BY liverate DESC LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute();
	@row = $sth->fetchrow();
	my $highest_liverate = $row[1] . " (".$row[5]."%)";
	
	return "Roulette stats: Most shots - ".$most_shots.". Most hits - ".$most_hits.". Highest deathrate - ".$highest_deathrate.". Highest survival rate - ".$highest_liverate.".";
}

## bot_search
# Searches various tables in the database
# Syntax is !search <table> <string>. Possible values are "notes" and "quotes"
sub bot_search {
	my $query = $_[0];
	return 'FALSE' if (!$query);
	my ($table, $string);
	
	if ($query =~ /(notes|quotes|all)\s+(.*)/) {
		$table = $1;
		$string = $2;
	} else {
		$table = 'all';
		$string = $query;
	}
	
	if ($table eq 'notes') {
		my $query = qq|SELECT * FROM notes WHERE word LIKE ?|;
		my $sth = $dbh->prepare($query);
		# No... the error wasn't here... I fail miserably
		$sth->execute("%".$string."%") or die(error($sth->errstr));
		my ($i, $j) = 0;
		my (@row, @words);
		while (@row = $sth->fetchrow()) {
			$words[$i] = $row[1];
			$i++;
		}
		
		return "No results for '".$string."'" if (scalar(@words) == 0);

		my $result = "Search results for '".$string."': ";
		if (scalar(@words) > 15) {
			for ($j = 0; $j <= 15; $j++) {
				$result .= "'" . $words[$j] . "', ";
			}
			$result =~ s/(.*), /$1/;
			$result .= " (search returned too many results)";
			return $result;
		}
		
		my $words;
		foreach (@words) {
			$words .= "'$_', ";
		}
		$words =~ s/(.*), /$1/;
		return $result . $words;
	} 

	if ($table eq 'quotes') {
		my $query = qq|SELECT * FROM quotes WHERE quote LIKE ?|;
		my $sth = $dbh->prepare($query);
		$sth->execute("%".$string."%") or die(error($sth->errstr));
		my ($i, $j) = 0;
		my (@row, @quotes);
		while (@row = $sth->fetchrow()) {
			$quotes[$i] = $row[1];
			$i++;
		}
		
		return "No results for '".$string."'" if ($i == 0);

		my $result = "Search results for '".$string."':\n";
		if ($i > 3) {
			for ($j = 0; $j <= 3; $j++) {
				$result .= "'" . $quotes[$j] . "'\n";
			}
			$result .= "(search returned too many results)\n";
			return $result;
		}
		for ($j = 0; $j < $i; $j++) {
			$result .= "'" . $quotes[$j] . "'\n";
		}
		$result =~ s/\Q\n\E/\n /ig;
		return $result;
	}
	
	if ($table eq 'all') {
		my $out = "Search results in quotes: ";
		$out .= bot_search("quotes ".$string);
		# The following line adds linebreak in case of no results
		$out =~ s/(No results for '$string')/$1\n/ig;
		$out .= "Search results in notes: ";
		$out .= bot_search("notes ".$string);
		$out =~ s/Search results for '$string'://ig;
		$out =~ s/\Q\n\E/\n /ig;
		return $out;
	}
}

## bot_uptime
# Returns current uptime of the bot
sub bot_uptime {
	return "Uptime: " . calc_diff(STARTTIME);
}

## bot_voice
# Takes two params (the hostmask of the user and the heap)
# Voices the user if setting is set.
sub bot_voice {
	return "Error - no hostmask or heap supplied. This is likely a bug"
		if (!$_[0] || !$_[1]);
	my ($from, $heap) = @_;

	my ($nick, $host) = split(/!/, $from);
	if (!$heap->{$host}->{auth}) {
		return "Error - you must authenticate first";
	}
	return "Error - Thou mvst remain voiceless" if (!$voice_auth);
	$irc->yield(mode => $server{'channel'} => "+v" => $nick);
	return;
}

## Do-routines
# Various stuff that keeps the bot running in case of certain events

## do_autoping
# Let's pings ourself to ensure the connection is still alive
sub do_autoping {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	$irc->yield(userhost => $irc->nick_name) unless $heap->{seen_traffic};
	$heap->{seen_traffic} = 0;
	$kernel->delay(autoping => 300);
}

## do_connect
# Connect us!
sub do_connect {
	irclog('status', sprintf "-!- Connecting to %s", $server{'server'});
	printf "[%s] %s!%s Connecting to %s\n", print_time(), colour('-', '94'),
		colour('-', '94'), $server{'server'} if ($verbose);
	$irc->yield(connect => {});
}

## do_reconnect
# This handles reconnection when we've died for various reasons
sub do_reconnect {
	my $kernel = $_[KERNEL];
	# Disable autopings when disconnected
	$kernel->delay(autoping => undef);
	irclog('status', 'Attempting reconnect in 60 seconds...');
	printf "[%s] Attempting reconnect in 60 seconds...\n", print_time() if (!$silent);
	$kernel->delay(connect => 60);
}

## Err-routines
# We get these when the irc server returns a numeric 4xx error. Print it to the 
# user and react if nescessary

## err_nick_taken
# This gets called whenever a connection attempt returns '433' - nick taken.
# The subroutine swaps between several different nicks
sub err_nick_taken {
	my $newnick = $server{'nick'} . int(rand(100));
	irclog('status', sprintf "Nick taken, trying %s...", $newnick);
	printf "[%s] Nick taken, trying %s...\n", print_time(), $newnick if (!$silent); 
	$irc->yield(nick => $newnick);
	$server{'nick'} = $newnick;
}

## err_4xx_default
# Oh my... we tried to do someting we couldn't...
# Defaults handler for 4xx-errors. Everything we don't care about should go 
# through here
sub err_4xx_default {
	my $args = $_[ARG2];
	irclog('status' => sprintf "%s: %s", $args->[0], $args->[1]);
	printf "[%s] ".colour('-', '94')."!".colour('-', '94')." %s: %s\n", 
		print_time(), $args->[0], $args->[1] if (!$silent);
}

## Session routines
# These subroutines relates purely to session handling

## session_auth
# Takes two arguments, username and password. Authenticates users.
sub session_auth {
	my ($username, $pass) = @_;
	my $query = "SELECT * FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($username);
	my %row;
	if (%row = $sth->fetchrow_hash()) {
		if ($row{'password'} eq $pass) {
			
			return "Login accepted";	
		}
		return "Invalid username or password";
	}
	return "Invalid username or password";
}

## Handle subroutines
# These are the standard handle subroutines... nothing to see here, please move along

## on_324
# channelmodeis (refer to the rfc...)
sub on_324 {
	irclog('status' => sprintf "-!- Mode/%s %s", $_[ARG2]->[0], $_[ARG2]->[1]);
	printf "[%s] %s!%s Mode/%s %s\n", print_time(), colour('-', 94), 
		colour('-', 94), colour($_[ARG2]->[0], 96), $_[ARG2]->[1] 
		if ($verbose);
}

## on_329
# This signal contains the creation date of the channel as an epoch timestamp
sub on_329 {
	my $msg = $_[ARG2];
	irclog('status' => sprintf "-!- Channel %s created %s", $msg->[0], scalar localtime $msg->[1]);
	printf "[%s] %s!%s Channel %s created %s\n", print_time(), 
		colour('-', 94), colour('-', 94), 
		colour($msg->[0], 96), scalar localtime $msg->[1]
		if ($verbose);
}

## on_332
# This is the topic announcement we recieve whenever we join a channel
# ->[0] is the channel, ->[1] is the topic
sub on_332 {
	my $msg = $_[ARG2];
	irclog('status' => sprintf "-!- Topic for %s: %s", $msg->[0], $msg->[1]);
	printf "[%s] ".colour('-', 94)."!".colour('-', 94)." Topic for %s: %s\n", print_time(), colour($msg->[0], '96'), $msg->[1]
		if ($verbose);
}

## on_333
# This numeric gives us the name of the person who sat the topic as well as the
# time he/she did that.
# ->[0] is the channel, ->[1] is the nick who sat the topic, ->[2] is the epoch
# timestamp the topic was set
sub on_333 {
	my $msg = $_[ARG2];
	irclog('status' => sprintf "-!- Topic set by %s [%s]", $msg->[1], scalar localtime $msg->[2]);
	printf "[%s] ".colour('-', 94)."!".colour('-', 94)." Topic set by %s [%s]\n", print_time(), $msg->[1], 
		scalar localtime $msg->[2] if ($verbose);
}

## on_namreply
# Whenever we join a channel the server returns irc_353. Print a list of users
# in the channel
sub on_namreply {
	return if (!$verbose);
	my @args = @{$_[ARG2]};
	shift (@args); # discard the "="-sign
	my $channel = shift(@args);
	my @users = split(/ /, shift(@args));
	my $out = sprintf "[%s] [".colour('Users', 32)." %s]\n", print_time(), 
		colour($channel, 92) if ($verbose);
	# FIXME: Do some automatic calculation instead of just printing in 
	# five rows
	my ($i, $j) = (0, 0);
	for ($i = 0; $i <= $#users; $i++) {
		$out .= sprintf "[%s] ", print_time() if ($j == 0);
		$out .= sprintf "[%s] ", $users[$i];
		if ($j == 4) {
			$out .= sprintf "\n";
			$j = 0;
		} else {
			$j++;
		}
	}
	## FIXME
#	irclog('status' => $out);
	printf "%s\n", $out if ($j != 0);
}

## on_msg
# This is called whenever the client recieves a privmsg. 
sub on_msg {
	my ($kernel, $heap, $from, $to, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
	my ($nick) = split(/!/, $from);

	# if this is a message from anna herself, send it to recipients log - 
	# else to sender's log
	irclog($nick => sprintf "<%s> %s", $nick, $msg);
	$heap->{seen_traffic} = 1;

	# Kill her own messages
	return if ($nick eq $server{'nick'});

	my $out = parse_message($kernel, $heap, $from, $to, $msg, 'msg');
	
	# Return if there's nothing to print
	return if ($out eq 'FALSE'); 
	
	my @lines = split(/\n/, $out);
	foreach(@lines) {
		irclog($nick => sprintf "<%s> %s", $irc->nick_name, $_);
		$irc->yield(privmsg => $nick => $_);
		$irc->yield(ctcp => $server{'channel'} => 'ACTION reloads...') if ($_ =~ /chamber \d of \d => \*bang\*/);
	}
}

## on_public
# This runs whenever someone post to a channel the bot is watching
sub on_public {
	my ($kernel, $heap, $from, $to, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
	my ($nick) = split(/!/, $from);
	
	irclog($to->[0] => sprintf "<%s> %s", $nick, $msg);
	$heap->{seen_traffic} = 1;

	# Kill her own messages
	return if ($nick eq $server{'nick'});

	my $out = parse_message($kernel, $heap, $from, $to, $msg, 'public');
	return if !defined($out);
	return if ($out eq 'FALSE');


	# $to is the target recipients. On public
	# messages, this is where the reply should be 
	# sent to.
	my @lines = split(/\n/, $out);
	foreach(@lines) {
		irclog($to->[0] => sprintf "<%s> %s", $irc->nick_name, $_);
		$irc->yield(privmsg => $to => $_);
		if ($out =~ /chamber \d of \d => \*bang\*/) {
			$irc->yield(kick => $server{'channel'} => $nick => "Bang! You die...");
			$irc->yield(ctcp => $server{'channel'} => 'ACTION reloads...');
		}
	}
}

## on_notice
# This is for notices...
sub on_notice {
	my ($from, $msg) = @_[ARG0, ARG2];
	
	$_[HEAP]->{seen_traffic} = 1;
	# No ! should indicate server message
	if ($from !~ /!/) {
		irclog('status' => sprintf "!%s %s", $from, $msg);
		printf "[%s] %s %s\n", print_time(), colour("!".$from, '92'), $msg 
			if (!$silent);
		return;
	}

	my ($nick, $host) = split(/!/, $from);
	irclog($nick => sprintf "-%s(%s)- %s", $nick, $host, $msg);
	printf "[%s] -%s(%s)- %s\n", print_time(), colour($nick, "95"),
			colour($host, '35'), $msg if (!$silent);
}


## on_connect
# This gets called whenever the script receives the event '376' - the 
# server code for "End of MOTD".
# on_connect takes responsibility for connecting to the appropriate channels
# and for negotiating with nickserv
sub on_connect {
	$_[HEAP]->{seen_traffic} = 1;
	if (($server{'nspasswd'} ne "") and ($default{'nick'} eq $server{'nick'})) {
		printf "[%s] Identifying with services... ", print_time() if (!$silent);
		$irc->yield(privmsg => 'nickserv' => "IDENTIFY $server{'nspasswd'}");
		printf "done!\n" if (!$silent);;
	}
	
	if (($server{'nick'} ne $default{'nick'}) and ($server{'nspasswd'} ne "")) {
		printf "[%s] Nick taken. Reclaiming custody from services... ", print_time() if (!$silent);
		$irc->yield(privmsg => 'nickserv' => "GHOST $default{'nick'} $server{'nspasswd'}");
		$irc->yield(privmsg => 'nickserv' => "RECOVER $default{'nick'} $server{'nspasswd'}");
		$irc->yield(nick => $default{'nick'});
		printf "done!\n" if (!$silent);
		printf "[%s] Identifying with services... ", print_time() if (!$silent);
		$irc->yield(privmsg => 'nickserv' => "IDENTIFY $server{'nspasswd'}");
		printf "done!\n" if (!$silent);
	}
	irclog('status' => sprintf "Joining %s", $server{'channel'});
	printf "[%s] Joining %s...\n", print_time(), $server{'channel'} if (!$silent);
	$irc->yield(mode => $server{'nick'} => '+i');
	$irc->yield(join => $server{'channel'});
	$irc->yield(mode => $server{'channel'});
#	$self->privmsg($server{'channel'}, "all hail your new bot");
}

## on_connected
# We recieve this once a connection is established. This does NOT mean the 
# server has accepted us yet, so we can't send anything
sub on_connected {
	my $kernel = $_[KERNEL];
	
	$_[HEAP]->{seen_traffic} = 1;
	$kernel->delay(autoping => 300);

	irclog('status' => sprintf "Connected to %s", $server{'server'});
	printf "[%s] %s!%s Connected to %s\n", print_time(), colour('-', '94'),
		colour('-', '94'),  $server{'server'} if (!$silent);
}

## on_join
# This is used when someone enters the channel. Use this for 
# auto-op'ing or welcome messages
sub on_join {
	my ($from, $channel) = @_[ARG0, ARG1];
	my ($nick, $host) = split(/!/, $from);
	
	$_[HEAP]->{seen_traffic} = 1;
	# Update lastseen table
	if ($channel eq $server{'channel'}) {
		my ($query, $sth, $msg);
		
		$msg = $nick . " joined " . $channel;
		
		# Delete old record
		$query = "DELETE FROM lastseen WHERE nick = ?";
		$sth = $dbh->prepare($query);
		$sth->execute(lc($nick));

		$query = "INSERT INTO lastseen (nick, msg, time) 
			VALUES (?, ?, ".time.")";
		$sth = $dbh->prepare($query);
		$sth->execute(lc($nick), $msg);
	}

	irclog($channel => sprintf "-!- %s [%s] has joined %s", $nick, $host, $channel);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s [%s] has joined %s\n", 
		print_time(), colour($nick, '96'), colour($host, '96'), $channel if ($verbose);
}

## on_kill
# This is called when you get killed. As it is followed by the standard 
# disconnect, don't sign up for a reconnect. ARG1 = $server{'nick'}
sub on_kill {
	my ($from, $reason) = @_[ARG0, ARG2];
	my ($user, $host) = split(/!/, $from);
	irclog('status' => sprintf "-!- You were killed by %s [%s] [%s]", $user, $host, $reason);
	printf "[%s] %s!%s You were %s by %s [%s] [%s]\n", print_time, 
		colour("-", 94), colour("-", 94), colour('killed', 91),
		$user, $host, $reason if (!$silent);
}

## on_part
# This is called when someone leaves the channel
sub on_part {
	my ($from, $channel, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);
	
	$_[HEAP]->{seen_traffic} = 1;
	# Update lastseen table
	if (lc($channel) eq lc($server{'channel'})) {
		my ($query, $sth, $ls_msg);
		
		if ($msg) {
			$ls_msg = $nick . " left from " . $channel . " stating '" . $msg . "'";
		} else {
			$ls_msg = $nick . " left from " . $channel . " with no reason";
		}
		
		# Delete old record
		$query = "DELETE FROM lastseen WHERE nick = ?";
		$sth = $dbh->prepare($query);
		$sth->execute(lc($nick));

		$query = "INSERT INTO lastseen (nick, msg, time) 
			VALUES (?, ?, ".time.")";
		$sth = $dbh->prepare($query);
		$sth->execute(lc($nick), $msg);
	}

	#FIXME: Blargh... this almost makes me puke
	$msg = '' if !defined($msg);
	
	irclog($channel => sprintf "-!- %s has left %s [%s]", $nick, $channel, $msg);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s has left %s [%s]\n", 
		print_time(), $nick, colour($channel, "96"), $msg if ($verbose);
}

## on_quit
# This signal is recieved when someone sends a QUIT notice (the disconnect)
sub on_quit {
	my ($from, $msg) = @_[ARG0, ARG1];
	my ($nick, $host) = split(/!/, $from);
	
	$_[HEAP]->{seen_traffic} = 1;
	# Update lastseen table
	my ($query, $sth, $ls_msg);
	
	if ($msg) {
		$ls_msg = $nick . " quit IRC stating '" . $msg . "'";
	} else {
		$ls_msg = $nick . " quit IRC with no reason";
	}
	
	# Delete old record
	$query = "DELETE FROM lastseen WHERE nick = ?";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick));
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES (?, ?, ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick), $ls_msg);
	$msg = '' if !defined($msg);

	irclog('status' => sprintf "%s (%s) has quit IRC [%s]", $nick, $host, $msg);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s (%s) has quit IRC [%s]\n",
		print_time(), $nick, $host, $msg if ($verbose);
}

## on_nick
# This gets called whenever someone on the channel changes their nickname
sub on_nick {
	my ($from, $newnick) = @_[ARG0, ARG1];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	# Update lastseen table
	my ($query, $sth, $msg);
	
	# Delete old record
	$query = "DELETE FROM lastseen WHERE nick = ? OR nick = ?";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick), lc($newnick));
	
	# Insert new record under old name
	$msg = $nick . " changed nick to " . $newnick;
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES (?, ?, ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick), $msg);

	# Insert new record under new name
	$msg = $newnick . " changed nick from " . $nick;
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES (?, ?, ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($newnick), $msg);
	
	# FIXME: find the channel in a supplied parameter to this function
	irclog($server{'channel'} => sprintf "-!- %s is now known as %s", $nick, $newnick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s is now known as %s\n",
		print_time(), $nick, $newnick if ($verbose);
}

## on_topic
# How can we possibly be on-topic here? ;)
# This runs whenever the channel changes topic 
sub on_topic {
	my ($from, $channel, $topic) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	if (!$topic) {
		irclog($channel => sprintf "-!- Topic unset by %s on %s", $nick, $channel);
		printf "[%s] %s!%s Topic unset by %s on %s", print_time(), 
			colour('-', '94'), colour('-', '94'), $nick, 
			$channel if ($verbose);
		return;
	}
	
	irclog($channel => sprintf "-!- %s changed the topic of %s to: %s", $nick, $channel, $topic);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s changed the topic of %s to: %s\n",
		print_time(), $nick, $channel, $topic if ($verbose);
}


## on_mode
# This gets called when channel modes are changed.
sub on_mode {
	my ($from, $to, $mode, $operands) = @_[ARG0, ARG1, ARG2, ARG3];
	my ($nick, $host) = split(/!/, $from);
	$_[HEAP]->{seen_traffic} = 1;
	$mode .= " ".$operands if ($operands);

	if (lc($to) eq lc($server{'nick'})) {
		irclog('status' => sprintf "-!- Mode change [%s] for user %s", $mode, $nick);
		printf "[%s] %s!%s Mode change [%s] for user %s\n", 
			print_time(), colour('-', '94'), colour('-', '94'), 
			$mode, $nick if ($verbose);
		return;
	}
	irclog($to => sprintf "-!- Mode/%s [%s] by %s", $to, $mode, $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Mode/%s [%s] by %s\n", 
		print_time(), colour($to, "96"), $mode, $nick if ($verbose);
}

## on_ctcp_ping
# This gets called whenever you get /ctcp ping'd. Should return a nice
# response to the pinger
sub on_ctcp_ping {
	my ($from, $to, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);
	
	$_[HEAP]->{seen_traffic} = 1;

	# Protocol says to use PONG in ctcpreply, but irssi & xchat for some 
	# reason only reacts to PING... mrmblgrbml
	$msg = "PING ".$msg;
	$irc->yield(ctcpreply => $nick => $msg);

	irclog('status' => sprintf "-!- CTCP PING request from %s recieved", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP PING request from %s recieved\n",
		print_time(), $nick if ($verbose);
}

## on_ctcpreply_ping
# Subroutine for handling ping replies. Just gives the lag results for
# outgoing pings.
# FIXME: Use microseconds instead
sub on_ctcpreply_ping {
	my ($from, $to, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	if (!$msg) {
		irclog('status' => sprintf "-!- Recieved invalid CTCP PING REPLY from %s", $nick);
		printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Recieved invalid CTCP PING REPLY from %s\n",
			print_time(), $nick if (!$silent);
		return;
	}

	my $diff = time - $msg;
	irclog('status' => sprintf "-!- CTCP PING REPLY from %s: %s sec", $nick, $diff);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP PING REPLY from %s: %s sec\n",
		print_time(), $nick, $diff if (!$silent);
}

## on_ctcp_version
# This subroutine reacts to the /ctcp version, returning the current 
# version of this script
sub on_ctcp_version {
	my ($from, $to, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	$irc->yield(ctcpreply => $nick => SCRIPT_NAME." : ".SCRIPT_VERSION." : ".SCRIPT_SYSTEM);
	irclog('status' => sprintf "-!- CTCP VERSION request from %s recieved", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION request from %s recieved\n",
		print_time(), $nick if ($verbose);
}

## on_ctcpreply_version
# This subroutine prints out version replies to stdout
sub on_ctcpreply_version {
	my ($from, $to, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	if (!$msg) {
		irclog('status' => sprintf "-!- Recieved invalid CTCP VERSION REPLY from %s", $nick);
		printf "[%s] %s!%s Recieved invalid CTCP VERSION REPLY from %s\n", 
			print_time(), colour('-', '94'), colour('-', '94'), 
			$nick if (!$silent);
		return;
	}

	irclog('status' => sprintf "-!- CTCP VERSION REPLY from %s: %s", $nick, $msg);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION REPLY from %s: %s\n",
		print_time(), $nick, $msg if (!$silent);
}

## on_ctcp_time
# This returns the local system time, to whoever sent you a CTCP TIME
sub on_ctcp_time {
	my $from = $_[ARG0];
	my ($nick) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	$irc->yield(ctcpreply => $nick => "TIME ".scalar localtime time);

	irclog('status' => sprintf "-!- CTCP TIME recieved from %s", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP TIME recieved from %s\n",
		print_time(), $nick if ($verbose);
}

## on_ctcp_finger
# I can't remember what this i supposed to return, so give a rude 
# response
sub on_ctcp_finger {
	my $from = $_[ARG0];
	my ($nick) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	my @replies = ("Dont finger me there...",
			"Don't your fscking dare!",
			"Screw off!",
			"Yes, please",
			"Please don't kill me... she did");
	$irc->yield(ctcpreply => $nick => "FINGER ".$replies[rand scalar @replies]);

	irclog('status' => sprintf "-!- CTCP FINGER recieved from %s", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP FINGER recieved from %s\n",
		print_time(), $nick if ($verbose);
}

## on_disconnected
# This gets called whenever we get disconnected from a server. Will
# attempt to reconnect after sleeping for five seconds
sub on_disconnected {
	my ($kernel, $server) = @_[KERNEL, ARG0];

	irclog('status' => sprintf "-!- Disconnected from %s", $server);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Disconnected from %s\n", 
		print_time(), $server if (!$silent);
	$kernel->yield("reconnect");
}

## on_error
# We get this whenever we recieve an error, usually followed by a dropping of 
# the connection. Print message and reconnect
sub on_error {
	my ($kernel, $error) = @_[KERNEL, ARG0];
	irclog('status' => sprintf "-!- ERROR: %s", $error);
	printf STDERR "[%s] ".colour("-", "94")."!".colour("-", "94")." ".error("ERROR:")." %s\n", 
		print_time(), $error if (!$silent);
}

## on_socketerr
# This is for whenever we fail to establish a connection. But let's try again!
sub on_socketerr {
	my ($kernel, $error) = @_[KERNEL, ARG0];
	irclog('status' => sprintf "-!- Failed to establish connection to %s: %s", $server{'server'}, $error);
	printf STDERR "[%s] %s!%s Failed to establish connection to %s: %s\n", 
		print_time(), colour('-', '94'), colour('-', '94'), 
		$server{'server'}, $error if (!$silent);
	$kernel->yield("reconnect");
}

## on_kick
# Whenever someone (possibly yourself) recieves a kick, this is run.
sub on_kick {
	my ($from, $channel, $to, $msg) = @_[ARG0, ARG1, ARG2, ARG3];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	if ($to eq $irc->nick_name) {
		# We were kicked...
		irclog('status' => sprintf "-!- Recieved KICK by %s from %s [%s]", $nick, $channel, $msg);
		printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Recieved KICK by %s from %s [%s]\n",
			print_time(), $nick, $channel, $msg if (!$silent);
		return;
	}

	irclog('status' => sprintf "-!- %s was kicked from %s by %s [%s]", $to, $channel, $nick, $msg);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s was kicked from %s by %s [%s]\n", 
		print_time(), colour($to, '96'), $channel, $nick, $msg if ($verbose);
}

## Trap routines
sub ABORT {
	irclog('status' => sprintf "-!- Log closed %s", scalar localtime);
	print "Caught Interrupt (^C), Aborting\n";
	# Messy as hell, but fast!
	$irc->disconnect if ($irc);
	$dbh->disconnect or warn("Couldn't disconnect from database: $dbh->errstr") if ($dbh);
	exit(1);
}

__END__

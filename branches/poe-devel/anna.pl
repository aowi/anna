#!/usr/bin/perl
use strict;
use warnings;

## Anna^ IRC Bot

# Version 0.21. Copyright (C) 2006 Anders Ossowicki <and@vmn.dk>

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

## DEBUG (uncomment when debugging)
use Data::Dumper;
## END DEBUG


## Set basic stuff like vars and the like up

## Trap signals
$SIG{'INT'} = 'ABORT';

## Global vars

# Locales for the script
use constant STARTTIME		=> time;
use constant SCRIPT_NAME 	=> "Anna^ IRC Bot";
use constant SCRIPT_VERSION 	=> "0.30-svn-poe";
use constant SCRIPT_RELEASE 	=> "Sat Nov 25 19:47:58 CET 2006";
use constant SCRIPT_SYSTEM 	=> `uname -sr`;
use constant DB_VERSION 	=> 1;

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
our $dbfile = $ENV{'HOME'}."/.anna/anna.db";
our $colour = 1;
our $silent = 0;
our $verbose = 0;
our $trigger = "!";
our @bannedwords;

## Read config-file (overrides default)
# By making two seperate if-conditions, the values of /etc/anna.conf will be
# overridden _if_, and only if, they are also set in ~/.anna/config. This 
# seems to be the most failsafe method.
if (-e "/etc/anna.conf") {
	parse_configfile("/etc/anna.conf");
}
if (-e $ENV{'HOME'}."/.anna/config") {
	parse_configfile($ENV{'HOME'}."/.anna/config");
} 

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
	'dbfile|D=s' => \$dbfile,
	'version|V' => \&version,
	'help|h|?' => sub { usage(0) }
) or die( usage(1) );

# Make verbose override silent
if (($verbose) && ($silent)) {
	$silent = 0;
}

# Default values. These doesn't change during runtime
our %default = %server;

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

print "Initializing perl modules... " if ($verbose);
use POE;
use POE::Component::IRC;
use DBI;
use LWP::UserAgent;
use HTML::Entities;
print "done!\n" if ($verbose);

print "Creating connection to irc server: $server{'server'}... "  if ($verbose);
my $irc = POE::Component::IRC->spawn(ircname 	=> $server{'name'},
				     port	=> $server{'port'},
				     username	=> $server{'username'},
				     server	=> $server{'server'},
				     nick	=> $server{'nick'}
				    ) or die(error("\nCan't create connection to $server{'server'}"));
print "done!\n" if ($verbose);

print "Connecting to SQLite database $dbfile... " if ($verbose);
# Test if database exists
if (!(-e $dbfile)) {
	# We _could_ recover by copying over the default database, but that 
	# might not be what the user wants 
	die(error("\nCouldn't find SQLite database file: ".$dbfile.".\nPlease check that the file exists and is readable\n"));
}
# TODO: Make this work
#my %dbi_attr = {
#	"PrintError" => 0,
#	"PrintWarn" => 0,
#	"AutoCommit" => 1,
#	"RaiseError" => 0
#};
my $dbh = DBI->connect("dbi:SQLite:dbname=".$dbfile, undef, undef)
	or die(error("Can't connect to SQLite database $dbfile: $DBI::errstr"));
print "done!\n" if ($verbose);

# Initialize Anna^ - run various checks
anna_init();

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
		irc_notice		=> \&on_notice,
		irc_part		=> \&on_part,
		irc_public 		=> \&on_public,
		irc_quit		=> \&on_quit,
		irc_topic		=> \&on_topic,
#		irc_whois		=> \&on_whois, # Not handled yet!
#		irc_whowas		=> \&on_whowas, # Ditto
#		irc_376			=> \&on_endofmotd, # Replaced by 001
		irc_332			=> \&on_332,
		irc_333			=> \&on_333,

		# CTCP stuff
		irc_ctcp_ping		=> \&on_ctcp_ping,
		irc_ctcpreply_ping	=> \&on_ctcpreply_ping,
		irc_ctcp_version	=> \&on_ctcp_version,
		irc_ctcpreply_version	=> \&on_ctcpreply_version,
		irc_ctcp_time		=> \&on_ctcp_time,
		irc_ctcp_finger		=> \&on_ctcp_finger,

		# Error handling
#		irc_401			=> \&err_nosuchuser,
#		irc_403			=> \&err_nosuchchannel,
#		irc_405			=> \&err_toomanychannels, # Not handled yet!
		irc_433			=> \&err_nick_taken,
		
		

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

	printf "[%s] Registering for all events... ", print_time() if (!$silent);
	$irc->yield(register => 'all');
	printf "done\n" if (!$silent);
	printf "[%s] Connecting to irc server: %s:%d...\n", print_time(), $server{'server'}, $server{'port'} if (!$silent);
	# Connect
	$kernel->yield("connect");
}

## _default 
# Handler for all unhandled events. This produces some debug info
# NOT TO BE INCLUDED IN RELEASES!
sub _default {
	print "\n\n========================DEBUG INFO===========================\n";
	my ($event, $args) = @_[ARG0 .. $#_];
	my @output = ( "$event: " );

	foreach my $arg ( @$args ) {
		if ( ref($arg) eq 'ARRAY' ) {
			push( @output, "[" . join(" ,", @$arg ) . "]" );
		} else {
			push ( @output, "'$arg'" );
		}
	}
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

## anna_init
# Run various init checks
sub anna_init {
	# Check for first-run
	if (!(-e $ENV{'HOME'}."/.anna/")) {
		# First run
		print "This seems to be the first time you're running Anna^... welcome!\n" if ($verbose);
		print "Creating ~/.anna directory to store information... " if ($verbose);
		mkdir $ENV{'HOME'}."/.anna" or die(error("\nFailed to create ~/.anna/ directory. $!"));
		print "done!\n" if ($verbose);
		use File::Copy;
		# Copy database to home
		print "Creating database for Anna^ and filling it... " if ($verbose);
		copy("/usr/local/share/anna/anna.db", $ENV{'HOME'}."/.anna/anna.db") or die(error("\nFailed to copy /usr/local/share/anna/anna.db to ~/.anna/anna.db: $!"));
		print "done\n" if ($verbose);
		# Copy config to locale
		print "Creating standard configuration file in ~/.anna/config... " if($verbose);
		copy("/etc/anna.conf", $ENV{'HOME'}."/.anna/config") or die(error("Failed to copy /etc/anna.conf to ~/.anna/config: $!"));
		print "done\nYou're all set!\n" if ($verbose);
	}

	# Check database version
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
	} else {
		# System is too old... we only support 0.2x, so update from 
		# that
		printf "Your database is out of date. Performing updates... " if ($verbose);
		# Create admin table
		$query = "CREATE TABLE admin (option VARCHAR(255), value VARCHAR(255))";
		$sth = $dbh->prepare($query);
		$sth->execute();
		$query = "INSERT INTO admin (option, value) VALUES (?, ?)";
		$sth = $dbh->prepare($query);
		$sth->execute("db_version", 1);

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
		# TODO: We ought to check the tuples... oh well
		$sth->execute_array({ ArrayTupleStatus => undef}, \@order_keys, \@order_values);

		# Create roulette_stats
		$query = "CREATE TABLE roulette_stats (id INTEGER PRIMARY KEY UNIQUE, user TEXT UNIQUE, shots INTEGER, hits INTEGER, deathrate TEXT, liverate TEXT)";
		$sth = $dbh->prepare($query);
		$sth->execute();
		printf "done!\n" if ($verbose);
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
			$server{'server'} = $2 if ($1 eq 'Server');
			$server{'port'} = $2 if ($1 eq 'Port');
			$server{'nick'} = $2 if ($1 eq 'Nickname');
			$server{'username'} = $2 if ($1 eq 'Username');
			$server{'channel'} = $2 if ($1 eq 'Channel');
			$server{'name'} = $2 if ($1 eq 'Ircname');
			$server{'nspasswd'} = $2 if ($1 eq 'Nspasswd');

			# Script part
			$dbfile = $2 if ($1 eq 'Dbfile');
			$colour = $2 if ($1 eq 'Colour');
			$silent = $2 if ($1 eq 'Silent');
			$verbose = $2 if ($1 eq 'Verbose');

			# Bot part
			$trigger = $2 if ($1 eq 'Trigger');
			@bannedwords = split(' ', $2) if ($1 eq 'BannedWords');
		} else {
			print Dumper($_);
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
				$irc->kick($to => $nick => $1);
			}
		}
	} elsif ($type eq "msg") {
		# Private message (p2p)
		# This is meant for things that anna should _only_
		# respond to in private (ie. authentications).
	}
	
	## This part reacts to special words/phrases in the messages
	if ($msg =~ /^\Q$server{'nick'}\E.*poke/i) {
		$out = "Do NOT poke the bot!";
	}

	if ($msg =~ /^n., anime$/) {
		$out = $nick . ": get back to work, loser!";
	}
	if ($msg =~ /dumb bot/i) {
		$out = "Stupid human!";
	}
	if ($msg =~ /dance/i) {
		# TODO: use $kernel->delay instead
		$irc->yield(ctcp => $server{'channel'} => 'ACTION dances o//');
		sleep(1);
		$irc->yield(ctcp => $server{'channel'} => 'ACTION dances \\\\o');
		sleep(1);
		$irc->yield(ctcp => $server{'channel'} => 'ACTION DANCES \\o/');
	}
	
	## Bot commands
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )mynotes$/) {
		$out = bot_mynotes($nick, $type);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )rstats$/) {
		$out = bot_roulette_stats();
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )search\s+(notes|quotes|all)\s+(.*)$/) {
		$out = bot_search($2, $3);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )rot13\s+(.*)$/i) {
		$out = bot_rot13($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )note(\s+(.*)|)$/i) {
		$out = bot_note($3, $nick);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )google (.*)$/i) {
		$out = bot_googlesearch($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )fortune(\s+.*|)$/i) {
		$out = bot_fortune($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )karma (.*)$/i) {
		$out = bot_karma($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )quote$/i) {
		$out = bot_quote();
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )addquote (.*)$/i) {
		$out = bot_addquote($nick, $2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )bash(\s+(\#|)([0-9]+|random)|)$/i) {
		$out = bot_bash($4);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )roulette$/i) {
		$out = bot_roulette($nick);
	}
	if ($msg =~/^(\Q$trigger\E|\Q$server{'nick'}\E: )reload$/i) {
		$out = bot_reload();
	}
	if ($msg =~ /^(\Q$trigger\Equestion|\Q$server{'nick'}\E:) .*\?$/i) {
		$out = $nick . ": ".bot_answer();
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )addanswer (.*)$/i) {
		$out = bot_addanswer($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )up(time|)$/i) {
		$out = bot_uptime();
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )lart (.*)$/i) {
		$out = bot_lart($nick, $2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )addlart (.*)$/i) {
		$out = bot_addlart($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )haiku$/i) {
		$out = bot_haiku();
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )addhaiku (.*)$/i) {
		$out = bot_addhaiku($2, $nick);
	}
	if ($msg =~ /^\Q$trigger\Edice (\d+d\d+)$/i) {
		$out = bot_dice($1, $nick);
	}
	if ($msg =~ /^(\d+d\d+)$/i) {
		$out = bot_dice($1, $nick);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )addorder (.*)$/i) {
		$out = bot_addorder($2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )order (.*)$/i) {
		$out = bot_order($nick, $2);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )seen (.*)$/i) {
		$out = bot_lastseen($nick, $2, $type);
	}
	if ($msg =~ /^(\Q$trigger\E|\Q$server{'nick'}\E: )meh$/i) {
		$out = "meh~";
	}


	return $out;
}

## Bot-routines
# These are the various subs for the bot's commands.

## bot_addanswer
# Add an answer to the database
sub bot_addanswer {
	my $answer = shift;

	my $query = "INSERT INTO answers (answer) VALUES (?)";
	my $sth = $dbh->prepare($query);
	$sth->execute($answer);
	return "Answer added to database, thanks!";
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
		if ($sth->fetchrow()) {
			return "I already have that item on my menu";
		}
		$query = "INSERT INTO orders (key, baka_order)
			     VALUES (?,?)";
		$sth = $dbh->prepare($query);
		$sth->execute($key, $order);
		return sprintf("Master, I am here to serve (%s)", $key);
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
			$rnd = int(rand($sides));
			
			if ($rnd == 0) {
				$rnd = $sides;
			}
			
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
		if ((-e "$_/fortune") && (-x "$_/fortune")) {
			my $fortune_app = $_."/fortune";
			
			# Parse arguments
			my $cmd_args = "";
			$cmd_args .= " -a" if ($args =~ s/\W-a\W//);
			$cmd_args .= " -e" if ($args =~ s/\W-e\W//);
			$cmd_args .= " -o" if ($args =~ s/\W-o\W//);
			# I most certainly hope escape_shell() is sufficient 
			# to avoid injections...
			$cmd_args .= " " . escape_shell($1) if ($args =~ /(.+)/);
			
			my $fortune = `$fortune_app -s $cmd_args 2>/dev/null`;
			return "No fortunes found" if $fortune eq '';
			$fortune =~ s/^\t+/   /gm;
			return $fortune;
		}
	}
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
	if ($nick eq 'me') {
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
	my ($table, $string) = @_;
	return 'FALSE' if (!$table or !$string);
	
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
		$out .= bot_search("quotes", $string);
		# The following line adds linebreak in case of no results
		$out =~ s/(No results for '$string')/$1\n/ig;
		$out .= "Search results in notes: ";
		$out .= bot_search("notes", $string);
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
	printf "[%s] Connecting to %s\n", print_time(), $server{'server'} if ($verbose);
	$irc->yield(connect => {});
}

## do_reconnect
# This handles reconnection when we've died for various reasons
sub do_reconnect {
	my $kernel = $_[KERNEL];
	# Disable autopings when disconnected
	$kernel->delay(autoping => undef);
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
	printf "[%s] Nick taken, trying %s...\n", print_time(), $newnick if (!$silent); 
	$irc->yield(nick => $newnick);
	$server{'nick'} = $newnick;
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

## on_332
# This is the topic announcement we recieve whenever we join a channel
# ->[0] is the channel, ->[1] is the topic
sub on_332 {
	my $msg = $_[ARG2];
	printf "[%s] Topic for %s: %s\n", print_time(), colour($msg->[0], '96'), $msg->[1]
		if ($verbose);
}

## on_333
# This numeric gives us the name of the person who sat the topic as well as the
# time he/she did that.
# ->[0] is the channel, ->[1] is the nick who sat the topic, ->[2] is the epoch
# timestamp the topic was set
sub on_333 {
	my $msg = $_[ARG2];
	printf "[%s] Topic set by %s [%s]\n", print_time(), $msg->[1], 
		scalar localtime($msg->[2]) if ($verbose);
}

## on_msg
# This is called whenever the client recieves a privmsg. 
sub on_msg {
	my ($kernel, $heap, $from, $to, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$heap->{seen_traffic} = 1;
	# Kill her own messages
	return if ($nick eq $server{'nick'});

	my $out = parse_message($kernel, $heap, $from, $to, $msg, 'msg');
	
	# Return if there's nothing to print
	return if ($out eq 'FALSE'); 
	
	my @lines = split(/\n/, $out);
	foreach(@lines) {
		$irc->yield(privmsg => $to => $_);
		$irc->yield(ctcp => $server{'channel'} => 'ACTION reloads...') if ($_ =~ /chamber \d of \d => \*bang\*/);
	}
}

## on_public
# This runs whenever someone post to a channel the bot is watching
sub on_public {
	my ($kernel, $heap, $from, $to, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

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
		$irc->yield(privmsg => $to => $_);
		if ($out =~ /chamber \d of \d => \*bang\*/) {
			$irc->yield(kick => $server{'channel'} => $nick => "Bang! You die...");
			$irc->yield(ctcp => $server{'channel'} => 'ACTION reloads...');
		}
	}
}

## on_notice
# This is for notices... I have no fucking clue yet
sub on_notice {
	my ($from, $msg) = @_[ARG0, ARG2];
	
	$_[HEAP]->{seen_traffic} = 1;
	# No ! should indicate server message
	if ($from !~ /!/) {
		printf "[%s] %s %s\n", print_time(), colour("!".$from, '92'), $msg 
			if (!$silent);
		return;
	}
	my ($nick, $host) = split(/!/, $from);
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
	printf "[%s] Joining %s...\n", print_time(), $server{'channel'} if (!$silent);
	$irc->yield(join => $server{'channel'});
#	$self->privmsg($server{'channel'}, "all hail your new bot");
}

## on_connected
# We recieve this once a connection is established. This does NOT mean the 
# server has accepted us yet, so we can't send anything
sub on_connected {
	my $kernel = $_[KERNEL];
	
	$_[HEAP]->{seen_traffic} = 1;
	$kernel->delay(autoping => 300);

	printf "[%s] Connected to %s\n", print_time(), $server{'server'} if (!$silent);
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

	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s [%s] has joined %s\n", 
		print_time(), colour($nick, '96'), colour($host, '96'), $channel if ($verbose);
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
		$msg = $nick . " quit IRC stating '" . $msg . "'";
	} else {
		$msg = $nick . " quit IRC with no reason";
	}
	
	# Delete old record
	$query = "DELETE FROM lastseen WHERE nick = ?";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick));
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES (?, ?, ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute(lc($nick), $msg);

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
	
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s is now known as %s\n",
		print_time(), $nick, $newnick if ($verbose);
}

## on_topic
# How can we possibly be on-topic here? ;)
# This is run whenever the channel changes topic - not on joins!
sub on_topic {
	my ($from, $channel, $topic) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	if (!$topic) {
		printf "[%s] Topic unset by %s on %s", print_time(), $nick, $channel 
			if ($verbose);
		return;
	}

	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s changed the topic of %s to: %s\n",
		$nick, $channel, $topic if ($verbose);
}


## on_mode
# This gets called when channel modes are changed.
sub on_mode {
	my ($from, $to, $mode, $operands) = @_[ARG0, ARG1, ARG2, ARG3];
	my ($nick, $host) = split(/!/, $from);
	$_[HEAP]->{seen_traffic} = 1;
	$mode .= " ".$operands if ($operands);

	if (lc($to) eq lc($server{'nick'})) {
		printf "[%s] Mode change [%s] for user %s\n", 
			print_time(), $mode, $nick if ($verbose);
		return;
	}
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
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP PING request from %s recieved\n",
		print_time(), $nick if ($verbose);
}

## on_ctcpreply_ping
# Subroutine for handling ping replies. Just gives the lag results for
# outgoing pings
# TODO: Use microseconds instead
sub on_ctcpreply_ping {
	my ($from, $to, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	if (!$msg) {
		printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Recieved invalid CTCP PING REPLY from %s\n",
			print_time(), $nick if (!$silent);
		return;
	}

	my $diff = time - $msg;
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
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION request from %s recieved\n",
		print_time(), $nick if ($verbose);
}

## on_ctcpreply_version
# This subroutine prints out version replies to stdout
sub on_ctcpreply_version {
	my ($from, $to, $msg) = @_[ARG0, ARG1, ARG2];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	if (!$msg) {
		printf "[%s] Recieved invalid CTCP VERSION REPLY from %s\n", 
			print_time(), $nick if (!$silent);
		return;
	}

	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION REPLY from %s: %s\n",
		print_time(), $nick, $msg if (!$silent);
}

## on_ctcp_time
# This returns the local system time, to whoever sent you a CTCP TIME
sub on_ctcp_time {
	my $from = $_[ARG0];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	$irc->yield(ctcpreply => $nick => "TIME ".scalar localtime time);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP TIME recieved from %s\n",
		print_time(), $nick if ($verbose);
}

## on_ctcp_finger
# I can't remember what this i supposed to return, so give a rude 
# response
sub on_ctcp_finger {
	my $from = $_[ARG0];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	
	my @replies = ("Dont finger me there...",
			"Don't your fscking dare!",
			"Screw off!",
			"Yes, please",
			"Please don't kill me... she did");
	$irc->yield(ctcpreply => $nick => "FINGER ".$replies[rand scalar @replies]);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP FINGER recieved from %s\n",
		print_time(), $nick if ($verbose);
}

## on_disconnected
# This gets called whenever we get disconnected from a server. Will
# attempt to reconnect after sleeping for five seconds
sub on_disconnected {
	my ($kernel, $server) = @_[KERNEL, ARG0];
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Disconnected from %s\n", 
		print_time(), $server if (!$silent);
	$kernel->yield("reconnect");
}

## on_error
# We get this whenever we recieve an error, usually followed by a dropping of 
# the connection. Print message and reconnect
sub on_error {
	my ($kernel, $error) = @_[KERNEL, ARG0];
	printf STDERR "[%s] ".colour("-", "94")."!".colour("-", "94")." ".error("ERROR:")." %s\n", 
		print_time(), $error if (!$silent);
}

## on_socketerr
# This is for whenever we fail to establish a connection. But let's try again!
sub on_socketerr {
	my ($kernel, $error) = @_[KERNEL, ARG0];
	printf STDERR "[%s] Failed to establish connection to %s: %s\n", 
		print_time(), $server{'server'}, $error if (!$silent);
	$kernel->yield("reconnect");
}

## on_kick
# Whenever someone (possibly yourself) recieves a kick, this is run.
sub on_kick {
	my ($from, $channel, $to, $msg) = @_[ARG0, ARG1, ARG2, ARG3];
	my ($nick, $host) = split(/!/, $from);

	$_[HEAP]->{seen_traffic} = 1;
	if ($to eq $irc->nick_name) {
		printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Recieved KICK by %s from  %s [%s]\n",
			print_time(), $nick, $channel, $msg if (!$silent);
		return;
	}
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." %s was kicked from %s by %s [%s]\n", 
		print_time(), colour($to, '96'), $channel, $nick, $msg if ($verbose);
}

## Trap routines
sub ABORT {
	print "Caught Interrupt (^C), Aborting\n";
	# Messy as hell, but fast!
	$irc->disconnect if ($irc);
	$dbh->disconnect or warn("Couldn't disconnect from database: $dbh->errstr") if ($dbh);
	exit(1);
}

__END__

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

# Anna^ is an IRC bot written in perl. She utilizes the perl module 
# Net::IRC and does various things. For more information, please see 
# the included documentation, or read the comments in this file.

# The name Anna^ comes from the horrible song, 'Boten Anna' by 
# BassHunter. The correct name of the bot (according to the music video
# is Anna^, and this is the name the bot will try to connect with. If 
# that fails, she will try a number of variations of the name.
# A number of functions are from an old, unreleased bot named kanako. 
# Kanako was basically just a bunch of scripts for the irssi IRC 
# client.

# Questions, comments, general bitching, nude pics and beer goes to 
# Anders Ossowicki <and@vmn.dk>.

## DEBUG
#use Data::Dumper;
#use Switch;
## END DEBUG

## Global vars

# Starttime - used to calculate uptime
our $start = time;

# Locales for the script
our %script;
$script{'name'} = "Anna^ IRC Bot";
$script{'version'} = "0.21";
$script{'release_date'} = "Wed Sep  6 19:29:16 CEST 2006";
$script{'system'} = `uname -sr`;

# Server information
our %server;
$server{'server'} = "irc.blitzed.org";
$server{'nick'}	= "Anna^";
$server{'username'} = "anna";
$server{'port'} = "6667";
$server{'channel'} = "#frokostgruppen";
$server{'name'} = "Boten Anna";
$server{'nspasswd'} = "";

# Default values. These doesn't change during runtime
our %default = %server;

# DB File
our $dbfile = $ENV{'HOME'}."/.anna/anna.db";

# The verbose mode may be invoked, either by changing this value, or 
# using the -v flag, when running the script. Under verbose mode, CTCP 
# REQUESTs and other miscallaneous information will be printed. All 
# status messages will be printed to stdout no matter what.
our $verbose = 0;


## Read command-line arguments
# Check for verbose mode first

my $arg_out;
foreach(@ARGV) {
	if (($_ eq "--verbose") or ($_ eq "-v")) {
		$verbose = 1;
		$arg_out .= "Verbose mode\n";
	}
}
my $i = 0;
foreach(@ARGV) {
	if (($_ eq "--server") or ($_ eq "-s")) {
		$server{'server'} = $ARGV[$i+1];
		$arg_out .= "Changed server to $server{'server'}\n" if $verbose == 1;
	} elsif (($_ eq "--channel") or ($_ eq "-c")) {
		my $chan = $ARGV[$i+1];
		if ($chan !~ /^\#.*$/) {
			$chan = "#".$chan;
		}
		$server{'channel'} = $chan;
		$arg_out .= "Changed channel to $server{'channel'}\n" if $verbose == 1;
	} elsif (($_ eq "--nick") or ($_ eq "-n")) {
		$server{'nick'} = $ARGV[$i+1];
		$arg_out .= "Changed nick to $server{'nick'}\n" if $verbose == 1;
	} elsif (($_ eq "--name") or ($_ eq "-a")) {
		$server{'name'} = $ARGV[$i+1];
		$arg_out .= "Changed name to $server{'name'}\n" if $verbose == 1;
	} elsif (($_ eq "--user") or ($_ eq "-u")) {
		$server{'username'} = $ARGV[$i+1];
		$arg_out .= "Changed username to $server{'username'}\n" if $verbose == 1;
	} elsif (($_ eq "--port") or ($_ eq "-p")) {
		$server{'port'} = $ARGV[$i+1];
		$arg_out .= "Changed port to $server{'port'}\n" if $verbose == 1;
	} elsif (($_ eq "--nspasswd") or ($_ eq "-P")) {
		$arg_out .= "Warning: Typing your NickServ password on the command-line is unsafe!\n";
		$server{'nspasswd'} = $ARGV[$i+1];
		$arg_out .= "Using NickServ for identifying\n" if $verbose == 1;
	} elsif (($_ eq "--dbfile") or ($_ eq "-D")) {
		if (!(-e $ARGV[$i+1])) {
			print "SQLite Database does not exist! Please create it first\n";
			exit(1);
		} else {
			$dbfile = $ARGV[$i+1];
		}
		$arg_out .= "Using $dbfile as default sqlite database" if $verbose == 1;
	} elsif (($_ eq "--version") or ($_ eq "-V")) {
		print "$script{'name'} version $script{'version'}. Released under the GNU GPL\n";
		exit(0);
	} elsif (($_ eq "--help") or ($_ eq "-h")) {
		usage();
		exit(0);
	} elsif (($_ eq "--verbose") or ($_ eq "-v")) {
		# We need this to work around -v flag not being checked for here
	} else {
		if ($_ =~ /^-.*$/){
			print "anna.pl: unrecognized option: '".$_."'.";
			print "\nTry `perl anna.pl --help` for more information.\n";
			exit(1);
		}
	}
	$i += 1;
}

# Print welcome message, disclaimer and argument changes
print $script{'name'}, " version ", $script{'version'}, ", Copyright (C) 2006 Anders Ossowicki\n";
print $script{'name'}, " comes with ABSOLUTELY NO WARRANTY; for details, see LICENSE.\n";
print "This is free software, and you are welcome to redistribute it under certain conditions\n";
print $arg_out;

print "Initiating perl modules\n" if $verbose == 1;
use Net::IRC;
use DBI;
use LWP::UserAgent;

my $irc = new Net::IRC;

print "Creating connection to irc server: $server{'server'}...\n" if $verbose == 1;

my $conn = $irc->newconn(Nick		=>	$server{'nick'},
			 Server 	=>	$server{'server'},
			 Username	=>	$server{'username'},
			 Port		=>	$server{'port'},
			 Name		=>	$server{'name'})
	or die("Can't create connection to $server{'server'}: $!");

print "Connecting to SQLite database: $dbfile...\n" if $verbose == 1;

my $dbh = DBI->connect("dbi:SQLite:dbname=".$dbfile, undef, undef)
	or die("Can't connect to SQLite database. Please check that the file
		exists and is readable\n");

## usage
# Print usage information
sub usage {
print <<EOUSAGE;
Anna^ IRC Bot version 0.21
Usage: perl anna.pl [OPTION]...

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
  -D, --dbfile <file>		specify the SQLite3 database-file.
  -v, --verbose			print verbose information.
  -V, --version			print version information and exit.
  -h, --help			show this message.

Note:   specifying your nickserv password on the command-line is unsafe. You
	should set it in the file instead.
All options listed here can be set within the file as well.

Anna^ IRC Bot is a small and versatile IRC-bot with various functionality.
Please report bugs to and\@vmn.dk

EOUSAGE
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
## Calculates the difference between two unix times and returns
# a string like '15d 23h 42m 15s ago.'
sub calc_diff {
	my ($when) = @_;
	my $diff = (time() - $when);
	my $day = int($diff / 86400); $diff -= ($day * 86400);
	my $hrs = int($diff / 3600); $diff -= ($hrs * 3600);
	my $min = int($diff / 60); $diff -= ($min * 60);
	my $sec = $diff;
	
	return "${day}d ${hrs}h ${min}m ${sec}s";
}


## parse_message
# This is where everything take place. Both on_msg (privmsgs) and 
# on_public (privmsgs to channels) send the message along with 
# important information to this subroutine.
# parse_message should return either text to be printed, or nothing.
# NOTE: parse_message must _never_ send anything to the irc-servers.
# The relevant subroutines should do that.
# The subroutines called from within parse_message may print stuff, but
# should return 'FALSE' in that case, to avoid printing things twice.
sub parse_message {
	my ($self, $event) = @_;
	my $msg = ($event->args)[0];
	my $type = $event->format;
	
	my $out = 'FALSE';

	if ($type eq "public") {
		# Public message (to a channel)
		# This part is meant for things that _only_ should
		# be monitored in channels
		
		# Lastseen part
		if ($msg !~ /^!seen .*$/) {
			bot_lastseen_newmsg($self, $event);
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
		$out = $event->nick . ": get back to work, loser!";
	}
	if ($msg =~ /dumb bot/i) {
		$out = "Stupid human!";
	}
	if ($msg =~ /DANCE/i) {
		$self->ctcp('ACTION', $server{'channel'}, "dances o//");
		sleep(1);
		$self->ctcp('ACTION', $server{'channel'}, "dances \\\\o");
		sleep(1);
		$self->ctcp('ACTION', $server{'channel'}, "DANCES \\o/");
	}
	


	## Bot commands
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )google (.*)$/i) {
		$out = bot_googlesearch($2);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )fortune$/i) {
		$out = bot_fortune();
	}
	if ($msg =~ /^(.*)(\+\+|\-\-)$/) {
		$out = bot_karma_update($1, $2, $event->nick);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )karma (.*)$/i) {
		$out = bot_karma($2);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )quote$/i) {
		$out = bot_quote();
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )addquote (.*)$/i) {
		$out = bot_addquote($self, $event, $2);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )bash (\#|)([0-9]+|random)$/i) {
		$out = bot_bash($3);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )roulette$/i) {
		$out = bot_roulette($self, $event);
	}
	if ($msg =~/^(!|\Q$server{'nick'}\E: )reload$/i) {
		$out = bot_reload($self, $event);
	}
	if ($msg =~ /^(!question|\Q$server{'nick'}\E:) .*\?$/i) {
		$out = $event->nick . ": ".bot_answer();
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )addanswer (.*)$/i) {
		$out = bot_addanswer($2, undef);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )up(time|)$/i) {
		$out = bot_uptime();
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )lart (.*)$/i) {
		$out = bot_lart($self, $event, $2);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )addlart (.*)$/i) {
		$out = bot_addlart($2);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )haiku$/i) {
		$out = bot_haiku();
	}
		
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )addhaiku (.*)$/i) {
		$out = bot_addhaiku($2, $event);
	}

	if ($msg =~ /(^!dice \d+d\d+|^\d+d\d+)/i) {
		$out = bot_dice($event, '1');
	}

	if ($msg =~ /^(!|\Q$server{'nick'}\E: )order (.*)$/i) {
		$out = bot_order($self, $event, $2);
	}
	
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )seen (.*)$/i) {
		$out = bot_lastseen($self, $event, $2);
	}
	if ($msg =~ /^(!|\Q$server{'nick'}\E: )meh$/i) {
		$out = "meh~";
	}

	return $out;
}

## Bot-routines
# These are the various subs for the bot's commands.

## bot_googlesearch
# Search google. Returns the first hit
sub bot_googlesearch {
	my $query = $_[0];
	return 'FALSE' if ($query eq '');
	
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
	my @pages = grep(/Similar&nbsp;pages/, @lines);

	# Remove empty results - should-be idiotproof method.
	my $i;
	for ($i = 0; $i <= $#pages; $i++) {
		$pages[$i] =~ s/\s+.*//g;
		if ($pages[$i] =~ /(^\n|\s+\n)/){ splice(@pages, $i, 1) };
		if ($pages[$i] !~ /\./){ splice(@pages, $i, 1) };
	}
	for ($i = 0; $i <= $#pages; $i++) {
		$pages[$i] =~ s/\&lt\;/\</gi;
		$pages[$i] =~ s/\&gt\;/\>/gi;
		$pages[$i] =~ s/\&amp\;/\&/gi;
		$pages[$i] =~ s/\&quot\;/\"/gi;
		$pages[$i] =~ s/\&nbsp\;/\ /gi;
	}

	return "Sorry - google didn't return any results :(" if (@pages == 0);
	return "http://".$pages[0];
}

## bot_fortune
# Prints a fortune, if fortune is installed
sub bot_fortune {
	my @path = split(':', $ENV{'PATH'});
	foreach (@path) {
		if ((-e "$_/fortune") && (-x "$_/fortune")) {
			my $fortune_app = $_."/fortune";
			my $fortune = `$fortune_app -s`;
			$fortune =~ s/^\t+/   /gm;
			return $fortune;
		}
	}
	print "Failed to fetch fortune - make sure fortune is installed, and in your \$PATH\n"
		if $verbose == 1;
	return "No fortune, sorry :-(";
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

	my $query = "SELECT * FROM karma WHERE word = '".$word."' LIMIT 1";
	my $sth = $dbh->prepare($query);
	$sth->execute();
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
			SET karma = '".$karma."', user = '".$nick."' 
			WHERE id = '".$row[0]."'";
		$sth = $dbh->prepare($query);
		$sth->execute();
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
			VALUES ('".$word."', '".$karma."', '".$nick."')";
		$sth = $dbh->prepare($query);
		$sth->execute();
		# No need to inform of the karma-change
		return 'FALSE';
	}
}

# bot_karma
# Returns the current karma for a word
sub bot_karma {
	my $word = $_[0];

	my $query = "SELECT * FROM karma WHERE word = '".$word."' LIMIT 1";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my @row;
	if (@row = $sth->fetchrow()) {
		return "Karma for '".$word."': ".$row[2];
	}
	return "Karma for ".$word.": 0";
}

## bot_quote
# This returns a random quote from a local quote database
# TODO: Make it possible to do searches in it
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

## bot_addquote 
# This is used to add a quote to the database
sub bot_addquote {
	my ($self, $event, $quote) = @_;
	$quote = $dbh->quote($quote);
	my $nick = $dbh->quote($event->nick);
	my $query = "INSERT INTO quotes (quote, author) VALUES (".$quote.", ".$nick.")";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	return "Quote inserted. Thanks ".$event->nick;
}
## bot_bash
# Takes one argument, the number of the bash quote.
# Returns the quote.
sub bot_bash {
	my $nr = $_[0];

	my $ua = new LWP::UserAgent;
	$ua->agent("Mozilla/5.0" . $ua->agent);
	my $request;
	if ($nr eq 'random') {
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

	# TODO: Gotta find something smarter than this
	my $quote = "";
	foreach (@lines){
		s/\&lt\;/\</gi;
		s/\&gt\;/\>/gi;
		s/\&amp\;/\&/gi;
		s/\&quot\;/\"/gi;
		s/\&nbsp\;/\ /gi;
		$quote .= $_."\n";
	}
	return $quote;
}

## bot_uptime
# Returns current uptime of the bot
sub bot_uptime {
	return "Uptime: " . calc_diff($start);
}

## bot_reload
# Reloads the roulette gun (only for weenies)
sub bot_reload {
	my ($self, $event) = @_;

	my $query = "DELETE FROM roulette_shots";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	$self->ctcp('ACTION', $server{'channel'}, "reloads...");
	return 'FALSE';
}


## bot_roulette
# Random chance of getting killed (kicked)
# Do you feel lucky?
sub bot_roulette {
	my ($self, $event) = @_;
	
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
		$out = $event->nick . ": chamber " . $shot . " of 6 => *bang*";
		$shot = 0;
	} else {
		$out = $event->nick . ": chamber " . $shot . " of 6 => *click*";
		$query = "INSERT INTO roulette_shots (shot, hit) VALUES (".$shot.", ".$hit.")";
		$sth = $dbh->prepare($query);
		$sth->execute();
	}
	return $out;
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

## bot_addanswer
# Add an answer to the database
sub bot_addanswer {
	my ($answer, undef) = @_;
	$answer = $dbh->quote($answer);

	my $query = "INSERT INTO answers (answer) VALUES (".$answer.")";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	return "Answer added to database, thanks!";
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

## bot_addhaiku
# This subroutine adds a haiku poem to the database
# params is the poem to be added and $event (to get the author)
sub bot_addhaiku {
	my ($haiku, $event) = @_;
	
	if ($haiku =~ /.* ## .* ## .*/){
		my $author = $event->nick;
		$haiku = $dbh->quote($haiku);
		my $query = "INSERT INTO haiku (poem, author) 
				VALUES (".$haiku.", '".$author."')";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		return 'Haiku inserted, thanks '.$author;
	}
	return "Wrong syntax for haiku. Should be '<line1> ## <line2> ## <line3>'";
}

## bot_dice
# This returns the result of a die roll (or several)
# Syntax is '!dice <amount>d<sides>' or just <int>d<int>
#### TODO: Truncate throws on more than 50 dice instead of removing it
sub bot_dice {
	my ($event, undef) = @_;
	
	my $dieroll = ($event->args)[0];
	$dieroll =~ s/!dice //i;
	if ($dieroll =~ /(\d+)d(\d+)/i) {
		my $dice = $1;
		my $sides = $2;

		if ($sides < 1) {
			return 'It seems ' . $event->nick . ' smoked too much pot. Or has anyone ever seen a die without sides?';
		}
		if ($sides == 1) {
			return $event->nick . ' will soon show us something wondrous - the first die with only one side!';
		}
		if ($sides >= 1000) {
			return $event->nick . ' needs to trap down on the sides. Seriously, try fewer sides!';
		}

		if ($dice < 1) {
			$dice = 1;
		}
		if ($dice >= 300) {
			return 'Is ' . $event->nick . ' going to take a bath in dice? Seriously, try fewer dice!';
		}

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
		my $out;
		if ($dice <= 50) {
			$out = $event->nick . ': ' . $value . ' (' . $throws . ')';
			return $out;
		}
		$out = $event->nick . '; ' . $value . ' (too many throws to show)';
		return $out;
	}
	# It shouldn't be possible to end up here, but anyway
	return 'Syntax error in diceroll. Correct syntax is <int>d<int>';
}

## bot_order
# Your very own bar!
# This sub should just return FALSE and then instead send an action
sub bot_order {
	my ($self, $event, $order) = @_;
	
	my %orders = (
		'coffee'	=> 'hands ## a steaming cup of coffee',
		'chimay'	=> 'hands ## a glass of Chimay',
		'pepsi'		=> 'gives ## a can of Star Wars Pepsi',
		'ice cream'	=> 'gives ## a chocolate ice cream with lots of cherries',
		'beer'		=> 'slides a beer down the bar counter to ##',
		'peanuts'	=> 'slides the bowl of peanuts down the bar counter to ##',
		'ice'		=> 'slips two ice cubes down ##\'s neck'
	);

	# Discover syntax
	my ($out, $key, $nick);
	if ($order =~ /(.*) for (.*)/i) {
		$key = $1;
		$nick = $2;
	} else {
		$key = $order;
		$nick = $event->nick;
	}
	if (exists($orders{$key})) {
		$out = $orders{$key};
		$out =~ s/##/$nick/;
	} else {
		$out = 'hands ' . $nick . ' ' . $key;
	}
	
	$self->ctcp('ACTION', $server{'channel'}, $out);
	return 'FALSE';
}

## bot_lastseen_newmsg
# This handles new messages in the channel, stores them in sqlite db
# for later retrieval with !seen command.
sub bot_lastseen_newmsg {
	my ($self, $event) = @_;

	my $nick = $event->nick;
	my $msg = ($event->args)[0];
	my $time = time;

	$nick = lc($nick);
	
	# Delete previous (if any) messages
	my $query = "DELETE FROM lastseen WHERE nick = '".$nick."'";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	
	# Insert new quote
	$msg = $nick .' last said \''.$msg.'\'';
	$msg = $dbh->quote($msg);
	
	$query = "INSERT INTO lastseen (nick, msg, time) 
			VALUES ('".$nick."', ".$msg.", ".$time.")";
	$sth = $dbh->prepare($query);
	$sth->execute();
	return;
}

## bot_lastseen
# This returns information on when a nick last was seen
sub bot_lastseen {
	my ($self, $event, $queried_nick) = @_;
	$queried_nick = lc($queried_nick);
	
	my ($query, $sth);

	if (($event->to)[0] eq $server{'channel'}) {
		# Update lastseen table
		$query = "DELETE FROM lastseen WHERE nick = '".$event->nick."'";
		$sth = $dbh->prepare($query);
		$sth->execute();
		my $newmsg = $event->nick . ' last queried information about ' . $queried_nick;
		$newmsg = $dbh->quote($newmsg);
		$query = "INSERT INTO lastseen (nick, msg, time) 
				VALUES ('".$event->nick."', ".$newmsg.", ".time.")";
		$sth = $dbh->prepare($query);
		$sth->execute();
	}

	if ($queried_nick eq lc($server{'nick'})) {
		return "I'm right here, dumbass";
	}
	if ($queried_nick eq lc($event->nick)) {
		return "Just look in the mirror, okay?";
	}
	if ($queried_nick =~ /^(me|myself|I)$/) {
		return "Selfcentered, eh?";
	}
	if ($queried_nick eq "jimmy hoffa") {
		return "I don't know either, try the Piranha Club";
	}
	if ($queried_nick =~ /dokuro(-chan|)/) {
		return "I don't know either, try the Wood Glue Club";
	}
	if ($queried_nick eq "the answer to life, the universe and everything") {
		return "42";
	}

	$query = "SELECT * FROM lastseen 
			WHERE nick = '".$queried_nick."' LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute();
	
	my @row;
	if (@row = $sth->fetchrow()) {
		my ($out, $time, $nick, $msg);
		$nick = $row[1];
		$msg = $row[2];
		$time = $row[3];
		$time = calc_diff($time);
		$out = $msg . ' ' . $time . ' ago.';
		return $out;
	} 

	return "Sorry, I couldn't find any information for $queried_nick";
}

## bot_lart
# This subroutine takes one argument (the nick to be lart'ed) and
# returns a random insult
sub bot_lart {
	my ($self, $event, $nick) = @_;
	
	if (lc($nick) eq lc($server{'nick'})) {
		return $event->nick . ": NAY THOU!";
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
	$lart =~ s/##/$nick/;

	$self->ctcp('ACTION', $server{'channel'}, $lart);
	return 'FALSE';
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
	$lart = $dbh->quote($lart);
	my $query = "INSERT INTO larts (lart) VALUES ($lart)";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	return "LART inserted!";
}

## Session routines
# These subroutines relates pruely to session handling

sub session_auth {
	my ($username, $pass) = @_;
	$username = $dbh->quote($username);
	my $query = "SELECT * FROM users WHERE username = '".$username."'";
	my $sth = $dbh->prepare($query);
	$sth->execute();
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

## on_msg
# This is called whenever the client recieves a privmsg. This is where 
# the fun takes place :)
sub on_msg {
	my ($self, $event) = @_;
	# Kill her own messages
	if ($event->nick ne $server{'nick'}) {
		my $out = parse_message($self, $event);
		if ($out ne 'FALSE') {
			# $event->nick denotes the sender. In case of 
			# primsgs, replies should be send there instead
			# of a channel. TODO:implement per-message 
			# return target.
			if ($out =~ /\\n/) {
				my @lines = split(/\\n/, $out);
				foreach(@lines) {
					$self->privmsg(($event->nick)[0], $_);
				}
			} else {
				$self->privmsg(($event->nick)[0], $out);
				if ($out =~ /chamber.*\*bang\*/) {
					$self->kick($server{'channel'}, $event->nick, "Bang! You die...");
					$self->ctcp('ACTION', $server{'channel'}, "reloads...");
				}
			}
		}
	}
}

## on_public
# This runs whenever someone post to a channel, the bot is watching
sub on_public {
	my ($self, $event) = @_;
	# Kill her own messages
	if ($event->nick ne $server{'nick'}) {
		my $out = parse_message($self, $event);
		if ($out ne 'FALSE') {
			# $event->to is the target channel. On public
			# messages, this is where the reply should be 
			# sent to.
			if ($out =~ /\n/) {
				my @lines = split(/\n/, $out);
				foreach(@lines) {
					$self->privmsg(($event->to)[0], $_);
				}
			} else {
				$self->privmsg(($event->to)[0], $out);
				if ($out =~ /chamber.*\*bang\*/) {
					$self->kick($server{'channel'}, $event->nick, "Bang! You die...");
					$self->ctcp('ACTION', $server{'channel'}, "reloads...");
				}
					
			}
		}
	}
}

## on_notice
# This is for notices... I have no fucking clue yet
sub on_notice {
	my ($self, $event) = @_;
	if ($event->nick eq "NickServ") {
		if (($event->args)[0] =~ /^Password accepted - you are now recognized.$/) {
			print "Authorized with NickServ!\n";
		}
	}
}


## on_connect
# This gets called whenever the script receives the event '376' - the 
# server code for "End of MOTD".
# on_connect takes responsibility for connecting to the appropriate channels
# and for negotiating with nickserv
sub on_connect {
	my $self = shift;
	
	print "Connected to $server{'server'}\n";
	if (($server{'nspasswd'} ne "") and ($default{'nick'} eq $server{'nick'})) {
		print "Identifying with services...\n";
		$self->privmsg("nickserv", "IDENTIFY $server{'nspasswd'}");
	}
	
	if (($server{'nick'} ne $default{'nick'}) and ($server{'nspasswd'} ne "")) {
		print "Real nick taken. Reclaiming custody from services...";
		$self->privmsg("nickserv", "GHOST $default{'nick'} $server{'nspasswd'}");
		$self->nick($default{'nick'});
		print "Done\n";
		print "Identifying with services...\n";
		$self->privmsg("nickserv", "IDENTIFY $server{'nspasswd'}");
	}
	print "Joining $server{'channel'}...\n";
	$self->join($server{'channel'});
#	$self->privmsg($server{'channel'}, "all hail your new bot");
}

## on_join
# This is used when someone enters the channel. Use this for 
# auto-op'ing or welcome messages
sub on_join {
	my ($self, $event) = @_;
	my $channel = ($event->to)[0];

	# Update lastseen table
	if ($channel eq $server{'channel'}) {
		my ($query, $sth, $msg);
		
		my $nick = lc($event->nick);
		$msg = $nick . " joined " . $channel;
		$msg = $dbh->quote($msg);
		
		# Delete old record
		$query = "DELETE FROM lastseen WHERE nick = '".$nick."'";
		$sth = $dbh->prepare($query);
		$sth->execute();

		$query = "INSERT INTO lastseen (nick, msg, time) 
			VALUES ('".$nick."', ".$msg.", ".time.")";
		$sth = $dbh->prepare($query);
		$sth->execute();
	}


	# Add any checks here. The three variables you can check on are:
	# * $channel - the channel user joined
	# * $event->nick - the nick of the user. If you use this, please
	#   confirm that the user has identified for it.
	# * $event->userhost - the host of the user, typically of the form 
	#   (~|)nick!username@host.tld.
	
	# Example: auto-op user based on hostmask
	if ($event->userhost =~ /^(~|)arkanoid\@.*static\.dsl\.webpartner\.net$/) {
		$self->mode($server{'channel'}, "+o", $event->nick);
	}
	#if ($event->userhost =~ /^botler\@62.79.146.119$/) {
	#	$self->mode($server{'channel'}, "-o", $event->nick);
	#}
	# Be very careful with this, as both nicks and hostmasks _can_
	# be faked. Some servers also utilizes hostmask protection, 
	# rendering recognition pretty hard. 

	printf "[".print_time()."] *** %s (%s) has joined channel %s\n", 
		$event->nick, $event->userhost, $channel if $verbose == 1;
}

## on_part
# This is called when someone leaves the channel
sub on_part {
	my ($self, $event) = @_;
	my $channel = ($event->to)[0];
	
	# Update lastseen table
	if ($channel eq $server{'channel'}) {
		my ($query, $sth, $msg);
		
		my $nick = lc($event->nick);

		if (($event->args)[0] ne '') {
			$msg = $nick . " left from " . $channel . " stating '" . ($event->args)[0] . "'";
		} else {
			$msg = $nick . " left from " . $channel . " with no reason";
		}
		$msg = $dbh->quote($msg);
		
		# Delete old record
		$query = "DELETE FROM lastseen WHERE nick = '".$nick."'";
		$sth = $dbh->prepare($query);
		$sth->execute();

		$query = "INSERT INTO lastseen (nick, msg, time) 
			VALUES ('".$nick."', ".$msg.", ".time.")";
		$sth = $dbh->prepare($query);
		$sth->execute();
	}



	printf "[".print_time()."] *** %s has left channel %s [%s]\n", 
		$event->nick, $channel, ($event->args)[0] if $verbose == 1;
}

## on_quit
# This signal is recieved when someone sends a QUIT notice (the disconnect)
sub on_quit {
	my ($self, $event) = @_;
	
	# Update lastseen table
	my ($query, $sth, $msg);
	
	my $nick = lc($event->nick);

	if (($event->args)[0] ne '') {
		$msg = $nick . " quit IRC stating '" . ($event->args)[0] . "'";
	} else {
		$msg = $nick . " quit IRC with no reason";
	}
	$msg = $dbh->quote($msg);
	
	# Delete old record
	$query = "DELETE FROM lastseen WHERE nick = '".$nick."'";
	$sth = $dbh->prepare($query);
	$sth->execute();
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES ('".$nick."', ".$msg.", ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute();

	printf "[".print_time()."] *** %s (%s) has quit IRC [%s]\n",
		$event->nick, $event->userhost, ($event->args)[0] if $verbose == 1;
}

## on_nick
# This gets called whenever someone on the channel changes their nickname
sub on_nick {
	my ($self, $event) = @_;
	my $newnick = lc(($event->args)[0]);
	my $nick = lc($event->nick);
	
	## Do all the fancy updating of variables on nick change here
	# Update lastseen table
	my ($query, $sth, $msg);
	
	
	# Delete old record
	$query = "DELETE FROM lastseen WHERE nick = '".$nick."' OR nick = '".$newnick."'";
	$sth = $dbh->prepare($query);
	$sth->execute();
	
	# Insert new record under old name
	$msg = $nick . " changed nick to " . $newnick;
	$msg = $dbh->quote($msg);
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES ('".$nick."', ".$msg.", ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute();

	# Insert new record under new name
	$msg = $newnick . " changed nick from " . $nick;
	$msg = $dbh->quote($msg);
	$query = "INSERT INTO lastseen (nick, msg, time) 
		VALUES ('".$newnick."', ".$msg.", ".time.")";
	$sth = $dbh->prepare($query);
	$sth->execute();
	

	printf "[".print_time()."] *** %s (%s) has quit IRC [%s]\n",
		$event->nick, $event->userhost, ($event->args)[0] if $verbose == 1;
	
	

	printf "[".print_time."] *** %s is now known as %s\n",
		$event->nick, $newnick if $verbose == 1;
}

## on_topic
# How can we possibly be on-topic here? ;)
# This is run whenever the channel changes topic (or announces it)
sub on_topic {
	my ($self, $event) = @_;
	if ($event->format eq "server") {
		# Server notice of topic
		printf "[".print_time()."] *** Topic for %s is %s\n",
			($event->args)[1], ($event->args)[2] if $verbose == 1;
	} else {
		# Genuine topic change
		printf "[".print_time()."] *** %s changed the topic of %s to %s\n",
			$event->nick, ($event->to)[0], ($event->args)[0]
			if $verbose == 1;
	}
}

## on_nick_taken
# This gets called whenever a connection attempt returns '433' - nick taken.
# The subroutine swaps between several different nicks
sub on_nick_taken {
	my $self = shift;
	
	my @nicks = ("$server{'nick'}^", "$server{'nick'}-", "$server{'nick'}_", "$server{'nick'}`");
	my $newnick = $nicks[rand scalar @nicks];
	print "Nick taken, trying $newnick...\n"; 
	$self->nick($newnick);
	$server{'nick'} = $newnick;
}

## on_mode
# This gets called when channel modes are changed.
sub on_mode {
	my ($self, $event) = @_;
	my $mode = join(' ',($event->args));
	my $channel = ($event->to)[0];
	
	# Only print notice if verbose is on
	printf "[".print_time()."] *** Mode/%s [%s] by %s\n", 
		$channel, $mode, $event->nick if $verbose == 1;
}

## on_ctcp_ping
# This gets called whenever you get /ctcp ping'd. Should return a nice
# response to the pingeri
#### TODO: Make it work... find out where the timestamp is
sub on_ctcp_ping {
	#print Dumper(@_);
	my ($self, $event) = @_;
	my $nick = $event->nick;
	
	$self->ctcp_reply($nick, join(' ', ($event->args)));
	print "[".print_time()."] *** CTCP PING request from $nick recieved\n" if $verbose == 1;
}

## on_ctcp_ping_reply
# Subroutine for handling ping replies. Just gives the lag results for
# outgoing pings
sub on_ctcp_ping_reply {
	my ($self, $event) = @_;
	my ($args) = ($event->args)[0];
	my ($nick) = $event->nick;

	$args = time - $args;
	print "[".print_time()."] *** CTCP PING REPLY from $nick: $args sec\n";
}

## on_ctcp_version
# This subroutine reacts to the /ctcp version, returning the current 
# version of this script
sub on_ctcp_version {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;

	# Reply
	$self->ctcp_reply($nick, join(' ', ($event->args, ($script{'name'}, ":", $script{'version'}, ":", $script{'system'}))));

	print "[".print_time()."] *** CTCP VERSION request from $nick recieved\n" 
		if $verbose == 1;;
}

## on_ctcp_version_reply
# This subroutine prints out version replies to stdout
sub on_ctcp_version_reply {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($args) = ($event->args)[0];

	print "[".print_time()."] *** CTCP VERSION REPLY from $nick: $args\n";
}

## on_ctcp_time
# This returns the local system time, to whoever sent you a CTCP TIME
sub on_ctcp_time {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my ($args) = ($event->args)[0];

	printf "** DEBUG: on_ctcp_time - args: %s\n", $args;
	$self->ctcp_reply($nick, int localtime);
	printf "[".print_time()."] *** CTCP TIME recieved from %s\n",
		$nick;
}

## on_ctcp_finger
# I can't remember what this i supposed to return, so give a rude 
# response
sub on_ctcp_finger {
	my ($self, $event) = @_;
	my @replies = ("Dont finger me there...",
			"Don't your fscking dare!",
			"Screw off!",
			"Yes, please",
			"Please don't kill me... she did");
	$self->ctcp_reply($event->nick, join(' ', "FINGER", $replies[rand scalar @replies]));
	printf "[".print_time()."] *** CTCP FINGER recieved from %s\n",
		$event->nick;
}

## on_disconnect
# This gets called whenever we get disconnected from a server. Will
# attempt to reconnect after sleeping for five seconds
sub on_disconnect {
	my ($self, $event) = @_;

	print "[".print_time()."] *** Disconnected from ", $event->from(), " (", 
		($event->args())[0], ")\nHmf... attempting to reconnect in 5 seconds...\n";
	sleep(5);
	$self->connect();
}

## on_kill
# This signal is recieved whenever an operator boots you off the network
sub on_kill {
	my ($self, $event) = @_;
	my $channel = ($event->to)[0];

	print "[".print_time()."] *** Recieved KILL from IRC Operator...... seeya!\n";
}

## on_kick
# Whenever someone (possibly yourself) recieves a kick, this is run.
sub on_kick {
	my ($self, $event) = @_;
	my $kicked = ($event->to)[0];

	if ($kicked eq $self->nick) {
		printf "[".print_time()."] *** Recieved KICK by %s from channel %s [%s]\n",
			$event->nick, ($event->args)[0], ($event->args)[1];
		return;
	}
	printf "[".print_time()."] *** %s was kicked from %s by %s [%s]\n", 
		$kicked, ($event->args)[0], $event->nick, ($event->args)[1]
		if $verbose == 1;
}

print "Initiating handler routines... ";
## Handle list
#
# Global Handles:
$conn->add_global_handler('376', \&on_connect);
$conn->add_global_handler('433', \&on_nick_taken);
$conn->add_global_handler('disconnect', \&on_disconnect);

# Local Handles:
$conn->add_handler('cping', \&on_ctcp_ping);
$conn->add_handler('crping', \&on_ctcp_ping_reply);
$conn->add_handler('cversion', \&on_ctcp_version);
$conn->add_handler('crversion', \&on_ctcp_version_reply);
$conn->add_handler('ctime', \&on_ctcp_time);
$conn->add_handler('cfinger', \&on_ctcp_finger);
$conn->add_handler('join', \&on_join);
$conn->add_handler('part', \&on_part);
$conn->add_handler('kill', \&on_kill);
$conn->add_handler('kick', \&on_kick);
$conn->add_handler('mode', \&on_mode);
$conn->add_handler('msg', \&on_msg);
$conn->add_handler('notice', \&on_notice);
$conn->add_handler('quit', \&on_quit);
$conn->add_handler('nick', \&on_nick);
$conn->add_handler('topic', \&on_topic);
$conn->add_handler('public', \&on_public);

print "Done!\n";
## Launch it, baby
print "Connecting to irc server: $server{'server'}:$server{'port'}...\n";
$irc->start;
print "Closing down... sayo nara\n";

__END__

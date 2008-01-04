package Anna::Utils;
use strict;
use warnings;

our @EXPORT = qw(INT colour warning error rtrim ltrim trim print_time calc_diff version usage);
our @EXPORT_OK = qw();
use Exporter;
our  @ISA = qw(Exporter);

use Anna::Config;
use Carp;

## Script constant
# Miscallaneus constants that are available to the main script
use constant STARTTIME          => time;
use constant SCRIPT_NAME        => "Anna^ IRC Bot";
use constant SCRIPT_VERSION     => "0.40-svn";
use constant SCRIPT_RELEASE     => "Thu May 17 17:02:20 CEST 2007";
use constant SCRIPT_SYSTEM      => `uname -sr`;
use constant SCRIPT_AUTHOR	=> "Anders Ossowicki";
use constant SCRIPT_EMAIL	=> 'and@vmn.dk';
use constant DB_LOCATION	=> "$ENV{'HOME'}/.anna/anna.db";
use constant DB_VERSION         => 2;

## version
# Params: N/A
# Prints version information and exits
sub version {
	printf "%s version %s, Copyright (C) 2006-2007 %s\n", 
		SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR;
	printf "%s comes with ABSOLUTELY NO WARRANTY; for details, see LICENSE.\n", 
		SCRIPT_NAME;
	printf "This is free software, and you are welcome to redistribute it under certain conditions\n";
	exit($_[0]) if defined $_[0] && $_[0] =~ /^\d+$/;
}

## usage
# Params: exit value
# Prints usage information and exits with the given value
sub usage {
	my $exit = shift;
	$exit ||= 0;
	print <<EOUSAGE;
@{[ SCRIPT_NAME ]} version @{[ SCRIPT_VERSION ]}
Usage: anna [OPTION]...

Mandatory arguments to long options are mandatory for short options too.
  -a, --name <name>             set the realname of the bot. This is not the
                                nickname!
  -c, --channel <channel>       set the channel to join.
  -s, --server <server>         set the server to connect to.
  -n, --nick <nick>             set the nickname of the bot. Default is Anna^
  -u, --username <user>         set the username of the bot.
  -p, --port <port>             set the port to connect to. Default is 6667
  -P, --nspasswd <passwd>       authorize with nickserv using <passwd> upon
                                successful connection.

      --no-color                don't use colours in terminal.
  -D, --dbfile <file>           specify the SQLite3 database-file.
  -v, --verbose                 print verbose information.
      --silent                  print nothing except critical errors.
  -V, --version                 print version information and exit.
  -d, --debug			print debugging information
  -h, --help                    show this message.

Note:   specifying your nickserv password on the command-line is unsafe. You
        should set it in the configuration file instead.
All options listed here can be set from the configuration file as well.

@{[ SCRIPT_NAME ]} is a small and versatile IRC-bot with various functionality.
Please report bugs to @{[ SCRIPT_EMAIL ]}

EOUSAGE
	exit($exit);
}

## error
# Params: error-string, conf-object
# Returns the colour-coded error message
sub error {
	my $errmsg = shift;
	unless (defined $errmsg) {
		carp "Missing string in Anna::Utils::error.";
		return;
	}
	# TODO: NOT a good solution, but worksfornow
	return $errmsg if (!-t STDERR);
	return colour($errmsg, "91");
}

## warning
# Params: warning-string, conf-object
# Returns the colour-coded warning
sub warning {
	my $warnmsg = shift;
	unless (defined $warnmsg) {
		carp "Missing string in Anna::Utils::warning.";
		return;
	}
	return colour($warnmsg, '93');
}

## colour
# Params: string, colour-code, conf-object
# Returns the colourcoded string, if appropriate
sub colour {
	my ($s, $c) = @_;
	unless (defined $s && defined $c) {
		carp "Missing string or colourcode in Anna::Utils::colour.";
		return;
	}
	my $conf = new Anna::Config;
	# Check if stdout is a tty. We probably need something better than this
	return $s if (!-t STDOUT);
	return "\e[" . $c . "m" . $s . "\e[00m" if ($conf->get('colour'));
	return $s;
}

## trim
# Params: string
# Returns new string without whitespace at beginning or end
sub trim {
        my $s = shift;
	unless (defined $s) {
		carp "Missing parameter in trim";
		return;
	}
        $s =~ s/^\s+//m;
        $s =~ s/\s+$//m;
        return $s;
}

## rtrim
# Params: string
# Returns new string without trailing whitespace
sub rtrim {
	my $s = shift;
	unless (defined $s) {
		carp "Missing parameter in rtrim";
		return;
	}
	$s =~ s/\s+$//m;
	return $s;
}

## ltrim
# Params: string
# Returns new string without leading whitespace
sub ltrim {
	my $s = shift;
	unless (defined $s) {
		carp "Missing paramter in ltrim";
		return;
	}
	$s =~ s/^\s+//m;
	return $s;
}

# calc_diff
# Params: epoch timestamp
# Returns formatted difference between param and current time
sub calc_diff {
	my $when = shift;
	my $diff = (time() - $when);
	my $day = int($diff / 86400); $diff -= ($day * 86400);
	my $hrs = int($diff / 3600); $diff -= ($hrs * 3600);
	my $min = int($diff / 60); $diff -= ($min * 60);
	my $sec = $diff;
	return sprintf "%dd %dh %dm %ds", $day, $hrs, $min, $sec;
}

# print_time
# Params: N/A
# Returns current time, nicely formatted for log/screen output
# TODO: Make it configurable
sub print_time {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	$hour = "0".$hour if (length($hour) == 1);
	$min = "0".$min if (length($min) == 1);
	$sec = "0".$sec if (length($sec) == 1);
	return sprintf "%d:%d:%d", $hour, $min, $sec;
}

1;

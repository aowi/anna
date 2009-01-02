# vim: set expandtab:tabstop=4:shiftwidth=4
package Anna::Utils;
use strict;
use warnings;

our @EXPORT = qw/INT colour warning error rtrim ltrim trim print_time 
                 calc_diff version usage print_formatted_message 
                 debug_print warn_print error_print verbose_print/;
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Anna::Config;
use Carp;
use POSIX qw(strftime);

## Script constant
# Miscallaneus constants that are available to the main script
# Constant: STARTTIME
# Epoch timestamp the bot was started
#
# Constant: SCRIPT_NAME
# Name of the script/bot
#
# Constant: SCRIPT_VERSION
# The current version of the bot. -svn, -git or -scm tagged on to the end means unreleased code
#
# Constant: SCRIPT_SYSTEM
# The system the bot runs on (just the output of uname -sr)
#
# Constant: SCRIPT_AUTHOR
# Name of the script-author
#
# Constant: SCRIPT_EMAIL
# Authors email
#
# Constant: CONFIGDIR
# Path to Anna^'s configuration directory
#
# Constant: DB_VERSION
# The DB layout version this script supports.

use constant STARTTIME          => time;
use constant SCRIPT_NAME        => "Anna^ IRC Bot";
use constant SCRIPT_VERSION     => "0.50-git";
use constant SCRIPT_RELEASE     => "Thu May 17 17:02:20 CEST 2007";
use constant SCRIPT_SYSTEM      => `uname -sr`;
use constant SCRIPT_AUTHOR      => "Anders Ossowicki";
use constant SCRIPT_EMAIL       => 'and@vmn.dk';
use constant CONFIGDIR          => "$ENV{'HOME'}/.anna/";
use constant DB_VERSION         => 2;

# sub: version
# Prints version information to stdout
# 
# If called with an exit signal as parameter, it will call exit() at the end
#
# Parameters: 
#   exit signal
#
# Returns:
#   1 or exits
sub version {
    printf "%s version %s, Copyright (C) 2006-2007 %s\n", 
        SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR;
    printf "%s comes with ABSOLUTELY NO WARRANTY; for details, see LICENSE.\n", 
        SCRIPT_NAME;
    printf "This is free software, and you are welcome to redistribute it under certain conditions\n";
    exit($_[0]) if defined $_[0] && $_[0] =~ /^\d+$/;
    return 1;
}

# sub: usage
# Prints usage information and quits
#
# Parameters: 
#   exit value
#
# Returns:
#   N/A (exits Anna^)
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
  -v, --verbose                 print verbose information.
      --silent                  print nothing except critical errors.
  -V, --version                 print version information and exit.
  -d, --debug           print debugging information
  -h, --help                    show this message.

Note:   specifying your nickserv password on the command-line is unsafe. You
        should set it in the configuration file instead.
All options listed here can be set from the configuration file as well.

@{[ SCRIPT_NAME ]} is a small and versatile IRC-bot with various functionality.
Please report bugs to @{[ SCRIPT_EMAIL ]}

EOUSAGE
    exit($exit);
}

# sub: error
# Colorifies an error-message
#
# Parameters: 
#   errmsg - the error message
#
# Returns:
#   the colour-coded error message or undef on error
sub error {
    my $errmsg = shift;
    unless (defined $errmsg) {
        carp "Missing string in Anna::Utils::error.";
        return;
    }
    return $errmsg if (!-t STDERR);
    return colour($errmsg, "91");
}

# sub: warning
# Colorifies a warning
#
# Parameters: 
#   warnmsg - the warning message
#
# Returns: 
#   the colour-coded warning or undef on error
sub warning {
    my $warnmsg = shift;
    unless (defined $warnmsg) {
        carp "Missing string in Anna::Utils::warning.";
        return;
    }
    return colour($warnmsg, '93');
}

# sub: colour
# Colorifies a string
#
# Parameters: 
#   s - the message to colour
#   c - the colour-code
# 
# Returns: 
#   the colourcoded string or undef on error
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

# sub: trim
# Trims whitespace off the start and end of a string
#
# Parameters: 
#   s - the string to trim
#
# Returns:
#   the trimmed string or undef on error
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

# sub: rtrim
# Trims whitespace off the end of a string
#
# Parameters: 
#   s - the string to be trimmed
#
# Returns:
#   the trimmed string or undef on error
sub rtrim {
    my $s = shift;
    unless (defined $s) {
        carp "Missing parameter in rtrim";
        return;
    }
    $s =~ s/\s+$//m;
    return $s;
}

# sub: ltrim
# Trims whitespace from the beginning of a string
#
# Parameters: 
#   s - the string to trim
#
# Returns:
#   trimmed string or undef on error
sub ltrim {
    my $s = shift;
    unless (defined $s) {
        carp "Missing paramter in ltrim";
        return;
    }
    $s =~ s/^\s+//m;
    return $s;
}

# sub: calc_diff
# Calculates the difference between now and a timestamp, and returns a nicely formatted output
#
# Parameters: 
#   when - epoch timestamp
#
# Returns:
#   "days d hours h minutes m seconds s" since $when
sub calc_diff {
    my $when = shift;
    $when ||= 0;
    my $diff = (time() - $when);
    my $day = int($diff / 86400); $diff -= ($day * 86400);
    my $hrs = int($diff / 3600); $diff -= ($hrs * 3600);
    my $min = int($diff / 60); $diff -= ($min * 60);
    my $sec = $diff;
    return sprintf "%dd %dh %dm %ds", $day, $hrs, $min, $sec;
}

# sub: print_time
# Formats the current time for displaying purposes (command line, in IRC, etc)
#
# Parameters: 
#   none
#
# Returns:
#   hour:min:sec
sub print_time {
    if (@_ == 1) {
        return strftime(shift, localtime);
    }
    return strftime("%H:%M:%S", localtime);
}

# sub: print_formatted_message
# Print message with standard formatting
#
# Parameters:
#   message
#
# Returns:
#   undef
sub print_formatted_message {
    my $msg = shift;
    return unless ($msg);
    printf "[%s] %s!%s %s\n", print_time(), colour('-', '94'), colour('-', '94'), $msg;
}

# sub: debug_print
# Print message on debug level. Use this for information only needed during 
# debugging and development
#
# Parameters: 
#   message
#
# Returns:
#   undef
sub debug_print {
    return unless Anna::Config->new->get('debug');
    my $msg = shift;
    return unless ($msg);
    print_formatted_message("[DEBUG] ".$msg) foreach(split("\n", $msg));
}

# sub: warn_print
# Print message on warning level. Use this for general warnings about operations
#
# Parameters: 
#   message
#
# Returns:
#   undef
sub warn_print {
    my $msg = shift;
    return unless ($msg);
    print_formatted_message("[WARNING] ".colour($_, '93')) foreach(split("\n", $msg));
}

# sub: error_print
# Print message on error level. Use this for non-critical errors.
#
# Parameters: 
#   message
#
# Returns:
#   undef
sub error_print {
    my $msg = shift;
    return unless ($msg);
    print_formatted_message("[ERROR] ".colour($_, '91')) foreach(split("\n", $msg));
}

# sub: verbose_print
# Print message only if verbose option was enabled. Use this for information that would normally be irrelevant 
#
# Parameters: 
#   message
#
# Returns:
#   undef
sub verbose_print {
    return unless Anna::Config->new->get('verbose');
    my $msg = shift;
    return unless ($msg);
    print_formatted_message($_) foreach(split("\n", $msg));
}

1;

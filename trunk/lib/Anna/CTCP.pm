package Anna::CTCP;
use strict;
use warnings;

our @EXPORT = qw(on_ctcp_ping on_ctcpreply_ping on_ctcp_version on_ctcpreply_version on_ctcp_time on_ctcp_finger);
our @EXPORT_OK = qw();
use Exporter;
our  @ISA = qw(Exporter);

use Carp;
use Anna::Output qw(irclog);
use Anna::Config;
use Anna::Utils;
use POE;

# sub: on_ctcp_ping
# Event callback called by POE when a CTCP PING is recieved.
#
# Responds to the sender with a PING-reply
#
# Do not call this manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub on_ctcp_ping {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick, $host) = split(/!/, $from);

	$h->{seen_traffic} = 1;

	# Protocol says to use PONG in ctcpreply, but irssi & xchat for some 
	# reason only reacts to PING... mrmblgrbml
	$msg = "PING ".$msg;
	$h->{irc}->yield(ctcpreply => $nick => $msg);

	irclog('status' => sprintf "-!- CTCP PING request from %s recieved", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP PING request from %s recieved\n",
		print_time(), $nick if Anna::Config->new->get('verbose');
}

# sub: on_ctcpreply_ping
# Event callback called by POE when a CTCP PING reply is recieved.
#
# If a timestampt is supplied, we assume that we sent it along with a CTCP PING
# and calculate the difference between current time and the timestamp
#
# Do not call this manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub on_ctcpreply_ping {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick, $host) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	unless ($msg) {
		irclog('status' => sprintf "-!- Recieved invalid CTCP PING REPLY from %s", $nick);
		printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Recieved invalid CTCP PING REPLY from %s\n",
			print_time(), $nick unless Anna::Config->new->get('silent');
		return 1;
	}

	my $diff = time - $msg;
	irclog('status' => sprintf "-!- CTCP PING REPLY from %s: %s sec", $nick, $diff);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP PING REPLY from %s: %s sec\n",
		print_time(), $nick, $diff unless Anna::Config->new->get('silent');
}

# sub: on_ctcp_version
# Event callback called by POE when a CTCP VERSION is recieved.
#
# Responds to the sender with version information
# <Anna::Utils::SCRIPT_NAME>, <Anna::Utils::SCRIPT_VERSION> & 
# <Anna::Utils::SCRIPT_SYSTEM>
#
# Do not call this manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub on_ctcp_version {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick, $host) = split(/!/, $from);
	
	$h->{seen_traffic} = 1;
	
	$h->{irc}->yield(ctcpreply => $nick => Anna::Utils::SCRIPT_NAME." : ".Anna::Utils::SCRIPT_VERSION." : ".Anna::Utils::SCRIPT_SYSTEM);
	irclog('status' => sprintf "-!- CTCP VERSION request from %s recieved", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION request from %s recieved\n",
		print_time(), $nick if Anna::Config->new->get('verbose');
}

# sub: on_ctcpreply_version
# Event callback called by POE when a CTCP VERSION reply is recieved.
#
# Prints the version information and hums along.
#
# Do not call this manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub on_ctcpreply_version {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	unless ($msg) {
		irclog('status' => sprintf "-!- Recieved invalid CTCP VERSION REPLY from %s", $nick);
		printf "[%s] %s!%s Recieved invalid CTCP VERSION REPLY from %s\n", 
			print_time(), colour('-', '94'), colour('-', '94'), 
			$nick unless Anna::Config->new->get('silent');
		return 1;
	}

	irclog('status' => sprintf "-!- CTCP VERSION REPLY from %s: %s", $nick, $msg);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION REPLY from %s: %s\n",
		print_time(), $nick, $msg unless Anna::Config->new->get('silent');
}

# sub: on_ctcp_time
# Event callback called by POE when a CTCP TIME is recieved.
#
# Sends a CTCP response with the current system time. RFC permits arbitrary 
# formats so we use scalar localtime time
#
# Do not call this manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub on_ctcp_time {
	my ($from, $h) = @_[ARG0, HEAP];
	my ($nick) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	$h->{irc}->yield(ctcpreply => $nick => "TIME ".scalar localtime time);

	irclog('status' => sprintf "-!- CTCP TIME recieved from %s", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP TIME recieved from %s\n",
		print_time(), $nick if Anna::Config->new->get('verbose');
}

# sub: on_ctcp_finger
# Technically supposed to be a finger-implementation but that's boring, so 
# respond with a rude remark instead.
#
# Event callback called by POE when a CTCP FINGER is recieved.
#
# Do not call this manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub on_ctcp_finger {
	my ($from, $h) = @_[ARG0, HEAP];
	my ($nick) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	my @replies = ("Dont finger me there...",
			"Don't your fscking dare!",
			"Screw off!",
			"Yes, please",
			"Please don't kill me... she did");
	$h->{irc}->yield(ctcpreply => $nick => "FINGER ".$replies[rand scalar @replies]);

	irclog('status' => sprintf "-!- CTCP FINGER recieved from %s", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP FINGER recieved from %s\n",
		print_time(), $nick if Anna::Config->new->get('verbose');
}

1;

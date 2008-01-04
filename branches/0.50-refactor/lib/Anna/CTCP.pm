package Anna::CTCP;
use strict;
use warnings;

our @EXPORT = qw(on_ctcp_ping on_ctcpreply_ping on_ctcp_version on_ctcpreply_version on_ctcp_time on_ctcp_finger);
our @EXPORT_OK = qw();
use Exporter;
our  @ISA = qw(Exporter);

use Carp;
use Anna::Output qw(irclog);
use Anna::Utils;
use POE;

## on_ctcp_ping
# This gets called whenever you get /ctcp ping'd. Should return a nice
# response to the pinger
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
		print_time(), $nick if $h->{config}->get('verbose');
}

## on_ctcpreply_ping
# Subroutine for handling ping replies. Just gives the lag results for
# outgoing pings.
# FIXME: Use microseconds instead
sub on_ctcpreply_ping {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick, $host) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	unless ($msg) {
		irclog('status' => sprintf "-!- Recieved invalid CTCP PING REPLY from %s", $nick);
		printf "[%s] ".colour("-", "94")."!".colour("-", "94")." Recieved invalid CTCP PING REPLY from %s\n",
			print_time(), $nick unless $h->{config}->get('silent');
		return;
	}

	my $diff = time - $msg;
	irclog('status' => sprintf "-!- CTCP PING REPLY from %s: %s sec", $nick, $diff);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP PING REPLY from %s: %s sec\n",
		print_time(), $nick, $diff unless $h->{config}->get('silent');
}

## on_ctcp_version
# This subroutine reacts to the /ctcp version, returning the current 
# version of this script
sub on_ctcp_version {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick, $host) = split(/!/, $from);
	
	$h->{seen_traffic} = 1;
	
	$h->{irc}->yield(ctcpreply => $nick => Anna::Utils::SCRIPT_NAME." : ".Anna::Utils::SCRIPT_VERSION." : ".Anna::Utils::SCRIPT_SYSTEM);
	irclog('status' => sprintf "-!- CTCP VERSION request from %s recieved", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION request from %s recieved\n",
		print_time(), $nick if $h->{config}->get('verbose');
}

## on_ctcpreply_version
# This subroutine prints out version replies to stdout
sub on_ctcpreply_version {
	my ($from, $to, $msg, $h) = @_[ARG0, ARG1, ARG2, HEAP];
	my ($nick) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	unless ($msg) {
		irclog('status' => sprintf "-!- Recieved invalid CTCP VERSION REPLY from %s", $nick);
		printf "[%s] %s!%s Recieved invalid CTCP VERSION REPLY from %s\n", 
			print_time(), colour('-', '94'), colour('-', '94'), 
			$nick unless $h->{config}->get('silent');
		return;
	}

	irclog('status' => sprintf "-!- CTCP VERSION REPLY from %s: %s", $nick, $msg);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP VERSION REPLY from %s: %s\n",
		print_time(), $nick, $msg unless $h->{config}->get('silent');
}

## on_ctcp_time
# This returns the local system time, to whoever sent you a CTCP TIME
sub on_ctcp_time {
	my ($from, $h) = @_[ARG0, HEAP];
	my ($nick) = split(/!/, $from);

	$h->{seen_traffic} = 1;
	
	$h->{irc}->yield(ctcpreply => $nick => "TIME ".scalar localtime time);

	irclog('status' => sprintf "-!- CTCP TIME recieved from %s", $nick);
	printf "[%s] ".colour("-", "94")."!".colour("-", "94")." CTCP TIME recieved from %s\n",
		print_time(), $nick if $h->{config}->get('verbose');
}

## on_ctcp_finger
# I can't remember what this i supposed to return, so give a rude 
# response
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
		print_time(), $nick if $h->{config}->get('verbose');
}

1;

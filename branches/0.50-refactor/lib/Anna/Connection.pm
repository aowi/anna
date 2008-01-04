package Anna::Connection;

use strict;
use warnings;

our @EXPORT = qw(do_autoping do_connect do_reconnect);
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use POE;
use Carp;
use Data::Dumper;
use Anna::Utils;
use Anna::Config;

my $std_croak = "Do not call do_*-routines manually. These are for internal use only!";

## do_autoping
# checks if we've seen any traffic for the pas 300 secs, generates some in case
# we haven't.
sub do_autoping() {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	croak $std_croak unless (defined $kernel && defined $heap);
	$heap->{irc}->yield(userhost => $heap->{irc}->nick_name) unless $heap->{seen_traffic};
	$heap->{seen_traffic} = 0;
	$kernel->delay(autoping => 300);
	return 1;
}

## do_connect
# Tell the irc-object to initiate the connection 
sub do_connect() {
	croak $std_croak unless defined $_[HEAP];
	my $c = new Anna::Config;
#	irclog('status', sprintf "-!- Connecting to %s", $c->get('server'));
	printf "[%s] %s!%s Connecting to %s\n", print_time(), colour('-', '94'),
		colour('-', '94'), $c->get('server') if $c->get('verbose');
	$_[HEAP]->{irc}->yield(connect => {});
	return 1;
}

## do_reconnect
# POE calls this when the connection died and needs to be reestablished.
# Wait for 60 secs, then attempt a connect.
sub do_reconnect() {
	croak $std_croak unless defined $_[KERNEL];
	my $kernel = $_[KERNEL];
	# Disable autopings when disconnected
	$kernel->delay(autoping => undef);
#	irclog('status', 'Attempting reconnect in 60 seconds...');
	# TODO: make timeout configurable
	printf "[%s] Attempting reconnect in 60 seconds...\n", print_time() 
		unless Anna::Config->new->get('silent');
	$kernel->delay(connect => 60);
	return 1;
}

1;

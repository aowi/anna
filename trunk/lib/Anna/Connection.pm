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

# var: $std_croak
# stardard error-message used when do-routines are called manually
my $std_croak = "Do not call do_*-routines manually. These are for internal use only!";

# sub: do_autoping
# Called by the POE-kernel when there has been no traffic for 300 seconds.
#
# Sends a message to the IRC-server to verify that we are, in fact, still 
# connected.
#
# Do not call this function manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub do_autoping() {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	croak $std_croak unless (defined $kernel && defined $heap);
	$heap->{irc}->yield(userhost => $heap->{irc}->nick_name) unless $heap->{seen_traffic};
	$heap->{seen_traffic} = 0;
	$kernel->delay(autoping => 300);
	return 1;
}

# sub: do_connect
# Initiates a connection to the IRC-server through the previously defined 
# IRC-object
#
# Do not call this function manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
sub do_connect() {
	croak $std_croak unless defined $_[HEAP];
	my $c = new Anna::Config;
#	irclog('status', sprintf "-!- Connecting to %s", $c->get('server'));
	printf "[%s] %s!%s Connecting to %s\n", print_time(), colour('-', '94'),
		colour('-', '94'), $c->get('server') if $c->get('verbose');
	$_[HEAP]->{irc}->yield(connect => {});
	return 1;
}

# sub: do_reconnect
# Called when a connection is dropped and needs to be re-established. 
#
# Sleeps for 60 seconds before calling $kernel->connect.
#
# Do not call this function manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   1
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

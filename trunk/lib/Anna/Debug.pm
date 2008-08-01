package Anna::Debug;
#use strict;
use warnings;

# Import Anna::Utils
use Anna::Utils;
use POE;

our @EXPORT = qw(state);
our @EXPORT_OK = qw(_default bitch);
use Exporter;
our @ISA = qw(Exporter);
use Anna::Config;


# sub: dummy
# Do I really need to do this?
sub dummy {}

# sub: _default
# A catch-all routine for otherwise unhandled events that POE might see.
#
# Tries to be smart if it's a numeric irc-event (irc_###). If not, it just dumps
# all available information.
#
# Do not call this function manually
#
# Params:
#   none (POE event call)
#
# Returns:
#   0
sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	
	my $conf = new Anna::Config;
	
	# If debug is turned on, we already know that Data::Dumper is available
	if (Anna::Config->new->get('debug') && !defined(&Dumper)) {
		require Data::Dumper;
		Data::Dumper->import(qw(Dumper));
	}

	# _default called before _start had time to populate $heap
	# we can't know whether user wants debug output.
	return 0 unless (ref $conf);

	$_[HEAP]->{seen_traffic} = 1 if ($event =~ /irc_.+/);

	return 0 unless $conf->get('debug');

	# Handle numeric events. These seems to follow a certain syntax.
	if ($event =~ /irc_(\d\d\d)/) {
		#irclog('status' => sprintf "(%s) %s", $1, "@{$args->[2]}");
		printf "[%s] ".colour('-', 94)."!".colour('-', 94)." (%s) %s\n",
		print_time(), $1, "@{$args->[2]}" if $conf->get('verbose');
		return 0;
	}
	print "\n\nAn event $event which Anna^ currently doesn't handle was recieved:\n";
	print Dumper($args);
	print "\nIf you don't want to see this message, please disable debugging\n\n";
	return 0;
}
1;

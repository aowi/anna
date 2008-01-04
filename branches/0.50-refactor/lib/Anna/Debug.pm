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



## _default
# Params: Whatever POE sends our way
# This is a function called by POE-events, that have no handlers. It should 
# only be used when debugging is enabled. Prints debug information tp stdout 
# and returns true
sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	
	my $conf = $_[HEAP]->{config};
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

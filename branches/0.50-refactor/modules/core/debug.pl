use strict;
use warnings;

use Anna::Module;
use Data::Dumper;
use POE;

my $m = Anna::Module->new('debug');
$m->bindcmd('dumpvars', 'dumpvars');
$m->bindcmd('kernel', 'kernel_stuff');
sub dumpvars {
	print Dumper(@_);
}

sub kernel_stuff {
	my $session = $poe_kernel->alias_resolve('irc');
	$poe_kernel->post('irc' => privmsg => $_[CHAN] => "lolinternet");

}

1;

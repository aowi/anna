use strict;
use warnings;

use Anna::Module;
use Data::Dumper;

my $m = Anna::Module->new('debug');
$m->registercmd('dumpvars', 'dumpvars');

sub dumpvars {
	print Dumper(@_);
}

1;

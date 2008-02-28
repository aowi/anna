use strict;
use warnings;

use Anna::Module;
use Data::Dumper;

my $m = Anna::Module->new('debug');
$m->bindcmd('dumpvars', 'dumpvars');

sub dumpvars {
	print Dumper(@_);
}

1;

# vim: et:ts=4:sw=4
use strict;
use warnings;

use Anna::Module;
use Data::Dumper;
use POE;

my $m = Anna::Module->new('debug');
$m->bindcmd('dumpvars', 'dumpvars');
$m->bindcmd('kernel', 'kernel_stuff');
$m->bindcmd('debug_modules', 'modules');
sub dumpvars {
    print Dumper(@_);
}

sub kernel_stuff {
    my $session = $poe_kernel->alias_resolve('irc');
    $poe_kernel->post('irc' => privmsg => $_[CHAN] => "lolinternet");
}

sub modules {
    print "Module info:\n";
    print Dumper($Anna::Module::modules);
    print "Module-bound commands:\n";
    print Dumper($Anna::Module::module_commands);
    print "Module-bound messages:\n";
    print Dumper($Anna::Module::module_messages);
    print "Module-bound regular expressions:\n";
    print Dumper($Anna::Module::module_regexps);
}

1;

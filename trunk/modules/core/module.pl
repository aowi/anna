# vim: et:ts=4:sw=4
use strict;
use warnings;

use Anna::Module;
use Data::Dumper;
use Anna::Auth;
use POE;

my $m = Anna::Module->new('module');
$m->bindcmd('load', 'module_load');
$m->bindcmd('unload', 'module_unload');

sub module_load {
    if (Anna::Auth->new->host2user($_[HOST])) {
        if (!Anna::Module::load($_[ARG])) {
            $_[IRC]->yield(privmsg => $_[CHAN] => $_[NICK] . ": Failed to load " . $_[ARG]);
        }
        return;
    }
    $_[IRC]->yield(privmsg => $_[CHAN] => $_[NICK] . ": You don't have permission to load modules!");
}

sub module_unload {
    if (Anna::Auth->new->host2user($_[HOST])) {
        if (Anna::Module::unload($_[ARG])) {
            $_[IRC]->yield(privmsg => $_[CHAN] => $_[NICK] . ": Unloaded module " . $_[ARG]);
        } else {
            $_[IRC]->yield(privmsg => $_[CHAN] => $_[NICK] . ": Failed to unload " . $_[ARG]);
        }
        return;
    }
    $_[IRC]->yield(privmsg => $_[CHAN] => $_[NICK] . ": You don't have permission to unload modules!");
}

1;

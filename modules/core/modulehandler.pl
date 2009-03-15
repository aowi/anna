# vim: et:ts=4:sw=4
use strict;
use warnings;

use Anna::Module;
use Anna::ModuleHandler;
use Data::Dumper;
use Anna::Auth;
use POE;

my $m = Anna::Module->new('modulehandler')->protect;
$m->bindcmd('load', 'module_load');
$m->bindcmd('unload', 'module_unload');
$m->bindcmd('listmodules', 'module_list');

sub module_load {
    unless (Anna::Auth->new->host2user($_[HOST])) {
        $m->irc->reply_hilight("You don't have permission to load modules!");
        return;
    }
    if (!Anna::ModuleHandler::load($_[ARG])) {
        $m->irc->reply_hilight("Failed to load " . $_[ARG]);
    }
}

sub module_unload {
    unless (Anna::Auth->new->host2user($_[HOST])) {
        $m->irc->reply_hilight("You don't have permission to unload modules!");
        return;
    }
    unless (Anna::ModuleHandler->new->module_loaded($_[ARG])) {
        $m->irc->reply_hilight(sprintf "Module %s isn't loaded", $_[ARG]);
        return;
    }
    if ($m->is_protected($_[ARG])) {
        $m->irc->reply_hilight(sprintf "Module %s is protected and cannot be unloaded", $_[ARG]);
        return;
    }
    if (Anna::ModuleHandler::unload($_[ARG])) {
        $m->irc->reply_hilight("Unloaded module " . $_[ARG]);
    } else {
        $m->irc->reply_hilight("Failed to unload " . $_[ARG]);
    }
}

sub module_list {
    my @mods;
    while (my ($k, $v) = each %$Anna::ModuleHandler::modules) {
        push @mods, $k;
    }
    $m->irc->reply(sprintf "Loaded modules: %s", join(", ", @mods));
}

1;

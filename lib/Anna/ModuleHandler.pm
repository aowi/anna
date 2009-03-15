# vim: et:ts=4:sw=4
package Anna::ModuleHandler;
use strict;
use warnings;

use Exporter;
our @EXPORT_OK = qw();
our @EXPORT = qw();
our @ISA = qw(Exporter);

use Anna::Utils;
use Carp qw(carp cluck croak confess);
use Symbol qw(delete_package);
use 5.010;

our $modules         = {};
our $module_commands = {};
our $module_messages = {};
our $module_regexps  = {};
our $protected_modules = [];

sub new {
    return bless {}, shift;
}

sub addcmd {
    my ($self, $cmd, $callback) = @_;
    $module_commands->{$cmd} = $callback;
    return $self;
}

sub addregexp {}

sub addevent {}

sub addmsg {
    my ($self, $msg, $callback) = @_;
    $module_messages->{$msg} = $callback;
    return $self;
}

sub protect {
    my ($self, $name) = @_;
    unless ($name ~~ @$protected_modules) {
        push @$protected_modules, $name;
        return 1;
    }
    return 0;
} 

sub is_protected {
    my ($self, $name) = @_;
    return $name ~~ @$protected_modules;
}

sub module_loaded {
    my $self = shift;
    return undef unless (@_ == 1);
    my $n = shift;
    if (ref $n) {
        # Called as method
        return 1;
    } else {
        return 1 if (exists $modules->{$n});
    }
    return 0;
}

sub add {
    my ($self, $name, $r) = @_;
    $modules->{$name} = $r;
    return $self;
}

sub commands {
    return $module_commands;
}

sub messages {
    return $module_messages;
}

sub regexps {
    return $module_regexps;
}

#sub events {
#    return $module_events;
#}

sub empty_db {
    if (@_ && ref $_[0]) {
        # Called as method, abort
        carp "Don't call empty_db as a method!!";
        return 0;
    }
    my $dbh = new Anna::DB;
    unless ($dbh) {
        carp "Failed to obtain DB handle: $DBI::errstr";
        return 0;
    }
    unless (defined $dbh->do("DELETE FROM modules")) {
        carp "Failed to empty module database: $DBI::errstr";
        return 0;
    }
    return 1;
}

# sub: execute
# Scans the command-table for commands matching the provided message. Executes
# the corresponding module subroutine if a command is found.
#
# Parameters:
#   msg - the full message, that were recieved
#   heap - ref to POE heap
#   channel - the target the message is to be returned to (in case of channels a 
#   channel-name, in case of privmsgs the user who sent the message)
#   nick - the nickname of the sender of the message
#   host - senders hostname
#   type - type of message. 'public' for messages to channels, 'msg' for private messages
#
# Returns:
#   1
sub execute {
    return 1 unless (@_ == 6);
    my ($msg, $heap, $channel, $nick, $host, $type) = @_;
    my $c = new Anna::Config;
    my ($trigger, $botnick) = ($c->get('trigger'), $c->get('nick'));
    if ($type eq 'msg') {
        debug_print(sprintf "Recieved a private message from [%s]: %s", $nick, $msg);
        # MSG
        # if the message matched something hooked with bindmsg, return. 
        # Otherwise, assume it was a standard command
        # XXX: REWRITE THIS SHIT! What about bound regexps? other stuff?
        # I need something more general.
        debug_print "Checking whether we want the message";
        if (do_msg($msg, $heap, $channel, $nick, $host, $type)) {
            return 1;
        } else {
            debug_print "We didn't. Assuming it is a command";
            if ($msg =~ /^(\Q$trigger\E|\Q$botnick\E[ :,-]+)/) {
                $msg =~ s/^(\Q$trigger\E|\Q$botnick\E[ :,-]+\s*)//;
            }
            do_cmd($msg, $heap, $channel, $nick, $host, $type);
            return 1;
        }
        
    }

    debug_print(sprintf "Recieved a public message from [%s]: %s", $nick, $msg);
    
    # Command
    if ($msg =~ /^(\Q$trigger\E|\Q$botnick\E[ :,-]+)/) {
        debug_print(sprintf "Message %s resolved as command", $msg);
        my $cmd = $msg;
        $cmd =~ s/^(\Q$trigger\E|\Q$botnick\E[ :,-]+\s*)//;
        do_cmd($cmd, $heap, $channel, $nick, $host, $type);
        return 1;
    }
    debug_print "Not a command...";
    
    # Regexp
    debug_print "Checking whether the message matches any bound regexps...";
    my $dbh = new Anna::DB or return 1;
    my $sth = $dbh->prepare(qq{
        SELECT * FROM modules WHERE type = 'regexp'
    });
    $sth->execute;
    while (my $res = $sth->fetchrow_hashref)  {
        my ($rx, $name, $sub) = ($res->{'value'}, $res->{'name'}, $res->{'sub'});
        if ($msg =~ m/$rx/) {
            debug_print(sprintf "Matched regexp %s which was resolved to Anna::Module::Modules::%s::%s",
                $rx, $name, $sub);
            $modules->{$name}->{irc}->stash({
                target  => $channel,
                nick    => $nick,
                host    => $host,
                type    => $type
            });
 
            my $s = \&{ "Anna::Module::Modules::".$name."::".$sub};
            eval '$s->($heap->{irc}, $channel, $nick, $host, $type, $msg)';
            cluck $@ if $@;
            $modules->{$name}->{irc}->clearstash();
            return 1;
        }
    }
    debug_print "It didn't... discarding.";
    return 1;
}

# sub: loaddir
# Scan a directory for anna-modules (or rather, .pl-files) and load them.
#
# Params:
#   dir - the (full) path to the directory to search
#
# Returns:
#   nothing
sub loaddir {
    my $dir = shift;
    unless (-d $dir) {
        debug_print(sprintf("%s does not exist or is not a directory - skipped!", $dir));
        return;
    }
    debug_print(sprintf "Loading modules from %s", $dir);
    opendir(DIR, $dir) or confess $!;
    while (defined(my $file = readdir(DIR))) {
        if ($file =~ m/[.]pl$/) {
            my $m = $file;
            $m =~ s/[.]pl$//;
            loadfullpath($dir."/".$file, $m);
        }
    }
    closedir(DIR) or croak $!;
}

# sub: do_cmd
# Handles command-checking and execution, if a command-trigger is found.
#
# Params:
#   msg - the full message, that were recieved
#   heap - ref to POE heap
#   channel - the target the message is to be returned to (in case of channels a 
#   channel-name, in case of privmsgs the user who sent the message)
#   nick - the nickname of the sender of the message
#   host - senders hostname
#   type - type of message. 'public' for messages to channels, 'msg' for private messages
#
# Returns:  
#   1
sub do_cmd {
    debug_print(sprintf "do_cmd called with parameters %s", join(', ',@_));
    my ($cmd, $heap, $channel, $nick, $host, $type) = @_;

    my ($c, $m) = split(' ', $cmd, 2);
    if (exists $module_commands->{$c}) {
        debug_print(sprintf "Command %s resolved to Anna::Module::Modules::%s", $c, join('::', @{$module_commands->{$c}}));
        debug_print("Stashing info");
        $modules->{$module_commands->{$c}->[0]}->{irc}->stash({
            target  => $channel,
            nick    => $nick,
            host    => $host,
            type    => $type
        });
        debug_print("Calling module");
        my $s = \&{ "Anna::Module::Modules::".$module_commands->{$c}->[0]."::".$module_commands->{$c}->[1] };
        eval '$s->($heap->{irc}, $channel, $nick, $host, $type, $m)';
        cluck $@ if $@;
        debug_print("Clearing stash");
        $modules->{$module_commands->{$c}->[0]}->{irc}->clearstash;
    }
    return 1;
}

# sub: do_msg
# Handles privmsg-checking and execution, if a msg-trigger is found.
#
# Params:
#   msg - the full message, that were recieved
#   heap - ref to POE heap
#   channel - the target the message is to be returned to (in case of channels a 
#   channel-name, in case of privmsgs the user who sent the message)
#   nick - the nickname of the sender of the message
#   host - senders hostname
#   type - type of message. 'public' for messages to channels, 'msg' for private messages
#
# Returns:  
#   1
sub do_msg {
    debug_print(sprintf "do_msg called with parameters %s", join(', ',@_));
    my ($text, $heap, $channel, $nick, $host, $type) = @_;

    my ($msg, $args) = split(' ', $text, 2);
    if (exists $module_messages->{$msg}) {
        debug_print(sprintf "Message %s resolved to Anna::Module::Modules::%s", $msg, join('::', @{$module_messages->{$msg}}));
        debug_print("Stashing info");
        $modules->{$module_messages->{$msg}->[0]}->{irc}->stash({
            target  => $channel,
            nick    => $nick,
            host    => $host,
            type    => $type
        });
        debug_print("Calling module");
        my $s = \&{ "Anna::Module::Modules::".$module_messages->{$msg}->[0]."::".$module_messages->{$msg}->[1]};
        eval '$s->($heap->{irc}, $channel, $nick, $host, $type, $args)';
        cluck $@ if $@;
        debug_print("Clearing stash");
        $modules->{$module_messages->{$msg}->[0]}->{irc}->clearstash;
        return 1;
    }

    return 0;
}

# sub: load
# Takes a module-name or a filename and scans for a module with that name in Anna's 
# module-directories. If a module is found, call loadfullpath on it
#
# Parameters:
#   m - module name or filename
# 
# Returns:
#   1 on successful loading, 0 on failure
sub load {
    unless (@_ >= 1) {
        carp "load takes one parameter";
        return 0;
    }
    my $m = shift;
 
    $m =~ s/[.]pl$//;
    debug_print(sprintf "Trying to load %s", $m);
    my @path = (
        Anna::Utils->CONFIGDIR."/modules/", 
        Anna::Utils->CONFIGDIR."/modules/core/", 
        Anna::Utils->CONFIGDIR."/modules/auto/",
        "/usr/share/anna/modules/", 
        "/usr/share/anna/modules/core/", 
        "/usr/share/anna/modules/auto/"
    );
    
    my ($found, $ret) = 0;
    foreach my $p (@path) {
        if (-f $p.$m.".pl") {
            debug_print(sprintf "%s resolved to %s", $m, $p.$m.".pl");
            $ret = loadfullpath($p.$m.".pl", $m); 
            $found = 1;
            last;
        }
    }
    if (!$found) {
        warn_print(sprintf("Module %s not found", $m));
        return 0;
    }
    return $ret;
}

sub loadfullpath {
    my ($path, $m) = @_;
    
    if (module_loaded($m)) {
        carp "Module $m already loaded";
        return 0;
    }

    verbose_print(sprintf("Loading module %s", $m));
    
    debug_print("Running eval...");
    eval qq{
        package Anna::Module::Modules::$m; 
        require qq|$path|;
        &init if (defined &init);
    };
    if ($@) {
        carp "Failed to load $m: $@";
        unload($m); # Cleanup cruft
        return 0;
    }
    debug_print("Module loaded");
    package Anna::Module;
    return 1;
}

# sub: unload
# Unloads a module. Cleans database and scrubs package namespace (with delete_package from Symbol)
#
# Parameters:
#   m - name of module
#
# Returns:
#   1 on success, 0 on failure
sub unload {
    unless (@_ >= 1) {
        carp "unload takes one parameter";
        return 0;
    }
    my $m = shift;
    if ($m ~~ @$protected_modules) {
        warn_print(sprintf "Tried to unload module %s which is protected", $m);
        return 0;
    }
    verbose_print(sprintf("Unloading module %s", $m));

    debug_print "Deleting symbols";
    delete_package('Anna::Module::Modules::'.$m);

    debug_print "Deleting module info";
    delete $modules->{$m};

    debug_print "Cleaning database";
    my $dbh = new Anna::DB;
    unless ($dbh) {
        carp "Unable to obtain DB handle: $DBI::errstr";
        return 0;
    }
    unless (defined $dbh->do("DELETE FROM modules WHERE name = ?", undef, ($m))) {
        carp "Failed to unload module $m: $DBI::errstr";
        return 0;
    }

    debug_print "Removing message handlers";
    foreach my $key (keys %$module_messages) {
        delete $module_messages->{$key}
            if ($module_messages->{$key}->[0] eq $m);
    }

    debug_print "Removing command handlers";
    foreach my $key (keys %$module_commands) {
        delete $module_commands->{$key}
            if ($module_commands->{$key}->[0] eq $m);
    }

    debug_print "Done removing module";
    return 1;
}

1;

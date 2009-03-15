# vim: et:ts=4:sw=4
package Anna::Module;
use strict;
use warnings;

use Exporter;
our @EXPORT_OK = qw();
our @EXPORT = qw(IRC CHAN NICK HOST TYPE MOD ARG);
our @ISA = qw(Exporter);

use Anna::DB;
use Anna::Config;
use Anna::Utils;
use Anna::ModuleGuts::IRC;
use Anna::ModuleHandler;
use Data::Dumper;

use Carp qw(carp cluck croak confess);
use Symbol qw(delete_package);
use 5.010;

our $modulehandler = new Anna::ModuleHandler;

# These subs are exported per default and used as constant expressions by 
# modules, to avoid having to keep track of argument order, and to allow us to
# reorder or add more args later, without breaking existing modules.
# Idea stolen from POE, btw :)
sub IRC  () {  0 } # irc-object
sub CHAN () {  1 } # channel the message is from
sub NICK () {  2 } # nick of the sender
sub HOST () {  3 } # host of the sender
sub TYPE () {  4 } # type of message/event (privmsg, public, join, part, ...)
sub ARG  () {  5 } # any arguments exactly as they were typed (no processing is done)

sub new {
    my ($class, $name) = @_;
    unless (defined $name && $name) {
        carp "new Anna::Module requested, but no name was supplied";
        return 0;
    }
    if ($modulehandler->module_loaded($name)) {
        carp "Module $name already loaded";
        return 0;
    }
    
    my $irc = new Anna::ModuleGuts::IRC;
    my $db = new Anna::DB $name;
    my $module = {
        name    => $name,
        db      => $db,
        irc     => $irc
    };
    my $r = bless $module, $class;
    $modulehandler->add($name, $r);
    return $r;
}

# sub: bindcmd
# Used as a method to bind a command to a subroutine
#
# Parameters:
#   cmd - the cmd to listen for
#   sub - the sub to call when cmd is found
#
# Returns:
#   The object (caller)
sub bindcmd {
    unless (@_ == 3) {
        carp "bindcmd takes two parameters: command and sub";
        return $_[0];
    }
    my $pkg = shift;
    my ($cmd, $sub) = @_;

    if (exists $modulehandler->commands->{$cmd}) {
        warn_print(
            sprintf 
            "Module %s will overwrite command %s which is already bound by %s",
            $pkg->{'name'}, $cmd, $modulehandler->commands->{$cmd}->[0]
        );
    }
    debug_print(
        sprintf "Binding command %s to Anna::Module::%s::%s",
            $cmd, $pkg->{'name'}, $sub
    );
    $modulehandler->addcmd($cmd, [ $pkg->{'name'}, $sub ]);

    return $pkg;
}

# sub: bindmsg
# Used as a method to bind a privmsg to a subroutine
# Anna^ will not trigger this on messages sent to public channels. Only 
# messages that are sent directly to Anna^
#
# Parameters:
#   msg - the msg to listen for
#   sub - the sub to call when cmd is found
#
# Returns:
#   The object (caller)
sub bindmsg {
    unless (@_ == 3) {
        carp "bindmsg takes two parameters: command and sub";
        return $_[0];
    }
    my $pkg = shift;
    my ($msg, $sub) = @_;

    if (exists $modulehandler->messages->{$msg}) {
        warn_print(
            sprintf
            "Module %s will overwrite message listener %s which is already bound by %s",
            $pkg->{'name'}, $msg, $modulehandler->messages->{$msg}->[0]
        );
    }

    debug_print(
        sprintf "Binding privmsg %s to Anna::Module::%s::%s",
            $msg, $pkg->{'name'}, $sub
    );
    $modulehandler->addmsg($msg, [ $pkg->{'name'}, $sub ]);

    return $pkg;
}

# sub: bindregxp
#
# Binds a regular expression to a subroutine. When the regular expression
# matches a message written in channel, the sub will be triggered.
#
# Params:
#   regexp  - the regular expression (as a scalar/string, without //)
#   sub     - the subroutine that will be executed when the regexp is found
#
# Returns:
#   the Module-object
sub bindregexp {
    my ($pkg, $rx, $sub) = @_;
    eval { "" =~ /$rx/ };
    if ($@) {
        carp "Invalid pattern $rx ignored: $@";
        return $pkg;
    }

    my $dbh = new Anna::DB or return $pkg;
    my $rv = $dbh->do(qq{
        INSERT INTO modules (name, type, value, sub)
        VALUES (?, 'regexp', ?, ?)},
        undef, ($pkg->{'name'}, $rx, $sub)
    );
    unless (defined $rv) {
        carp "Failed to add regexp $rx to DB: $DBI::errstr";
    }
    return $pkg;    
}

# sub: bindevent
#
# Binds a given event to a subroutine. When the event is triggered, the 
# subroutine is executed with the relevant event information.
#
# Params:
#   event   - event to listen for (see POE::IRC::Component docs
#   sub     - subroutine that will be executed when the event is triggered
sub bindevent {}

sub irc {
    my $self = shift;
    return $self->{irc};
}

sub db {
    my $self = shift;
    return $self->{db};
}

sub protect {
    my $self = shift;
    print Dumper($self);
    $modulehandler->protect($self->{name})
        unless ($modulehandler->is_protected($self->{name}));
    return $self;
}

sub is_protected {
    my ($self, $m) = @_;
    return $modulehandler->is_protected($m);
}
1;

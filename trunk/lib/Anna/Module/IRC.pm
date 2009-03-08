# vim: et:ts=4:sw=4
package Anna::Module::IRC;
use strict;
use warnings;

use Exporter;
our @EXPORT_OK = qw();
our @EXPORT = qw();
our @ISA = qw(Exporter);

sub new {
    return bless {}, shift;
}

sub sendmsg {}
sub sendaction {}

sub reply {
    my $self = shift;
    $self->{stash}->{irc}->yield(privmsg => $self->{stash}->{target} => shift);
}

sub reply_hilight {
    my $self = shift;
    $self->{stash}->{irc}->yield(privmsg => $self->{stash}->{target} => $self->{stash}->{nick} . ": ", shift);
}

sub stash {
    my $self = shift;
    $self->{stash} = shift;
}

sub clearstash {
    my $self = shift;
    delete $self->{stash};
}

1;

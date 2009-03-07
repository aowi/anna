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
sub reply {}
sub reply_hilight {}

sub stash {
    my $self = shift;
    my $params = shift;
    while (my ($k, $v) = each %$params) {
        $self->{stash}->{$k} = $v;
    }
}

sub clearstash {
    my $self = shift;
    delete $self->{stash};
}

1;

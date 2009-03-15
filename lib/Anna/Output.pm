# vim: set expandtab:tabstop=4:shiftwidth=4
package Anna::Output;
use strict;
use warnings;

our @EXPORT = qw(irclog);
use Exporter;
our @ISA = qw(Exporter);

use Anna::Utils;

# sub: irclog
# DEPRECATED! DON'T USE
#
# Parameters:
#   N/A
#
# Returns:
#   undef
sub irclog {
    return undef;
    croak("irclog requires three parameters") unless (@_ == 3);
    my ($target, $msg, $conf) = @_;
    
    if (!(-e $ENV{'HOME'}."/.anna/logs")) {
        mkdir $ENV{'HOME'}."/.anna/logs" or die("Can't create directory: $!");
    }
    
    # Use lowercase
    $target = lc($target);
    
    if ($target eq 'status') {
        open(LOG, ">> $ENV{'HOME'}/.anna/logs/anna.log") or die("Can't open logfile: $!");
        printf LOG "%s %s\n", print_time(), $msg;
        close(LOG);
    } else {
        my $network = $conf->get('server');
        $network =~ s/.*\.(.*)\..*/$1/;
        if (!(-e $ENV{'HOME'}."/.anna/logs/".$network)) {
            mkdir $ENV{'HOME'}."/.anna/logs/".$network or die("Can't create directory: $!");
        }
        open(LOG, ">> $ENV{'HOME'}/.anna/logs/$network/$target.log") or die("Can't open logfile: $!");
        printf LOG "%s %s\n", print_time(), $msg;
        close(LOG);
    }
}

1;

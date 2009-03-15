# vim: et:ts=4:sw=4

use strict;
use warnings;

use Anna::Module;
use Anna::Utils;

my $m = Anna::Module->new('order');
$m->bindcmd('addorder', 'addorder')->bindcmd('order', 'order');

sub addorder {
    my ($order, $irc) = @_[ARG, IRC];
    if ($order =~ /^(.*)\s*=\s*(.*\#\#.*)$/) {
        my $key = trim($1);
        my $return = trim($2);
        
        my $dbh = $_[MOD]->{db};
        my $query = "SELECT * FROM orders WHERE key = ?";
        my $sth = $dbh->prepare($query);
        $sth->execute($key);
        $irc->yield(privmsg => $_[CHAN] => sprintf("%s: I already have %s on my menu", $_[NICK], $key))
            if ($sth->fetchrow());

        $query = "INSERT INTO orders (key, baka_order)
                 VALUES (?,?)";
        $sth = $dbh->prepare($query);
        $sth->execute($key, $return);
        $irc->yield(privmsg => $_[CHAN] => sprintf("%s: Master, I am here to serve (%s)", $_[NICK], $key));
    } else {
        $irc->yield(privmsg => $_[CHAN] => sprintf(
            "%s: Wrong syntax for addorder, Use %saddorder <key> = <order>. <order> must contain '##' which is substituted for the user's nick".
            $_[NICK], Anna::Config->new()->get('trigger')
        ));
    }
}

sub order {
    my ($nick, $order, $irc) = @_[NICK, ARG, IRC];
    
    # Discover syntax
    my ($out, $key);
    if ($order =~ /(.*) for (.*)/i) {
        $key = $1;
        $nick = $2;
    } else {
        $key = $order;
    }

    my $query = "SELECT * FROM orders WHERE key = ?";
    my $sth = $m->{db}->prepare($query);
    $sth->execute($key);
    
    my @row;
    if (@row = $sth->fetchrow()) {
        $out = $row[2];
        $out =~ s/##/$nick/;
    } else {
        # Key wasn't in database
        $out = 'hands ' . $nick . ' ' . $key;
    }

    $irc->yield(ctcp => $_[CHAN] => 'ACTION '.$out);
}

sub init {
    my $db = $m->{db};

    $db->do('CREATE TABLE IF NOT EXISTS orders (id INTEGER PRIMARY KEY UNIQUE, key TEXT, baka_order TEXT)');
    my %orders = (
        coffee      => 'hands ## a steaming cup of coffee',
        chimay      => 'hands ## a glass of Chimay',
        pepsi       => 'gives ## a can of Star Wars pepsi',
        'ice cream' => 'gives ## a chocolate ice cream with lots of cherries',
        beer        => 'slides a beer down the bar counter to ##',
        peanuts     => 'slides the bowl of peanuts down the bar counter to ##',
        ice         => "slips two ice cubes down ##'s neck"
    );

    my $sth = $db->prepare("INSERT OR IGNORE INTO orders (key, baka_order) VALUES (?, ?)");
    while (my ($k, $v) = each %orders) {
        $sth->execute($k, $v);
    }
}

1;

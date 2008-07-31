use strict;
use warnings;

use Anna::Module;
use Anna::DB;

my $m = Anna::Module->new('lart');
$m->bindcmd('addlart', 'addlart')->bindcmd('lart', 'lart');

sub addlart {
	my ($irc, $target, $lart) = @_[IRC, CHAN, ARG];
	
	if ($lart !~ /##/) {
		$irc->yield(privmsg => $target => 
			"Invalid LART. A Lart must contain '##' which is replaced by the luser's nick");
	}
	
	my $query = "INSERT INTO larts (lart) VALUES (?)";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute($lart);
	
	$irc->yield(privmsg => $target => "LART inserted!");
}


sub lart {
	my ($irc, $target, $nick, $luser) = @_[IRC, CHAN, NICK, ARG];
	
	$irc->yield(privmsg => $target => $nick . ": NAY THOU!")
		if (lc $luser eq lc $irc->nick_name);
	
	my $query = "SELECT * FROM larts";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute();

	my @larts;
	while (my $res = $sth->fetchrow_hashref) {
		push(@larts, $res->{'lart'});
	}
	
	my $lart = $larts[rand scalar @larts];
	$lart =~ s/##/$luser/;
	
	$luser = $nick if ($luser eq 'me');
	
	$irc->yield(ctcp => $target => 'ACTION '.$lart);
}

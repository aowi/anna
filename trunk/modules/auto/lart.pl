use strict;
use warnings;

use Anna::Module;
use Anna::DB;

my $m = Anna::Module->new('lart');
$m->bindcmd('addlart', 'addlart')->bindcmd('lart', 'lart');

sub addlart {
	my ($irc, $target, $m, $lart) = @_[IRC, CHAN, MOD, ARG];
	
	if ($lart !~ /##/) {
		$irc->yield(privmsg => $target => 
			"Invalid LART. A Lart must contain '##' which is replaced by the luser's nick");
	}
	
	my $query = "INSERT INTO larts (lart) VALUES (?)";
	my $sth = $m->db->->prepare($query);
	$sth->execute($lart);
	
	$irc->yield(privmsg => $target => "LART inserted!");
}


sub lart {
	my ($irc, $target, $nick, $m, $luser) = @_[IRC, CHAN, NICK, MOD, ARG];
	
	$irc->yield(privmsg => $target => $nick . ": NAY THOU!")
		if (lc $luser eq lc $irc->nick_name);
	$luser = $nick if ($luser eq 'me');
	
	my $query = "SELECT * FROM larts";
	my $sth = $m->db->prepare($query);
	$sth->execute();

	my @larts;
	while (my $res = $sth->fetchrow_hashref) {
		push(@larts, $res->{'lart'});
	}
	
	my $lart = $larts[rand scalar @larts];
	$lart =~ s/##/$luser/;
	
7	
	$irc->yield(ctcp => $target => 'ACTION '.$lart);
}

sub init {
	my $m = shift;

	$m->db->do('CREATE TABLE IF NOT EXISTS larts (id INTEGER PRIMARY KEY UNIQUE, lart TEXT);';
	my @larts = (
		"stabs ##",
		"throws a pile of dirt at ##",
		"throws seven litres of hot ice tea at ##",
		"fills ##'s mouth with lead",
		"beats ## with a kanji dictionary",
		"laughs at ##'s tasteless clothes",
		"summmons seven deadly gnomes and order them to bite ##'s toenails",
		"shoves a VB .Net manual down ##'s throat",
		"farts in ##'s general direction",
		"sends ## flying though the air with a Sexyjutsu(tm) stunt",
		"smacks ## with the big book of Windows errors",
		"installs XMMS/BMP on ##'s computer",
		"covers ## in COBOL manuals",
		"signs ## up for CS class with Munter",
		"slaps ## around his face with a big trout",
		"jabs a hot car lighter into ##'s eye sockets",
		"forces two hot jabbanero peppers up ##'s nostrils",
		"roundhouse-kicks ##",
		"slaps ## around with a big trout",
		"makes ## another victim of 1000-years-of-pain no jutsu",
		"locks ## in a dark room with naught but a monitor displaying windows me",
		"beats ## up with a cluebat",
		"shoots ## with a syringe full of Bird Flu!"
	);
	foreach my $lart (@larts) {
		my $sth = $m->db->prepare("INSERT OR REPLACE INTO larts (lart) VALUES (?)");
		$sth->exec($lart);
	}
}
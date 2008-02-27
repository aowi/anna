use strict;
use warnings;
use Anna::Module;
use Anna::DB;

## bot_addhaiku
# This subroutine adds a haiku poem to the database
# params is the poem to be added and $nick (to get the author)
sub addhaiku {
	my ($haiku, $irc, $channel, $nick) = @_[ARG, IRC, CHAN, NICK];
	
	if ($haiku =~ /.* ## .* ## .*/){
		my $query = "INSERT INTO haiku (poem, author) 
				VALUES (?, ?)";
		my $sth = Anna::DB->new->prepare($query);
		$sth->execute($haiku, $nick);
		$irc->yield(privmsg => "#frokostgruppen" => 
			'Haiku inserted, thanks '.$nick);
		return;
	}
	$irc->yield(privmsg => $channel =>
		"Wrong syntax for haiku. Should be '<line1> ## <line2> ## <line3>'");
}

## bot_haiku
# This returns a haiku
sub haiku {
	my ($irc, $channel) = @_[IRC, CHAN];
	my (@rows, @haiku);
	my $query = "SELECT * FROM haiku";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute();

	my $i = 0;
	while (@rows = $sth->fetchrow()) {
		$haiku[$i] = $rows[1];
		$i++;
	}
	my $out = $haiku[rand scalar @haiku];
	my @h = split(' ## ', $out);
	$irc->yield(privmsg => $channel => $_) for @h;
}

my $mod = Anna::Module->new("haiku");
# Module name, command, sub
$mod->registercmd("haiku", "haiku")->registercmd("addhaiku", "addhaiku");
1;

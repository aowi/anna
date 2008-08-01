use strict;
use warnings;
use Anna::Module;
use Anna::Utils;
use Anna::DB;
use POE;
use Carp;

## bot_addhaiku
# This subroutine adds a haiku poem to the database
# params is the poem to be added and $nick (to get the author)
sub addhaiku {
	my ($haiku, $irc, $channel, $nick) = @_[ARG, IRC, CHAN, NICK];
	
	if ($haiku =~ /.* ## .* ## .*/){
		my $query = "INSERT INTO haiku (poem, author) 
				VALUES (?, ?)";
		my $sth = Anna::DB->new("haiku")->prepare($query);
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
	my @haiku;
	my $query = "SELECT * FROM haiku";
	my $sth = Anna::DB->new("haiku")->prepare($query);
	$sth->execute();

	my $i = 0;
	while (my $row = $sth->fetchrow_hashref) {
		$haiku[$i] = $row->{poem};
		$i++;
	}
	my $out = $haiku[rand scalar @haiku];
	my @h = split(' ## ', $out);
	$irc->yield(privmsg => $channel => $_) for @h;
}

sub init {
	my $db = Anna::DB->new('haiku');
	debug_print "Creating tables...";
	$db->do('CREATE TABLE IF NOT EXISTS haiku (poem, author)');
	my @haikus = (
		q|Green frog ## is your body also ## freshly painted?|,
		q|'the old pond ## a frog leaps ## the sound of water|,
		q|Sick and feverish ## Glimpse of cherry blossoms ## Still shivering|,
		q|Without flowing wine ## How to enjoy lovely ## Cherry blossoms?|,
		q|It's 1:25AM ## My wine glass is empty ## I'm going to bed|,
		q|Seeing my great fault ## Through darkening blue windows ## I begin again|,
		q|Errors have occurred. ## We won't tell you where or why. ## Lazy programmers|,
		q|Chaos reigns within. ## Reflect, repent, and reboot. ## Order shall return|,
		q|wind catches lily ## scatt'ring petals to the wind: ## segmentation fault|,
		q|Stay the patient course ## Of little worth is your ire ## The network is down|,
		q|To have no errors ## Would be life without meaning ## No struggle, no joy|,
		q|Out of memory. ## We wish to hold the whole sky, ## But we never will|,
		q|The ten thousand things ## How long do any persist? ## Netscape, too, has gone|
	);
	debug_print "Inserting haikus";
	my $sth = $db->prepare(q|INSERT OR IGNORE INTO haiku (poem, author) VALUES (?, 'Anna^')|);
	foreach my $haiku (@haikus) {
		$sth->execute($haiku);
	}
}

my $mod = Anna::Module->new("haiku");
# Module name, command, sub
$mod->bindcmd("haiku", "haiku")->bindcmd("addhaiku", "addhaiku");
1;

use strict;
use warnings;
use Anna;
use Anna::DB;

## bot_addhaiku
# This subroutine adds a haiku poem to the database
# params is the poem to be added and $nick (to get the author)
sub addhaiku {
	my ($heap, $haiku, $nick) = @_;
	
	if ($haiku =~ /.* ## .* ## .*/){
		my $query = "INSERT INTO haiku (poem, author) 
				VALUES (?, ?)";
		my $sth = Anna::DB->new->prepare($query);
		$sth->execute($haiku, $nick);
		return 'Haiku inserted, thanks '.$nick;
	}
	return "Wrong syntax for haiku. Should be '<line1> ## <line2> ## <line3>'";
}

## bot_haiku
# This returns a haiku
sub haiku {
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
	$out =~ s/ ## /\n/g;
	return $out;
}

Anna::command_bind("haiku", "haiku");
Anna::command_bind("addhaiku", "addhaiku");

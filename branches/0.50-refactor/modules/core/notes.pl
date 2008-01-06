use strict;
use warnings;
use Anna;
use Anna::DB;

## bot_mynotes
# Return all notes belonging to a user
# Takes one param: username to search for
sub mynotes {
	my ($irc, $channel, $nick, $type) = @_[1, 2, 3, 5];
	
	my $query = "SELECT word FROM notes WHERE author = ? ORDER BY word ASC";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute($nick);
	my (@row, @words);
	my $i = 0;
	while (@row = $sth->fetchrow()) {
		$words[$i] = $row[0];
		$i++;
	}

	if ((scalar(@words) > 15) && ($type eq 'public')) {
		# Will not display more than 15 notes in 'public' (channels)
		my $out = sprintf("%s: Too many notes. Displaying 15 first (message me to see all):", $nick);
		for (my $j = 0; $j <= 15; $j++) {
			$out .= " '".$words[$j]."',";
		}
		$irc->yield(privmsg => $channel => $out);
		return;
	}
	
	if (scalar(@words) == 0) {
		$irc->yield(privmsg => $channel => $nick.": you haven't taken any notes yet... better get starting soonish!");
		return;
	}
	
	my $words;
	foreach (@words) {
		$words .= "'$_', "
	}
	$words =~ s/(.*), /$1/;
	$irc->yield(privmsg => $channel => $nick.": your notes: $words");
}

command_bind("notes", "mynotes", "mynotes");

use strict;
use warnings;
use Anna::DB;
use Anna::Utils;
use Anna::Module;

my $m = Anna::Module->new('notes');
$m->bindcmd('mynotes', 'mynotes')->bindcmd('notes', 'notes');

## bot_mynotes
# Return all notes belonging to a user
# Takes one param: username to search for
sub mynotes {
	my ($irc, $channel, $nick, $type) = @_[IRC, CHAN, NICK, TYPE];
	
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

## bot_note
# This manages calc-stuff. Calc is a small system to associate a word or 
# little sentence with a longer sentence, answer, solution, retort, whatever.
sub note {
	my ($note, $irc, $target, $nick) = @_[ARG, IRC, CHAN, NICK];
	
	my ($dbh, $query, $sth, @row);
	$dbh = new Anna::DB;
	# Print random note if nothing is specified
	unless ($note) {
		$query = "SELECT * FROM notes";
		$sth = $dbh->prepare($query);
		$sth->execute();
		
		my (@words, @answers, @authors);
		my $i = 0;
		while (@row = $sth->fetchrow()) {
			$words[$i] = $row[1];
			$answers[$i] = $row[2];
			$authors[$i] = $row[3];
			$i++;
		}
		if ($i == 0) {
			$irc->yield(privmsg => $target => 
				"No notes found in database. You all better start taking some notes!");
			return;
		}
		my $num = rand scalar @words;
		$irc->yield(privmsg => $target => 
			"* ".$words[$num]." = ".$answers[$num]." [added by ".$authors[$num]."]");
		return;
	}
	
	# Find out what to do
	if ($note =~ /^(.+?)\s*=\s*(.+)$/) {
		# User want to insert a new quote
		# Test if word exists
		my $word = trim($1);
		my $answer = trim($2);
		return 'FALSE' if (($word eq '') or ($answer eq ''));
		
		$query = "SELECT * FROM notes WHERE word = ?";
		$sth = $dbh->prepare($query);
		$sth->execute($word);
		if (@row = $sth->fetchrow()) {
			if ($nick eq $row[3]) {
				$query = "UPDATE notes SET answer = ? WHERE word = ?";
				$sth = $dbh->prepare($query);
				$sth->execute($answer, $word);
				$irc->yield(privmsg => $target => 
					"'".$word."' updated, thanks ".$nick."!");
				return;
			}
			$irc->yield(privmsg => $target => 
				"Sorry ".$nick." - the word '".$word."' already exists in my database");
			return;
		}
		
		# Insert new note
		$query = "INSERT INTO notes (word, answer, author, date)
			     VALUES (?, ?, ?, ".(int time).")";
		$sth = $dbh->prepare($query);
		$sth->execute($word, $answer, $nick);
		$irc->yield(privmsg => $target => "'".$word."' added to the database, thanks ".$nick."!");
		return;
	}
	
	$note = trim($note);
	$query = "SELECT * FROM notes WHERE word = ?";
	$sth = $dbh->prepare($query);
	$sth->execute($note);
	@row = '';
	if (@row = $sth->fetchrow()) {
		$irc->yield(privmsg => $target => "* ".$row[1]." = ".$row[2]." [added by ".$row[3]."]");
	} else {
		$irc->yield(privmsg => $target => "'".$note."' was not found, sorry");
	}
}

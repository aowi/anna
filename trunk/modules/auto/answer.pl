use strict;
use warnings;

use Anna::Module;

my $m = Anna::Module->new('answer');
$m->bindcmd('addanswer', 'addanswer')->bindcmd('question', 'answer');

sub addanswer {
	my ($answer, $nick) = @_[ARG, NICK];

	my $query = "INSERT INTO answers (answer) VALUES (?)";
	my $sth = $m->{db}->prepare($query);
	$sth->execute($answer);
	$m->irc->reply("Answer added to database, thanks $nick!");
}

sub answer {
	my $query = "SELECT * FROM answers";
	my $sth = $m->{db}->prepare($query);
	$sth->execute();
	
	my @answers;
	while (my $res = $sth->fetchrow_hashref) {
		push(@answers, $res->{'answer'});
	}
	$m->irc->reply_hilight($answers[rand scalar @answers]);
}

sub init {
	my $db = $m->{db};
	$db->do(q|CREATE TABLE IF NOT EXISTS answers (answer)|);
	my @answers = (
		q|Yes|,
		q|No|, 
		q|Absolutely|,
		q|My sources say no|,
		q|Yes definitely|,
		q|42!|,
		q|Very doubtful|,
		q|Most likely|,
		q|Forget about it|,
		q|Are you kidding?|,
		q|Go for it!|,
		q|Not now|,
		q|Looking good|,
		q|Who knows|,
		q|A definite yes|,
		q|You will have to wait|,
		q|Yes, in due time|,
		q|I have my doubts|,
		q|I don't know, and I don't care... I'm just a mindless bot!|,
		q|No, commit seppuku|,
		q|No, kick everyone|,
		q|A question... a question? Here I am, brain the size of a planet, and they get me to answer stupid questions. Call that job satisfaction? 'Cos I don't...|
	);

	my $sth = $db->prepare(q|INSERT OR IGNORE INTO answers (answer) VALUES (?)|);
	foreach my $ans (@answers) {
		$sth->execute($ans);
	}
}


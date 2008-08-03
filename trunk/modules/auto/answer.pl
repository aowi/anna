use strict;
use warnings;

use Anna::Module;
use Anna::DB;

my $m = Anna::Module->new('answer');
$m->bindcmd('addanswer', 'addanswer')->bindcmd('question', 'answer');

sub addanswer {
	my ($answer, $nick, $irc, $target) = @_[ARG, NICK, IRC, CHAN];

	my $query = "INSERT INTO answers (answer) VALUES (?)";
	my $sth = Anna::DB->new('answer')->prepare($query);
	$sth->execute($answer);
	$irc->yield(privmsg => $target => "Answer added to database, thanks $nick!");
}

sub answer {
	my ($nick, $irc, $target) = @_[NICK, IRC, CHAN];

	my $query = "SELECT * FROM answers";
	my $sth = Anna::DB->new('answer')->prepare($query);
	$sth->execute();
	
	my @answers;
	while (my $res = $sth->fetchrow_hashref) {
		push(@answers, $res->{'answer'});
	}
	$irc->yield(privmsg => $target => $nick.": ".$answers[rand scalar @answers]);
}

sub init {
	my $db = new Anna::DB 'answer';
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


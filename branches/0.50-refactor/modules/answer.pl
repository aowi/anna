use strict;
use warnings;

use Anna::Module;
use Anna::DB;

my $m = Anna::Module->new('answer');
$m->bindcmd('addanswer', 'addanswer')->bindcmd('question', 'answer');

sub addanswer {
	my ($answer, $nick, $irc, $target) = @_[ARG, NICK, IRC, CHAN];

	my $query = "INSERT INTO answers (answer) VALUES (?)";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute($answer);
	$irc->yield(privmsg => $target => "Answer added to database, thanks $nick!");
}

sub answer {
	my ($nick, $irc, $target) = @_[NICK, IRC, CHAN];

	my $query = "SELECT * FROM answers";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute();
	
	my @answers;
	while (my $res = $sth->fetchrow_hashref) {
		push(@answers, $res->{'answer'});
	}
	$irc->yield(privmsg => $target => $nick.": ".$answers[rand scalar @answers]);
}

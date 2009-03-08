use strict;
use warnings;

use Anna::Module;

my $mod = new Anna::Module 'dice';
$mod->bindregexp('\d+d\d+', 'dice')->bindcmd('dice', 'dice');

sub dice {
	my ($msg, $nick) = @_[ARG, NICK];
	if ($msg =~ /(\d+)d(\d+)/i) {
		my $dice = $1;
		my $sides = $2;

		if ($sides < 1) {
			$mod->irc->reply('It seems ' . $nick . ' smoked too much pot. Or has anyone ever seen a die without sides?');
			return;
		} elsif ($sides == 1) {
			$mod->irc->reply($nick . ' will soon show us something wondrous - the first die with only one side!');
			return;
		} elsif ($sides >= 1000) {
			$mod->irc->reply($nick . ' needs to trap down on the sides. Seriously, try fewer sides!');
			return;
		} elsif ($dice >= 300) {
			$mod->irc->reply('Is ' . $nick . ' going to take a bath in dice? Seriously, try fewer dice!');
			return;
		}
		
		$dice = 1 if ($dice < 1);
		# Here we go
		my ($i, $rnd, $value, $throws);
		$value = 0;
		for ($i = 1; $i <= $dice; $i++) {
			$rnd = int(rand($sides)) + 1;
			$value = $value + $rnd;
			
			if ($i != $dice){
				$throws .= $rnd . ", ";
			} else {
				$throws .= $rnd;
			}
		}
		
		if ($dice <= 50) {
			$mod->irc->reply_hilight($value . ' (' . $throws . ')');
		} else {
			$mod->irc->reply_hilight($value . ' (too many throws to show)');
		}
		return;
	}
	# It shouldn't be possible to end up here, but anyway
	$mod->irc->reply($msg . ': Syntax error in diceroll. Correct syntax is <int>d<int>');
}

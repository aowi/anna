use strict;
use warnings;

use Anna::Module;
use Anna::Utils;
use Anna::Auth;

my $m = Anna::Module->new('auth')->protect;
$m->bindmsg('auth', 'auth')->bindmsg('register', 'register')->bindcmd('whoami', 'whoami');

# sub: auth
# Authenticates a user with anna
sub auth {
	my ($arg, $nick, $host) = @_[ARG, NICK, HOST];
	
	my ($user, $pass);
	# Accept auth <nick> <pass> as well as auth <pass> (use $nick in last 
	# case)
	if (trim($arg) =~ / /) {
		($user, $pass) = split(/ /, trim($arg));
	} else {
		($user, $pass) = ($nick, trim($arg));
	}
	unless ($user && $pass) {
		$m->irc->reply("Error: you must supply a username and a password");
		return 1;
	}
	
	my $auth = new Anna::Auth;
	my $msg;
	if ($auth->identify($user, $pass, $nick, $host)) {
		$msg = sprintf "Welcome back %s!", $user;
	} else {
		$msg = "Error: wrong username or password!";
	}
	$m->irc->reply($msg);
	return 1;
}

sub register {
	my ($arg, $nick, $host) = @_[ARG, CHAN, NICK, HOST];
	my ($user, $pass) = split(/ /, trim($arg));
	if ($user eq '' || $pass eq '') {
		$m->irc->reply("Error: you must speicify a username and a password");
		return;
	}

	my $auth = new Anna::Auth;
	if ($auth->register($user, $pass)) {
		$auth->identify($user, $pass, $nick, $host);
		$m->irc->reply(sprintf("You are now registered and identified with username: '%s' and password: '%s'", $user, $pass));
	} else {
		$m->irc->reply($auth->errstr);
	}
}

sub whoami {
	my $host = $_[HOST];
	my $auth = new Anna::Auth;
	if (my $u = $auth->host2user($host)) {
		$m->irc->reply_hilight(sprintf "You are identified as %s", $u->{user});
	} else {
		$m->irc->reply_hilight("You are not identified");
	}
}
1;

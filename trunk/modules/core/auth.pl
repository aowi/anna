use strict;
use warnings;

use Anna::Module;
use Anna::Utils;
use Anna::Auth;

my $m = Anna::Module->new('auth');
$m->bindmsg('auth', 'auth')->bindmsg('register', 'register')->bindcmd('whoami', 'whoami');

# sub: auth
# Authenticates a user with anna
sub auth {
	my ($arg, $irc, $target, $nick, $host) = @_[ARG, IRC, CHAN, NICK, HOST];
	
	my ($user, $pass);
	# Accept auth <nick> <pass> as well as auth <pass> (use $nick in last 
	# case)
	if (trim($arg) =~ / /) {
		($user, $pass) = split(/ /, trim($arg));
	} else {
		($user, $pass) = ($nick, trim($arg));
	}
	unless ($user && $pass) {
		$irc->yield(privmsg => $target => "Error: you must supply a username and a password");
		return 1;
	}
	
	my $auth = new Anna::Auth;
	my $msg;
	if ($auth->identify($user, $pass, $nick, $host)) {
		$msg = sprintf "Welcome back %s!", $user;
	} else {
		$msg = "Error: wrong username or password!";
	}
	$irc->yield(privmsg => $target => $msg);
	return 1;
}

sub register {
	my ($arg, $irc, $target, $nick, $host) = @_[ARG, IRC, CHAN, NICK, HOST];
	my ($user, $pass) = split(/ /, trim($arg));
	if ($user eq '' || $pass eq '') {
		$irc->yield(privmsg => $target => "Error: you must speicify a username and a password");
		return;
	}

	my $auth = new Anna::Auth;
	if ($auth->register($user, $pass)) {
		$auth->identify($user, $pass, $nick, $host);
		$irc->yield(privmsg => $target => sprintf("You are now registered and identified with username: '%s' and password: '%s'", $user, $pass));
	} else {
		$irc->yield(privmsg => $target => $auth->errstr);
	}
}

sub whoami {
	my ($irc, $target, $nick, $host) = @_[IRC, CHAN, NICK, HOST];
	my $auth = new Anna::Auth;
	if (my $u = $auth->host2user($host)) {
		$irc->yield(privmsg => $target => sprintf "%s: You are identified as %s", $nick, $u->{user});
	} else {
		$irc->yield(privmsg => $target => sprintf "%s: You are not identified", $nick);
	}
}
1;

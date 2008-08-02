package Anna::Auth;
use strict;
use warnings;

use Anna::DB;
use Anna::Utils;

sub new {
	return bless {}, shift;
}

sub identify {
	my ($self, $user, $pass, $nick, $host);
	if (ref $_[0]) {
		($self, $user, $pass, $nick, $host) = @_;
	} else {
		($user, $pass, $nick, $host) = @_;
	}

	my $query = "SELECT * FROM users WHERE username = ?";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute($user);
	if (my @row = $sth->fetchrow()) {
		if (crypt($pass, substr($row[2], 0, 2)) eq $row[2]) {
			# We have a match! Light it
#			$heap->{auth}->{$host} = { user => $user, nick => $nick };
			debug_print(sprintf("Nick %s [%s] successfully identified as %s", $nick, $host, $user));
			return 1;
		}
	}
	debug_print(sprintf("Nick %s [%s] failed identificatation as %s", $nick, $host, $user));
	return 0;
}
sub register {}
sub add_user_to_role {}
sub user_can {}

1;

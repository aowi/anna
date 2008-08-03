package Anna::Auth;
use strict;
use warnings;

use Anna::DB;
use Anna::Utils;
use POE; 
use Data::Dumper;

my %auth = ();

sub new {
	return bless {}, shift;
}

sub identify {
	my ($self, $user, $pass, $nick, $host) = @_;

	my $query = "SELECT * FROM users WHERE username = ?";
	my $sth = Anna::DB->new->prepare($query);
	$sth->execute($user);
	if (my @row = $sth->fetchrow()) {
		if (crypt($pass, substr($row[2], 0, 2)) eq $row[2]) {
			# We have a match! Light it
			$auth{$host} = { user => $user, nick => $nick };
			debug_print(sprintf("Nick %s [%s] successfully identified as %s", $nick, $host, $user));
			Dumper(%auth);
			return 1;
		}
	}
	debug_print(sprintf("Nick %s [%s] failed identificatation as %s", $nick, $host, $user));
	return 0;
}

sub register {
	my ($self, $user, $pass) = @_;
	
	unless (defined $user && defined $pass) {
		$self->{_errmsg} = "Error - you must supply a username and a password";
		return 0;
	}
	
	my $dbh = new Anna::DB;
	my $query = "SELECT id FROM users WHERE username = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($user);
	if ($sth->fetchrow) {
		$self->{_errmsg} = "Error - username already exists";
		return 0;
	}
	
	$query = "INSERT INTO users (username, password) VALUES (?, ?)";
	$sth = $dbh->prepare($query);
	my @salt_chars = ('a'..'z','A'..'Z','0'..'9');
	my $salt = $salt_chars[rand(63)] . $salt_chars[rand(63)];
	$sth->execute($user, crypt($pass, $salt));
	return 1;
}

sub errstr {
	my $self = shift;
	return $self->{_errmsg};
}

sub add_user_to_role {}
sub user_can {}

sub host2user {
	my ($self, $host) = @_;
	if (exists $auth{$host}) {
		return $auth{$host};
	} else {
		$self->{_errmsg} = sprintf "Error: not identified";
		return 0;
	}
}

1;

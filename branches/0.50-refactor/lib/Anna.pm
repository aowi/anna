package Anna;
use strict;
use warnings;

our @EXPORT = qw(command_bind);
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Anna::DB;
use Carp;

# Takes command and func to be run when command is encountered
sub command_bind {
	unless (@_ == 3) {
		carp "command_bind needs three parameters. Got @_";
		return 0;
	}
	my ($mod, $cmd, $sub) = @_;
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Failed to obtain DB handle: $DBI::errstr";
		return 0;
	}
	if (cmd_exists_in_db($cmd)) {
		carp "Failed to bind command: $cmd already bound by another module";
		return 0;
	}
	my $rv = $dbh->do("INSERT INTO commands (module_name, command, sub) VALUES (?, ?, ?)", undef, 
			($mod, $cmd, $sub));
	unless (defined $rv) {
		carp "Failed to add command $cmd to DB: $DBI::errstr";
		return 0;
	}
	return 1;
}

# Takes a command-name. Returns true if command exists in DB
sub cmd_exists_in_db {
	unless (@_ >= 1) {
		carp "cmd_exists_in_db takes one parameter";
		return 0;
	}
	my $cmd = shift;
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return 0;
	}
	my $sth = $dbh->prepare("SELECT command FROM commands WHERE command = ?");
	$sth->execute($cmd);
	$sth->fetchrow ? return 1 : return 0;
}

1;

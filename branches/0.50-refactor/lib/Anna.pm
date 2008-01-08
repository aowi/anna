package Anna;
use strict;
use warnings;

our @EXPORT = qw(command_bind);
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Anna::DB;
use Carp;

# Function: command_bind
# 
# Binds a command from IRC to a subroutine in a module
#
# Parameters:
# 
#   mod - name of the module that calls
#   cmd - the command that should be bound
#   sub - the subroutine to bind to
#
# Returns:
#
#   0 upon success, 1 upon failure (error message is carp'd)
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

# Func: cmd_exists_in_db
# Checks if a command already exists in the table of commands
#
# Parameters:
#    cmd - command to scan for
#
# Returns:
#    0 if the command doesn't exists, 1 if it's there
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

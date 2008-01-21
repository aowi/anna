package Anna;
use strict;
use warnings;

our @EXPORT = qw(command_bind);
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Anna::DB;
use Anna::Module;
use Carp;

# Function: command_bind
# DEPRECATED
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
	if (Anna::Module::cmd_exists_in_db($cmd)) {
		carp "Failed to bind command: $cmd already bound by another module";
		return 0;
	}
	my $rv = $dbh->do(
		"INSERT INTO modules (name, type, value, sub) 
		VALUES (?, 'command', ?, ?)", 
		undef, ($mod, $cmd, $sub));
	unless (defined $rv) {
		carp "Failed to add command $cmd to DB: $DBI::errstr";
		return 0;
	}
	return 1;
}


1;

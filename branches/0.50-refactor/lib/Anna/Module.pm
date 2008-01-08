package Anna::Module;
use strict;
use warnings;
use Anna::DB;
use Carp;

# var: $current_module
# Package-global, that holds the name of the module being parsed at the moment.
my $current_module;

# sub: empty_db
# Removes all commands from the command-table. Used at startup to clean up leftover cruft
#
# Parameters:
# 	none
#
# Returns:
# 	1 on success, 0 on failure
sub empty_db {
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Failed to obtain DB handle: $DBI::errstr";
		return 0;
	}
	unless (defined $dbh->do("DELETE FROM commands")) {
		carp "Failed to delete all commands: $DBI::errstr";
		return 0;
	}
	return 1;
}

# sub: execute
# Scans the command-table for commands matching the provided message. Executes the corresponding
# module subroutine if a command is found.
#
# Parameters:
# 	cmd - the full command (including args, excluding trigger)
# 	heap - ref to POE heap
# 	channel - the target the message is to be returned to (in case of channels a channel-name,
# 	in case of privmsgs the user who sent the message)
# 	nick - the nickname of the sender of the message
# 	host - senders hostname
# 	type - type of message. 'public' for messages to channels, 'msg' for private messages
#
# Returns:
# 	1
sub execute {
	return 1 unless (@_ == 6);
	my ($cmd, $heap, $channel, $nick, $host, $type) = @_;
	
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Failed to obtain DB handle: $DBI::errstr";
		return 1;
	}
	my ($c, $m) = split(' ', $cmd, 2);
	my $sth = $dbh->prepare("SELECT * FROM commands WHERE command = ?");
	$sth->execute($c);
	my ($module, $sub);
	if (my $row = $sth->fetchrow_hashref) {
		$module = $row->{'module_name'};
		$sub = $row->{'sub'};
	} else {
		return 1;
	}
	#load($module) or carp "Loading failed";
	# XXX turning of strict 'refs'... just pretend you didn't see this
	# Params are: Message, IRC-object, channel, nick, host
	no strict 'refs';
	eval {
		&$sub($m, $heap->{irc}, $channel, $nick, $host, $type);
	};
	print $@."\n" if (defined $@);
	use strict 'refs';

	return 1;
}

# sub: load
# Takes a module-name or a filename and scans for a module with that name in Anna's 
# module-directories. If a module is found, it is loaded (read and eval'd)
#
# Parameters:
# 	m - module name or filename
# 
# Returns:
# 	1 on successfull loading, 0 on failure
sub load {
	unless (@_ >= 1) {
		carp "load takes one parameter";
		return 0;
	}
	my $m = shift;
	$current_module =  $m;
	if ($m =~ /\.pl$/) {
		$current_module =~ s/.*\/(.*)\.pl$/$1/;
	}

	my $code;
	my @path = ("/.anna/modules/", "/.anna/modules/core/", "/.anna/modules/auto/");
	foreach my $p (@path) {
		if (-f $ENV{'HOME'}.$p.$m.".pl") {
			open(MOD, "<", $ENV{'HOME'}.$p.$m.".pl") or croak $!;
			while (<MOD>) {
				$code .= $_;
			}
			close(MOD) or croak $!;
			last;
		}
	}
	unless ($code) {
		carp "Can't find $m";
		return 0;
	}
	eval $code;
	if ($@) {
		carp "Failed to load $m: $@";
		# XXX cleanup possible cruft from database
		return 0;
	}
	return 1;
}

# sub: unload
# Unloads a module (for now, just deletes the commands associated with that module-name
#
# Parameters:
# 	m - name of module
#
# Returns:
# 	1 on success, 0 on failure
sub unload {
	unless (@_ >= 1) {
		carp "unload takes one parameter";
		return 0;
	}
	my $m = shift;
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Unable to obtain DB handle: $DBI::errstr";
		return 0;
	}
	unless (defined $dbh->do("DELETE FROM commands WHERE module_name = ?", undef, ($m))) {
		carp "Failed to unload module $m: $DBI::errstr";
		return 0;
	}
	return 1;
}

1;

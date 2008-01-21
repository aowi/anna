package Anna::Module;
use strict;
use warnings;
use Anna::DB;
use Carp;

# var: $current_module
# Package-global, that holds the name of the module being parsed at the moment.
my $current_module;

# sub: new
# Create new instance of Anna::Module. Modules can use this to register for 
# events/commands and much more.
#
# Parameters:
# 	name - module name
#
# Returns:
# 	Anna::Module-object, zero on failure
sub new {
#	return 0 unless (@_ == 1);
	my ($class, $name) = @_;
	if (module_loaded($name)) {
		carp "Module $name already loaded";
		return 0;
	}
	my $module = {name => $name};
	return bless $module, $class;
}

# sub: module_loaded
# Checks if a module with the supplied name has already been loaded
#
# Parameters:
# 	name - module name
#
# Returns:
# 	1 if module is loaded
# 	0 if module isn't loaded
# 	1 if called as a method
sub module_loaded {
	return undef unless (@_ == 1);
	my $n = shift;
	if (ref $n) {
		# Called as method
		return 1;
	} else {
		my $dbh = new Anna::DB or return undef;
		my $sth = $dbh->prepare("SELECT * FROM modules WHERE name = ? LIMIT 1");
		$sth->execute($n);
		return 1 if ($sth->fetchrow);
	}
	return 0;
}


# sub: empty_db
# Removes all commands from the command-table. Used at startup to clean up leftover cruft
#
# Parameters:
# 	none
#
# Returns:
# 	1 on success, 0 on failure
sub empty_db {
	if (@_ && ref $_[0]) {
		# Called as method, abort
		carp "Don't call empty_db as a method!!";
		return 0;
	}
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Failed to obtain DB handle: $DBI::errstr";
		return 0;
	}
	unless (defined $dbh->do("DELETE FROM modules")) {
		carp "Failed to empty module database: $DBI::errstr";
		return 0;
	}
	return 1;
}

# Func: cmd_exists_in_db
# Checks if a command already exists in the modules-table
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
	if (ref $cmd) {
		my $pkg = $cmd;
		$cmd = shift;
	}
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return 0;
	}
	my $sth = $dbh->prepare("SELECT value FROM modules WHERE type = 'command' AND value = ?");
	$sth->execute($cmd);
	$sth->fetchrow ? return 1 : return 0;
}


# sub: registercmd
# Used as a method to register a command
#
# Parameters:
# 	cmd - the cmd to listen for
# 	sub - the sub to call when cmd is found
#
# Returns:
# 	The object (caller)
sub registercmd {
	unless (@_ == 3) {
		carp "registercmd takes two parameters: command and sub";
		return $_[0];
	}
	my $pkg = shift;
	my ($cmd, $sub) = @_;
	my $mod = $pkg->{'name'};
	if (cmd_exists_in_db($cmd)) {
		carp "Failed to register cmd $cmd: Already existing";
		return $pkg;
	}
	my $dbh = new Anna::DB or return $pkg;
	my $rv = $dbh->do(
		"INSERT INTO modules (name, type, value, sub) 
		VALUES (?, 'command', ?, ?)", 
		undef, ($mod, $cmd, $sub));
	unless (defined $rv) {
		carp "Failed to add command $cmd to DB: $DBI::errstr";
		return $pkg;
	}
	return $pkg;
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
	my $sth = $dbh->prepare("SELECT * FROM modules WHERE type = 'command' AND value = ?");
	$sth->execute($c);
	my ($module, $sub);
	if (my $row = $sth->fetchrow_hashref) {
		$module = $row->{'name'};
		$sub = $row->{'sub'};
	} else {
		return 1;
	}
	#load($module) or carp "Loading failed";
	# XXX turning off strict 'refs'... just pretend you didn't see this
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
	unless (defined $dbh->do("DELETE FROM modules WHERE name = ?", undef, ($m))) {
		carp "Failed to unload module $m: $DBI::errstr";
		return 0;
	}
	return 1;
}

1;

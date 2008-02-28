package Anna::Module;
use strict;
use warnings;

use Exporter;
our @EXPORT_OK = qw();
our @EXPORT = qw(IRC CHAN NICK HOST TYPE MOD ARG);
our @ISA = qw(Exporter);

use Anna::DB;
use Carp;

# var: %modules
# Global, that holds the name of all modules with registered events. Don't
# mess with this outside Anna::Module!
our %modules;

# ugly, dirty and alltogether bad.
# These subs are exported per default and used as constant expressions by 
# modules, to avoid having to keep track of argument order, and to allow us to
# reorder or add more args later, without breaking existing modules.
sub IRC  () {  0 }
sub CHAN () {  1 }
sub NICK () {  2 }
sub HOST () {  3 }
sub TYPE () {  4 }
sub MOD  () {  5 }
sub ARG  () {  6 }

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
	my ($class, $name) = @_;
	unless (defined $name && $name) {
		carp "new Anna::Module requested, but no name was supplied";
		return 0;
	}
	if (module_loaded($name)) {
		carp "Module $name already loaded";
		return 0;
	}
	my $module = {name => $name};
	my $r = bless $module, $class;
	$modules{$name} = $r;
	return $r;
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
		return 1 if (exists $modules{$n});
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
	my $sth = $dbh->prepare(qq{
		SELECT value FROM modules WHERE type = 'command' AND value = ?
	});
	$sth->execute($cmd);
	$sth->fetchrow ? return 1 : return 0;
}


# sub: bindcmd
# Used as a method to bind a command to a subroutine
#
# Parameters:
# 	cmd - the cmd to listen for
# 	sub - the sub to call when cmd is found
#
# Returns:
# 	The object (caller)
sub bindcmd {
	unless (@_ == 3) {
		carp "bindcmd takes two parameters: command and sub";
		return $_[0];
	}
	my $pkg = shift;
	my ($cmd, $sub) = @_;
	my $mod = $pkg->{'name'};
	if (cmd_exists_in_db($cmd)) {
		carp "Failed to bind cmd $cmd: Already existing";
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

# sub: bindregxp
#
# Binds a regular expression to a subroutine. When the regular expression
# matches a message written in channel, the sub will be triggered.
#
# Params:
# 	regexp 	- the regular expression (as a scalar/string, without //)
# 	sub 	- the subroutine that will be executed when the regexp is found
#
# Returns:
# 	the Module-object
sub bindregexp {
	my ($pkg, $rx, $sub) = @_;
	eval { "" =~ /$rx/ };
	if ($@) {
		carp "Invalid pattern $rx ignored: $@";
		return $pkg;
	}

	my $dbh = new Anna::DB or return $pkg;
	my $rv = $dbh->do(qq{
		INSERT INTO modules (name, type, value, sub)
		VALUES (?, 'regexp', ?, ?)},
		undef, ($pkg->{'name'}, $rx, $sub)
	);
	unless (defined $rv) {
		carp "Failed to add regexp $rx to DB: $DBI::errstr";
	}
	return $pkg;	
}

# sub: bindevent
#
# Binds a given event to a subroutine. When the event is triggered, the 
# subroutine is executed with the relevant event information.
#
# Params:
# 	event	- event to listen for (see POE::IRC::Component docs
# 	sub		- subroutine that will be executed when the event is triggered
sub bindevent {}

# sub: execute
# Scans the command-table for commands matching the provided message. Executes
# the corresponding module subroutine if a command is found.
#
# Parameters:
# 	msg - the full message, that were recieved
# 	heap - ref to POE heap
# 	channel - the target the message is to be returned to (in case of channels a 
# 	channel-name, in case of privmsgs the user who sent the message)
# 	nick - the nickname of the sender of the message
# 	host - senders hostname
# 	type - type of message. 'public' for messages to channels, 'msg' for private messages
#
# Returns:
# 	1
sub execute {
	return 1 unless (@_ == 6);
	my ($msg, $heap, $channel, $nick, $host, $type) = @_;
	my $c = new Anna::Config;
	my ($trigger, $botnick) = ($c->get('trigger'), $c->get('nick'));
	# Command
	if ($msg =~ /^(\Q$trigger\E|\Q$botnick\E[ :,-]+)/) {
		my $cmd = $msg;
		$cmd =~ s/^(\Q$trigger\E|\Q$botnick\E[ :,-]+\s*)//;
		do_cmd($cmd, $heap, $channel, $nick, $host, $type);
		return 1;
	}

	# Regexp
	my $dbh = new Anna::DB or return 1;
	my $sth = $dbh->prepare(qq{
		SELECT * FROM modules WHERE type = 'regexp'
	});
	$sth->execute;
	while (my $res = $sth->fetchrow_hashref)  {
		my ($rx, $name, $sub) = ($res->{'value'}, $res->{'name'}, $res->{'sub'});
		if ($msg =~ m/$rx/) {
			my $s = \&{ "Anna::Module::".$name."::".$sub};
			eval '$s->($heap->{irc}, $channel, $nick, $host, $type, $modules{$name}, $msg)';
			confess $@ if $@;
		}
	}
	return 1;
}

# sub: do_cmd
# Handles command-checking and execution, if a command-trigger is found.
#
# Params:
# 	msg - the full message, that were recieved
# 	heap - ref to POE heap
# 	channel - the target the message is to be returned to (in case of channels a 
# 	channel-name, in case of privmsgs the user who sent the message)
# 	nick - the nickname of the sender of the message
# 	host - senders hostname
# 	type - type of message. 'public' for messages to channels, 'msg' for private messages
#
# Returns: 	
# 	1
sub do_cmd {
	my ($cmd, $heap, $channel, $nick, $host, $type) = @_;
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Failed to obtain DB handle: $DBI::errstr";
		return 1;
	}
	my ($c, $m) = split(' ', $cmd, 2);
	my $sth = $dbh->prepare(qq{
		SELECT * FROM modules WHERE type = 'command' AND value = ?
	});
	$sth->execute($c);
	my ($name, $sub);
	if (my $row = $sth->fetchrow_hashref) {
		$name = $row->{'name'};
		$sub = $row->{'sub'};
	} else {
		return 1;
	}
	
	my $s = \&{ "Anna::Module::".$name."::".$sub };
	eval '$s->($heap->{irc}, $channel, $nick, $host, $type, $modules{$name}, $m)';
	confess $@ if $@;

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
	if (module_loaded($m)) {
		carp "Module $m already loaded";
		return 0;
	}
	my $code;
	my @path = ("/.anna/modules/", "/.anna/modules/core/", "/.anna/modules/auto/");
	foreach my $p (@path) {
		if (-f $ENV{'HOME'}.$p.$m.".pl") {
			open(MODULE, "<", $ENV{'HOME'}.$p.$m.".pl") or croak $!;
			while (<MODULE>) {
				$code .= $_;
			}
			close(MODULE) or croak $!;
			last;
		}
	}
	unless ($code) {
		carp "Can't find $m";
		return 0;
	}
	eval "package Anna::Module::$m; $code";
	if ($@) {
		carp "Failed to load $m: $@";
		# XXX cleanup possible cruft from database
		return 0;
	}
	package Anna::Module;
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

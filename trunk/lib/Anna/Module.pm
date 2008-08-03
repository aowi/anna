package Anna::Module;
use strict;
use warnings;

use Exporter;
our @EXPORT_OK = qw();
our @EXPORT = qw(IRC CHAN NICK HOST TYPE MOD ARG);
our @ISA = qw(Exporter);

use Anna::DB;
use Anna::Config;
use Anna::Utils;
use Carp;
use Symbol qw(delete_package);

# var: %modules
# Global, that holds the name of all modules with registered events. Don't
# mess with this outside Anna::Module!
our %modules;

# ugly, dirty and alltogether bad.
# These subs are exported per default and used as constant expressions by 
# modules, to avoid having to keep track of argument order, and to allow us to
# reorder or add more args later, without breaking existing modules.
# Idea stolen from POE, btw :)
sub IRC  () {  0 } # irc-object
sub CHAN () {  1 } # channel the message is from
sub NICK () {  2 } # nick of the sender
sub HOST () {  3 } # host of the sender
sub TYPE () {  4 } # type of message/event (privmsg, public, join, part, ...)
sub MOD  () {  5 } # module-object
sub ARG  () {  6 } # any arguments exactly as they were typed (no processing is done)

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
	my $db = new Anna::DB $name;
	my $module = {
		name 	=> $name,
		db		=> $db,
	};
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

# Func: msg_exists_in_db
# Checks if a msg already exists in the modules-table
#
# Parameters:
#    msg - msg to scan for
#
# Returns:
#    0 if the command doesn't exists, 1 if it's there
sub msg_exists_in_db {
	unless (@_ >= 1) {
		carp "msg_exists_in_db takes one parameter";
		return 0;
	}
	my $msg = shift;
	if (ref $msg) {
		my $pkg = $msg;
		$msg = shift;
	}
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return 0;
	}
	my $sth = $dbh->prepare(qq{
		SELECT value FROM modules WHERE type = 'msg' AND value = ?
	});
	$sth->execute($msg);
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

# sub: bindmsg
# Used as a method to bind a privmsg to a subroutine
# Anna^ will not trigger this on messages sent to public channels. Only 
# messages that are sent directly to Anna^
#
# Parameters:
# 	msg - the msg to listen for
# 	sub - the sub to call when cmd is found
#
# Returns:
# 	The object (caller)
sub bindmsg {
	unless (@_ == 3) {
		carp "bindmsg takes two parameters: command and sub";
		return $_[0];
	}
	my $pkg = shift;
	my ($msg, $sub) = @_;
	my $mod = $pkg->{'name'};
	if (msg_exists_in_db($msg)) {
		carp "Failed to bind msg $msg: Already existing";
		return $pkg;
	}
	debug_print(sprintf("Binding privmsg %s to %s::%s", $msg, $mod, $sub));
	my $dbh = new Anna::DB or return $pkg;
	my $rv = $dbh->do(
		"INSERT INTO modules (name, type, value, sub) 
		VALUES (?, 'msg', ?, ?)", 
		undef, ($mod, $msg, $sub));
	unless (defined $rv) {
		carp "Failed to add msg $msg to DB: $DBI::errstr";
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
	if ($type eq 'msg') {
		debug_print "Recieved a PRIVMSG from [$nick]";
		# MSG
		# if the message matched something hooked with bindmsg, return. 
		# Otherwise, assume it was a standard command
		# XXX: REWRITE THIS SHIT! What about bound regexps? other stuff?
		# I need something more general.
		if (do_msg($msg, $heap, $channel, $nick, $host, $type)) {
			return 1;
		} else {
			if ($msg =~ /^(\Q$trigger\E|\Q$botnick\E[ :,-]+)/) {
				$msg =~ s/^(\Q$trigger\E|\Q$botnick\E[ :,-]+\s*)//;
			}
			do_cmd($msg, $heap, $channel, $nick, $host, $type);
			return 1;
		}
		
	}

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

# sub: loaddir
# Scan a directory for anna-modules (or rather, .pl-files) and load them.
#
# Params:
# 	dir - the (full) path to the directory to search
#
# Returns:
# 	nothing
sub loaddir {
	my $dir = shift;
	unless (-d $dir) {
		debug_print(sprintf("%s does not exist or is not a directory - skipped!", $dir));
		return;
	}
	opendir(DIR, $dir) or confess $!;
	while (defined(my $file = readdir(DIR))) {
		if ($file =~ m/[.]pl$/) {
			my $m = $file;
			$m =~ s/[.]pl$//;
			loadfullpath($dir."/".$file, $m);
		}
	}
	closedir(DIR) or croak $!;
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

# sub: do_msg
# Handles privmsg-checking and execution, if a msg-trigger is found.
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
sub do_msg {
	my ($cmd, $heap, $channel, $nick, $host, $type) = @_;
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Failed to obtain DB handle: $DBI::errstr";
		return 1;
	}
	my ($c, $m) = split(' ', $cmd, 2);
	my $sth = $dbh->prepare(qq{
		SELECT * FROM modules WHERE type = 'msg' AND value = ?
	});
	$sth->execute($c);
	my ($name, $sub);
	if (my $row = $sth->fetchrow_hashref) {
		$name = $row->{'name'};
		$sub = $row->{'sub'};
	} else {
		return 0;
	}
	debug_print(sprintf("Calling %s", $sub));	
	my $s = \&{ "Anna::Module::".$name."::".$sub };
	eval '$s->($heap->{irc}, $channel, $nick, $host, $type, $modules{$name}, $m)';
	confess $@ if $@;

	return 1;
}

# sub: load
# Takes a module-name or a filename and scans for a module with that name in Anna's 
# module-directories. If a module is found, call loadfullpath on it
#
# Parameters:
# 	m - module name or filename
# 
# Returns:
# 	1 on successful loading, 0 on failure
sub load {
	unless (@_ >= 1) {
		carp "load takes one parameter";
		return 0;
	}
	my $m = shift;
		
	$m =~ s/[.]pl$//;

	my @path = (
		Anna::Utils->CONFIGDIR."/modules/", 
		Anna::Utils->CONFIGDIR."/modules/core/", 
		Anna::Utils->CONFIGDIR."/modules/auto/",
		"/usr/share/anna/modules/", 
		"/usr/share/anna/modules/core/", 
		"/usr/share/anna/modules/auto/"
	);
	
	my ($found, $ret) = 0;
	foreach my $p (@path) {
		if (-f $p.$m.".pl") {
			$ret = loadfullpath($p.$m.".pl", $m); 
			$found = 1;
			last;
		}
	}
	if ($found) {
		return $ret;
	} else {
		warn_print(sprintf("Module %s not found", $m));
		return 0;
	}
}

sub loadfullpath {
	my ($path, $m) = @_;
	
	if (module_loaded($m)) {
		carp "Module $m already loaded";
		return 0;
	}

	verbose_print(sprintf("Loading module %s", $m));

	eval qq{
		package Anna::Module::$m; 
		require qq|$path|;
		&init if (defined &init);
	};
	if ($@) {
		carp "Failed to load $m: $@";
		unload $m; # Cleanup cruft
		return 0;
	}
	package Anna::Module;
	return 1;
}

# sub: unload
# Unloads a module. Cleans database and scrubs package namespace (with delete_package from Symbol)
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
	verbose_print(sprintf("Unloading module %s", $m));
	delete_package('Anna::Module::'.$m);
	delete $modules{$m};
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

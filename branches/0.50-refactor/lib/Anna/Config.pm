package Anna::Config;
use strict;
use warnings;

our @EXPORT = qw();
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Carp;
use Data::Dumper;
use Anna::Utils;
use Anna::DB;

# Func: new
# Generate a new configuration-object
#
# Parameters: 
#   none
#
# Returns:
#   A blessed reference to a hash (that is, a config-object)
sub new {
	my $class = shift;
	croak "$class requires an even number of parameters" if @_ & 1;

	# Get parameters from caller
	my %params = @_;
	foreach (keys %params) {
		$params{ lc($_) } = delete $params{$_};
	}

	# Create an empty config-hash
	my $conf = {
		server		=> undef,
		port		=> undef,
		nick		=> undef,
		username	=> undef,
		channel		=> undef,
		name		=> undef,
		nspasswd	=> undef,
		dbfile		=> undef,
		colour		=> undef,
		silent		=> undef,
		verbose		=> undef,
		log		=> undef,
		trigger		=> undef,
		bannedwords	=> [],
		voice_auth	=> undef
	};
 
	# Fill config with entries from database
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return undef;
	}
	carp "Unable to get database handle" unless ($dbh);
	my $sth = $dbh->prepare("SELECT key, value FROM config");
	$sth->execute;
	while(my $rv = $sth->fetchrow_hashref) {
		$$conf{$rv->{'key'}} = $rv->{'value'}
	}

	# Fill it with caller's params
	foreach (keys %$conf) {
		update_db($_, $params{$_}) if defined $params{$_};
		$conf->{$_} = $params{$_} if defined $params{$_};
	}

	return bless $conf, $class;
}

# Func: empty_db
# Empty the configuration database. This should only be run on startup, to clean cruft.
#
# Parameters: 
#   none
#
# Returns: 
#   1 on success, 0 on failure
sub empty_db {
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return 0;
	}
	$dbh->do("DELETE FROM config");
	return 1;
}

# Func: exists
# Checks if a configuration key have been set (exists in the configuration table)
# 
# Must be called through a config-object.
#
# Parameters:
#   k - the key to search for
#
# Returns:
#   1 if the key exists, 0 if it doesn't
sub exists {
	my (undef, $k) = @_;
	unless (defined $k) {
		carp "exists called without key";
		return 0;
	}
	return key_exists_in_db($k);
}

# Func: key_exists_in_db
# Private pendant to <exists>. Does the real checking but can't be called from a 
# config-object. 
#
# Only used internally.
#
# Parameters:
#   k - the key to search for 
#
# Returns:
#   1 if the key exists, 0 otherwise
sub key_exists_in_db {
	my $k = shift;
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return undef;
	}
	my $sth = $dbh->prepare("SELECT key FROM config WHERE key = ?");
	$sth->execute($k);
	$sth->fetchrow ? return 1 : return 0;
}

# sub: update_db
# Updates database with changes configuration values. Only used internally.
# 
# Use <set> for normal operation
#
# Parameters:
#   k - the key to update
#   v - the new value for the key
#
# Returns:
#   >1 on success, undef on errors (along with a carp'd errmsg)
sub update_db {
	my ($k, $v) = @_;
	unless (defined $k && defined $v) {
		carp "tried to update config table with undefined key or value";
		return undef;
	}

	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return undef;
	}
	my $query = "INSERT INTO config (value, key) VALUES(?, ?)";
	if (key_exists_in_db($k)) { 
		$query = "UPDATE config SET value = ? WHERE key = ?";
	}
	$dbh->do($query, undef, ($v, $k)) or croak $DBI::errstr;
}

# sub: parse_configfile
# Parses a configuration file and updates config-table with new keys and values.
# 
# Called from a config-object only!
#
# Parameters:
#   cfile - path to the configuration file (absolute, please)
#
# Returns: 
#   the updated config-object  
sub parse_configfile {
	my ($self, $cfile) = @_;
	unless (defined $cfile) {
		carp "Missing parameter in parse_configfile" 
			unless defined $cfile;
		return $self;
	}
	unless (-r $cfile) {
		carp "$cfile does not exist or is not readable";
		return $self;
	}
	open(CFG, "<".$cfile) or 
		croak("Can't open configuration file ".$cfile.": ".$!);
	while(<CFG>) {
		next if (/^#/ || /^\[/ || /^$/);
		if (/^(.*?)\s*=\s*(.*)$/) {
			# Server part
			$self->set('server', $2) if (lc($1) eq 'server');
			$self->set('port', $2) if (lc($1) eq 'port');
			$self->set('nick', $2) if (lc($1) eq 'nickname');
			$self->set('username', $2) if (lc($1) eq 'username');
			$self->set('channel', $2) if (lc($1) eq 'channel');
			$self->set('name', $2) if (lc($1) eq 'ircname');
			$self->set('nspasswd', $2) if (lc($1) eq 'nspasswd');
			# Script part
			$self->set('dbfile', $2) if (lc($1) eq 'dbfile');
			$self->set('colour', $2) if (lc($1) eq 'colour');
			$self->set('silent', $2) if (lc($1) eq 'silent');
			$self->set('verbose', $2) if (lc($1) eq 'verbose');
			$self->set('log', $2) if (lc($1) eq 'logging');
			# Bot part
			$self->set('trigger', $2) if (lc($1) eq 'trigger');
			if (lc($1) eq 'bannedwords') {
				foreach (split ' ', $2) {
					push @{$self->{'bannedwords'}}, $_;
				}
			}
			$self->set('voice_auth', $2) if (lc($1) eq 'voice_auth');
#                       $require_ops = $2 if (lc($1) eq 'require op');
#                       $require_voice = $2 if (lc($1) eq 'require voice');
		} else {
			carp "Syntax error in configuration file (".$cfile.") line ".$. 
				unless ($self->get('silent'));
		}
	}
	close(CFG);
	return $self;
}

# sub: set
# Sets a given key to a given value
# 
# Must be called from a config-object
#
# Parameters:
#   k - the key to set/update
#   v - the new value of the key
#
# Returns:
#   undef on failure, 1 on success
sub set {
	my $self = shift;
	my ($k, $v) = @_;
	unless (defined $k && defined $v) {
		carp "set require two parameters";
		return undef;
	}

	update_db($k, $v);
	$self->{$k} = $v;
	return 1;
}

# sub: get
# Get the value of a key.
# 
# Must be called from a config-object
#
# Parameters:
#   k - the key whose value you want
#
# Returns:
#   undef on failure, the value on success
sub get {
	my ($self, $k) = @_;

	unless (defined $k) {
		carp "get requires one parameter";
		return undef;
	}
	
	return $self->{$k} if defined $self->{$k};
	undef;
}

# sub: toggle
# Toggles a boolean value (set it to zero if it's one and vice-versa)
# 
# Must be called from a config-object
#
# Parameters:
#   k - the key which must point to a boolean value
#
# Returns:
#   1 on success, 0 on failure
sub toggle {
	my ($self, $k) = @_;
	
	unless (defined $k) {
		carp "toggle requires one parameter";
		return 0;
	}

	if (defined $self->get($k) && $self->get($k) != 1 && $self->get($k) != 0) {
		carp "tried to toggle non-boolean key $k (value: ".$self->get($k).")";
		return 0;
	}

	$self->get($k) ? $self->set($k, 0) : $self->set($k, 1);

	return 1;
}

# sub: delete
# Deletes a key from object and database, if it exists.
# 
# Keep in mind, that other config-objects floating around might still have the key/value.
# 
# Must be called from a config-object
#
# Parameters:
#   k - the key to delete
#
# Returns:
#   0 on failure, the old (now deleted) value of the key on success
sub delete {
	my ($self, $k) = @_;
	
	unless (defined $k) {
		carp "delete requires one parameter";
		return 0;
	}
	
	unless (defined $self->get($k)) {
		# Key didn't exist
		carp "Attempted to delete nonexisting key $k";
		return 0;
	}
	my $dbh = new Anna::DB;
	$dbh->do("DELETE FROM config WHERE key = ?", undef, ($k));
	my $v = $self->{$k};
	delete $self->{$k};
	return $v;
}

1;

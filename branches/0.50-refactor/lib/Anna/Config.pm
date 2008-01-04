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

## new
# Params: configuration options
# Return a blessed reference to a configuration hash based on the SQLite table
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

sub empty_db {
	my $dbh = new Anna::DB;
	unless ($dbh) {
		carp "Couldn't get database-handle: $DBI::errstr";
		return undef;
	}
	$dbh->do("DELETE FROM config");
}

sub exists {
	my (undef, $k) = @_;
	unless (defined $k) {
		carp "exists called without key";
		return 0;
	}
	return key_exists_in_db($k);
}

# Only for internal use
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

## parse_configfile
# Params: path to configfile
# Return a reference to an object, holding the configuration details.
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

## set
# Params: key, value
# Sets a given key to a given value.
# Returns the value
sub set {
	my $self = shift;
	my ($k, $v) = @_;
	unless (defined $k && defined $v) {
		carp "set require two parameters";
		return undef;
	}

	update_db($k, $v);
	$self->{$k} = $v;
}

## get
# Params: key
# Returns the current value for the given key, undef if key wasn't found
sub get {
	my ($self, $k) = @_;

	unless (defined $k) {
		carp "get requires one parameter";
		return undef;
	}
	
	return $self->{$k} if defined $self->{$k};
	undef;
}

## toggle
# Params: key
# Toggles the value of the given key (to false of true, and otherwise)
# Be careful as this could potentially lead to loss of information, if a string
# or like is 'toggled'. We will print a warning unless 
# Returns true if key was toggled, false if it couldn't be.
sub toggle {
	my ($self, $k) = @_;
	
	unless (defined $k) {
		carp "toggle requires one parameter";
		return undef;
	}

	if (defined $self->get($k) && length($self->get($k)) > 1) {
		carp "tried to toggle non-boolean key $k (value: ".$self->get($k).")";
		return 0;
	}

	$self->get($k) ? $self->set($k, 0) : $self->set($k, 1);

	return 1;
}

## sub delete
# Params: key
# Calls delete on the key, if it's defined
# Returns the deleted value if key was found, false otherwise.
sub delete {
	my ($self, $k) = @_;
	
	unless (defined $k) {
		carp "delete requires one parameter";
		return undef;
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

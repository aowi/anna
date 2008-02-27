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

my %config = ();

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
	croak "$class->new doesn't take any parameters" if @_;
	my $i = 1;
	return bless \$i, $class;
}

# sub: dump
# Dumps the current configuration hash on stdout. Use for debugging
# 
# Params:
# 	none
#
# Returns:
# 	1
sub dump {
	print Dumper(%config);
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
	return exists $config{$_[1]};
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
				$config{'bannedwords'} = [] 
					unless exists $config{'bannedwords'};
				foreach (split ' ', $2) {
					push @{$config{'bannedwords'}}, $_;
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

	$config{$k} = $v;
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
	
	return $config{$k} if defined $config{$k};
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
	my $v = $config{$k};
	delete $config{$k};
	return $v;
}

1;

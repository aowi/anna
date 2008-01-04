package Anna::Log;

use strict;
use warnings;

# Multipurpose log-system for Anna.

our @EXPORT = qw();
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Carp;
use Anna::Utils;

## new
# Takes a couple of configurations as params. Returns a log-object
sub new {
	my $class = shift;
	croak "$class requires an even number of parameters" if @_ & 1;

	# Get parameters from caller
	my %params = @_;
	$params{ lc($_) } = delete $params{$_} foreach (keys %params);
	
	croak "A new log-object requires a reference to the heap" unless defined $params{'heap'};
	croak "A new log-object requires a 'format' key" unless defined $params{'format'};
	croak "Format of log must be either 'service' or 'msg'" 
		unless ($params{'format'} =~ /^(service|msg)$/i);
	if (lc($params{'format'}) eq 'service') {
		# Require service-name
		croak "Format 'service' requires 'name'" unless defined $params{'name'};
	} else {
		# msg, require network & target
		croak "Format 'msg' requires 'network' and 'target'"
			unless (defined $params{'network'} && defined $params{'target'});
	}

	my $log = { 
		format => lc($params{'format'}),
	};

	if (lc($params{'format'}) eq 'service') {
		$$log{'name'} = lc($params{'name'});
	} else {
		# msg
		$$log{'network'} = lc($params{'network'});
		$$log{'target'} = lc($params{'target'});
	}
	$$log{heap} = $params{'heap'};

	return bless $log, $class;
}

## write
# Takes one param, the message to write to a logfile.
# Writes the message and returns 1 on succes, 0 on failure
sub write {
	my ($self, $message) = @_;
	unless (defined $message) {
		carp "$self->write called without a message!";
		return 0;
	}
	return 1 unless $self->{heap}->{config}->get('log');
	# TODO: make this configurable
	my $logdir = $ENV{'HOME'}."/.anna/logs";

        if (!(-e $logdir)) {
		mkdir $logdir or croak "Can't create log-directory: $!";
	}

	my $file;
	if ($self->{'format'} eq 'msg') {
		$file = $self->{'network'}."/".$self->{'target'};
		unless (-d $logdir."/".lc($self->{'network'})) {
			mkdir $logdir."/".lc($self->{'network'}) 
				or croak "Can't create log-directory: $!";
		}
	} elsif ($self->{'format'} eq 'service') {
		$file = "services/".lc($self->{'name'});
		unless (-d $logdir."/services") {
			mkdir $logdir."/services" or croak "Can't create log-directory: $!";
		}
	} else {
		carp "$self->write called, but $self doesn't define a format... this is a bug!!";
		return 0;
	}

	open(LOG, ">> ", $logdir."/".$file) or croak "Can't open file for appending: $!";
	printf LOG "%s %s\n", print_time(), $message or croak "Couldn't write to logfile: $!";
	close(LOG) or croak "Couldn't close logfile: $!";

	return 1;
}



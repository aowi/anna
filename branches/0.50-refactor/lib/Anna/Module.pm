package Anna::Module;
use strict;
use warnings;
use Anna::DB;
use Carp;

my $current_module;

# Removes all added user commands from db
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

sub execute {
	return 1 unless (@_ == 5);
	my ($cmd, $heap, $channel, $nick, $host) = @_;
	
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
		&$sub($m, $heap->{irc}, $channel, $nick, $host);
	};
	print $@."\n" if (defined $@);
	use strict 'refs';

	return 1;
}

# Takes modulename or filename, loads module (evals it)
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
		return 0;
	}
	return 1;
}

# Takes modulename, removes traces of it
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

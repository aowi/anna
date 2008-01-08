package Anna::DB;
use strict;
use warnings;

our @EXPORT = qw();
our @EXPORT_OK = qw();
use Exporter;
our @ISA = qw(Exporter);

use Anna::Utils;
use Anna::Config;
use DBI;
use DBD::SQLite;
use Carp;

# sub: new
# Instance-method that return a plain database-handle
#
# Parameters:
#   class - the callers class
#
# Returns:
#   DB-handle (DBI, DBD::SQLite)
sub new {
	my $class = shift;
	my $file = Anna::Utils->DB_LOCATION;
	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=".$file,
		undef,
		undef,
		{
			PrintError      => 1,
			PrintWarn       => 1,
			RaiseError      => 1,
			AutoCommit      => 1
		}
	) or carp("Can't connect to SQLite database ".$file.": $DBI::errstr");

	return $dbh;
}

# sub: sync
# Synchronizes an older version of Anna's database to the current version.
#
# Params:
#   dbh - database-handle, as returned from <new>
#
# Returns:
#   1 (craps out if there are any errors)
sub sync {
	my $dbh = shift;
	unless (defined $dbh) {
		carp "sync called without a database handle";
		return;
	}
	my $config = new Anna::Config;

	# Check database version. sqlite_master contains a list of all tables.
	my $query = "SELECT * FROM sqlite_master WHERE type = ? AND name = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute("table", "admin");
	my $dbfile = Anna::Utils->DB_LOCATION;
	if ($sth->fetchrow()) {
		# Okay, admin table exists, fetch database version
		$query = "SELECT * FROM admin WHERE option = 'db_version'";
		$sth = $dbh->prepare($query);
		$sth->execute();
		my @row = $sth->fetchrow();
		return 1 if ($row[1] == Anna::Utils->DB_VERSION);
		if ($row[1] eq "1") {
			# Upgrades from 1->DB_VERSION
			printf "Upgrading database from version 1 to %s\n", 
				Anna::Utils->DB_VERSION if $config->get('verbose');
			copy($dbfile, $dbfile."_bak") 
				or die("Failed during backup of database: $!");
			$query = "ALTER TABLE users ADD COLUMN op INT";
			$sth = $dbh->prepare($query);
			$sth->execute();
			$query = "ALTER TABLE users ADD COLUMN admin INT";
			$sth = $dbh->prepare($query);
			$sth->execute();
			create_rootuser();
			$query = "UPDATE admin SET value = ? WHERE option = ?";
			$sth = $dbh->prepare($query);
			$sth->execute('2', 'db_version');
			# Upgrade succeded, delete backup
			unlink($dbfile."_bak") 
				or warn("Failed to unlink database backup: $!");
		}
	} else {
		# System is too old... we only support 0.2x, so update from 
		# that (version 0 -> 2)
		printf "Your database is out of date. Performing updates... \n" 
			if $config->get('verbose');
		# Make a backup copy
		copy($dbfile, $dbfile."_bak") 
			or die("Failed during backup of database: $!");
		# TODO: Inform user of backup copy in case of failure and 
		# delete it in case of success

		# Create admin table
		$query = q{
			CREATE TABLE admin (
				option VARCHAR(255), 
				value VARCHAR(255)
			)
		};
		$sth = $dbh->prepare($query);
		$sth->execute();

		# Create notes table
		$query = q{
			CREATE TABLE notes (
				id INTEGER PRIMARY KEY UNIQUE, 
				word TEXT, 
				answer TEXT, 
				author TEXT, 
				date INTEGER
			)
		};
		$sth = $dbh->prepare($query);
		$sth->execute();

		# Create orders table
		$query = q{
			CREATE TABLE orders (
				id INTEGER PRIMARY KEY UNIQUE, 
				key TEXT, 
				baka_order TEXT
			)
		};
		$sth = $dbh->prepare($query);
		$sth->execute();
		
		my @order_keys = ("coffee", "chimay", "pepsi", "ice cream", 
				  "beer", "peanuts", "ice");
		my @order_values = (
			"hands ## a steaming cup of coffee",
			"hands ## a glass of Chimay",
			"gives ## a can of Star Wars pepsi",
			"gives ## a chocolate ice cream with lots of cherries",
			"slides a beer down the bar counter to ##",
			"slides the bowl of peanuts down the bar counter to ##",
			"slips two ice cubes down ##'s neck",
		);
		$query = "INSERT INTO orders (key, baka_order) VALUES (?, ?)";
		$sth = $dbh->prepare($query);
		# FIXME: We ought to check the tuples... oh well
		$sth->execute_array({ ArrayTupleStatus => undef}, 
			\@order_keys, \@order_values);

		# Create roulette_stats
		$query = q{
			CREATE TABLE roulette_stats (
				id INTEGER PRIMARY KEY UNIQUE, 
				user TEXT UNIQUE, 
				shots INTEGER, 
				hits INTEGER, 
				deathrate TEXT, 
				liverate TEXT
			)
		};
		$sth = $dbh->prepare($query);
		$sth->execute();
		
		# Add op & admin columns to users table
		$query = "ALTER TABLE users ADD COLUMN op INT";
		$sth = $dbh->prepare($query);
		$sth->execute();
		$query = "ALTER TABLE users ADD COLUMN admin INT";
		$sth = $dbh->prepare($query);
		$sth->execute();
		create_rootuser();
		# Update db_version field
		$query = "INSERT INTO admin (option, value) VALUES (?, ?)";
		$sth = $dbh->prepare($query);
		$sth->execute("db_version", 2);
		# Upgrade succeded, delete backup
		unlink($dbfile."_bak") or carp "Failed to unlink database backup: $!";
		printf "Your database is up to speed again!\n" 
			if ($config->get('verbose'));
	}
}

# sub: DESTROY
# Disconnects a database-handle when it goes out of scope.
#
# Technically unneeded
#
# Params:
#   dbh - database-handle
#
# Returns:
#   1
sub DESTROY {
	my $dbh = shift;
	$dbh->disconnect or carp "Couldn't disconnect from database" ;
}
1;

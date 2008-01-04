#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use Data::Dumper;

use Anna::Config;
use Anna::Utils;
my $c = Anna::Config->new(
		server	=> "irc.blitzed.org",
		nick	=> "Anna^",
		port	=> 6667
	);
#print Dumper($c);
$c->parse_configfile("/home/arkanoid/.anna/config");
$c->set('colour', 1);

my $n = "Anna^";
if ($n =~ /^\Q@{[$c->get('nick')]}\E$/x) {
	printf "Hooray!\n";
}
printf "%s\t%s\n", $n, $c->get('nick');
print error("Yaddaerror\n", $c);
print warning("Warningse\n", $c);
print colour("Coloured\n", '34', $c);
$c->set('colour', 0);
print error("Noncoloured\n", $c);
$c->set('colour', 1);

print trim("   Ecksil   ")."\n";
print rtrim("   Ecksil   ")."\n";
print ltrim("   Ecksil   ")."\n";
ltrim();
print "[".print_time()."]\n";
print calc_diff(time())." ago\n";
print calc_diff(time()-86400)." ago\n";
print calc_diff(time()-2341)." ago\n";
#usage(0);
version();

sub foo {
	my ($a, $b) = @_;
	print scalar @_;
}
foo(1,2);
foo(1,undef,3);

use Anna::Log;

my $slog = new Anna::Log(
	format	=> 'service',
	name	=> 'kernel'
);
print Dumper($slog);
my $mlog = new Anna::Log(
	format	=> 'msg',
	network	=> 'rizon',
	target	=> '#frokostgruppen'
);

$slog->write("This is a test");
$mlog->write("<arkanoid> This is also a test");
print  Dumper($mlog);
#my $faillog = new Anna::Log(
#	format => 'SeRvIcE',
#	baka => 'yadda'
#);

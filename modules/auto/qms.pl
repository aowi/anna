use strict;
use warnings;

use Anna::Module;
use Anna::Utils qw(trim);
use HTML::Entities;
use LWP::UserAgent;

sub getquote {
	my ($url, $nr) = @_;

	my $ua = new LWP::UserAgent;
	$ua->agent("Mozilla/5.0" . $ua->agent);
	my $request;
	if (!$nr) {
		$request = new HTTP::Request GET => $url."?random";
	} else {
		$request = new HTTP::Request GET => $url."?".$nr;
	}
	my $get = $ua->request($request);
	my $content = $get->content;
	$content =~ s/\n//g;
	# Find the quote. If this function stops working, the problem 
	# lies here.
	$content =~ /(\<p class\=\"qt\"\>|\<div class\=\"quote_output\"\>)(.*?)(\<\/p\>|\<\/div\>)/;
	if (!$2) {
		return "No quote found. Please check the number";
	}
	my @lines = split(/<br \/>.{1}/, $2);

	my $quote = "";
	foreach (@lines){
		$_ = trim(decode_entities($_));
		$quote .= $_."\n";
	}
	return $quote;
}

sub bash {
	my ($target, $arg, $irc) = @_[CHAN, ARG, IRC];
	$arg ||= "";
	my @quote = split('\n',getquote('http://bash.org/', $arg));

	for (@quote) {
		$irc->yield(privmsg => $target => $_);
	}
}
sub limerick {
	my ($target, $arg, $irc) = @_[CHAN, ARG, IRC];
	$arg ||= "";
	my @quote = split('\n',getquote('http://limerickdb.com/', $arg));

	for (@quote) {
		$irc->yield(privmsg => $target => $_);
	}
}

my $m = Anna::Module->new('qms');
$m->bindcmd('limerick', 'limerick')->bindcmd('bash', 'bash');

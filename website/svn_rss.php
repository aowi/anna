<?
$fh = fopen('http://cia.navi.cx/stats/project/anna/.rss', 'r') or die("Failed...");
$rss_content = "";
while (!feof($fh)) {
	$rss_content .= fgets($fh, 4096);
}
print $rss_content;

?>
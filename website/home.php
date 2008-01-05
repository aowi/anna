<div class='main_box'>
	<div class='main_box_head'><span class='main_head'>Welcome</span></div>
	<div class='main_box_content'>
		<p>Anna^ IRC Bot is a small bot written in perl with a multitude of features, ranging from basic storage of notes to interaction with external web services such as google and <a href='http://bash.org'>bash.org</a>. Originally based on some scripts for the <a href='http://irssi.org'>irssi irc client</a>, Anna^ has grown into a full-fledged irc bot capable of many things. Through the POE framework for perl, Anna^ delivers quick responses to queries and handles most of the IRC protocol at the moment. And the rest is coming soon. Being launched in august 2006, the project is still young and is currently maintained by two persons. But Anna^ is growing fast in regards to features and possibilities.</p>
	<p>The current version of Anna^ is the 0.40 "lacuna" release. This release featured a new session system, automatic logging, a reqrite to POE and a lot of bug fixes and added stability. You can grab the latest release at <a href='http://sourceforge.net/project/showfiles.php?group_id=180743'>the SF.net download page</a>. Don't forget to submit bugs and wishes to us!</p>
	</div>
	<div class='main_box_head'><span class='main_head'>Latest news</span></div>
	<div class='main_box_content'>
	<h2>Anna^ IRC Bot 0.40 - lacuna</h2>
	<p>This one took a long time - way too long time. But finally here, after the shortest test period so far. 0.40, aka. lacuna features a session system, that allows you to authenticate yourself to Anna^, who in turn keeps track of a list of channel operators. The session system is slated for lots of improvements during 0.50 development. Besides the sessions, this marks the first release with POE - the Perl Object Environment (as some call it). POE allows for greater flexibility and is easier to maintain - two things that will be needed for 0.50, where Anna^ will be fully modularized. The documentation has been updated to include all functionality, and this release also include detailed installation and setup instructions. Automatic logging has been added to lacuna as well as load of minor and major bugfixes.</p>
	<p>We will attempt to release bugfix-versions this time - something that unfortunately weren't done with 0.40 because some bugfixes couldn't easily be backported to the old codebase. See the changelog for more details on this release.<br />For now, enjoy Anna^!</p>
	<h2>Anna^ IRC Bot 0.30 - caprice</h2>
	<p>The dust have settled for a while, and before we pick up the work again, we have decided to release the current svn snapshot as version 0.30, codenamed "caprice". Thus, after a lot of tests and checks, you may now enjoy a new version of Anna^ with more features and (hopefully) less bugs.<br />Some effort has been put into making it easier to install, upgrade and keep Anna^ in a consistent state. A makefile has been added, so all you need to do to install Anna^ it typing su -c "make install" (or sudo make install, if you're one of those). This will put the files where they belong.<br />Since the last release one and a half month ago, we have moved development from our own rusty, old server to sourceforge. While we will continue to use the server for testing purposes (and the website, once it's up and running) all development will be taken care of on sourceforge.net.</p>
	<p>Highlights from the changelog includes:</p>
	<ul>
		<li>Anna^ now recovers her nick correctly. Rejoice! (Bug since 0.10).</li>
		<li>Experimental color-coding of terminal output.</li>
		<li>Quoting of messages in lastseen-system fixed.</li>
		<li>Anna^ now checks for the presence of /etc/anna.conf and ~/.anna/config and uses those two instead of default values.</li>
		<li>Notices are now printed on stdout, unless the --silent flag is used.</li>
	</ul>
	<p>New features include:</p>
	<ul>
		<li>Note - yep, a note-taking system (somewhat).</li>
		<li>Mynotes - show all notes belonging to yourself.</li>
		<li>Rot13 - translate rot13-strings (or encrypt string in rot13).</li>
		<li>Search - use !search to search various tables in Anna^'s database.</li>
		<li>!addorder - add a new order to the database.</li>
		<li>!rstats - print statistical information from roulette games.</li>
	</ul>
	<p>For now, we'll concentrate on 0.40, as well as some initial work for 0.50, where a cli is planned, among other things. 0.40, will feature a rewrite of Anna^ to make use of the POE-framework for perl.<br />Enjoy caprice, and remember: any comments, suggestions, nude pics (girls only!) and general bitching should be directed to <a href='mailto:and@vmn.dk'>and@vmn.dk</a>, <a href='http://ossowicki.com'>http://ossowicki.com</a>, <a href='http://sf.net/projects/anna'>http://sf.net/projects/anna</a> or /dev/null.</p>
	</div>
</div>

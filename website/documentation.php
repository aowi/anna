<div class='main_box'>
	<div class='main_box_head'><span class='main_head'>Documentation</span></div>
	<div class='main_box_content'>
		<p>The documentation included here, qualifies for Anna^ version 0.4. Some of it applies to older version as well, but don't expect it. You can grab the latest svn snapshot from the <a href='http://sf.net/projects/anna'>SF.net project site</a>. If you like, please feel free to submit more documentation as this is in no way enough.</p>
	</div><br />
	<div class='main_box_head'><span class='main_head'>HELP</div>
	<div class='main_box_content'>
	<p>Table of contents:
	<ul>
		<li>1) Anna^ IRC Bot</li>
		<ul>
			<li>1.1) What Anna^ is</li>
			<li>1.2) What Anna^ isn't</li>
		</ul>
		<li>2) Installation</li>
		<li>3) Configuration</li>
		<li>4) First run</li>
		<li>5) In-IRC setup</li>
		<li>6) Features</li>
		<ul>
			<li>6.1) Standard features</li>
			<li>6.2) Private features</li>
			<li>6.3) Sessions</li>
			<li>6.4) Misc. features and concepts</li>
		</ul>
	</ul>
	<hr />
	<p><b>1) Anna^ IRC Bot</b></p>
	<p><i>1.1) What Anna^ is</i></p>
	<p>Anna^ is a small, versatile IRC-bot written in perl. She uses POE and the 
	POE::Component::IRC interface to communicate with an IRC-server and act as a 
	bot. Anna^ can connect to one server and handle one channel at the moment (this
	is due to change as development charges onwards). Besides, Anna^ can handle 
	messages sent directly to her. Anna^ has a multitude of functions, and is quite
	easy to extend. In the near future, it will be possible to write external 
	modules, rather than changing the script to add functionality. See section 6 
	for more on Anna^'s feature-set. Anna^ aims to be easy to get up and running, 
	with some functionality, rather than require a lot of configuration beforehand.</p>

	<p><i>1.2) What Anna^ isn't</i></p>
	<p>Anna^ is not an IRC-server, nor is she a DCC fserve, an XDCC-bot or the like
	(although it's quite possible to extend Anna^ to serve as a fserve or XDCC-bot)
	Anna^ is not well-suited as a spambot, mainly due to the built-in throttling of
	POE::Component::IRC.
	Anna^ is not yet fully developed, nor is she anywhere near that state.</p>

	<p><b>2) Installation</b></p>
	<p>Installation instructions along with requirements can be found in the INSTALL 
	document. Per default, Anna^ will install herself in /usr/local/bin, and she 
	will install files in /etc and /usr/local/share/anna/. On first-run, Anna^ will
	create a directory in the users homedir called .anna, where the database, local
	configuration and logfiles will be stored. If you have several bots running and
	don't want to use the same database for each bot, you can specify a path to the
	database in the configuration file or from the command-line.</p>

	<p><b>3) Configuration</b></p>
	<p>Once Anna^ is installed, a configuration file, /etc/anna.conf is available.
	You can either edit this, or use the local configuration file ~/.anna/config 
	(created on first-run). The configuration files follow a simple associative 
	"key = value"-syntax where everything to the right of the equal-sign (except 
	for whitespace) is treated as the value of the key. The keys (not the values)
	are case-insensitive. Lines beginning with # or [ (section dividers) are 
	treated as comments. Empty lines doesn't matter.</p>

	<p>The following keys are currently understood: <br />
	&lt;int&gt; = integer, &lt;str&gt; = string, &lt;bool&gt; = 1 (true) or 0 (false)<br />

	<p>
	server = &lt;str&gt;:<br />
	the URL of the irc-server Anna^ should connect to (without irc://)<br />
	port = &lt;int&gt;:<br />
	the server-port to use. Default is 6667<br />
	nickname = &lt;str&gt;:<br />
	the nickname Anna^ will connect with. Default is Anna^<br />
	username = &lt;str&gt;:<br />
	the username Anna^ will connect with. Default in anna<br >
	channel = #&lt;str&gt;:<br />
	the channel Anna^ should join upon successful connection. Anna^ will 
	not prepend a # if it isn't there<br />
	ircname = &lt;str&gt;:<br />
	the ircname (see whois output). Default is Boten Anna<br />
	nspasswd = &lt;str&gt;:<br />
	if set, Anna^ will identify herself with Nickserv upon successful connection. Anna^ will also reclaim her nick if it was taken.<br />
	dbfile = &lt;str&gt;:<br />
	path of the database-file Anna^ will use. Default is ~/.anna/anna.db<br />
	colour = &lt;bool&gt;:<br />
	if true, Anna^ will colour the output to the terminal (note: this is not the output to the IRC-server) <br />
	silent = &lt;bool&gt;:<br />
	if true, Anna^ will stay very silent, only informing about crucial events.<br />
	verbose = &lt;bool&gt;:<br />
	if true, Anna^ will speak all the time (she is a girl, after all)<br />
	logging = &lt;bool&gt;:<br />
	if true, Anna^ will log all activity to logfiles<br />
	trigger = &lt;str&gt;:<br />
	this is the trigger all commands should be prefixed with. Default is !<br />
	bannedwords = &lt;str&gt;:<br />
	a space-separated list of banned words. You can use regexp-like features here. If Anna^ sees a banned word in a public channel, she will kick the user.<br />
	voice_auth = &lt;bool&gt;:<br />
	if true, Anna^ will voice authenticated users.<br /></p>
	<p>Any settings in the local configuration file automatically overwrites the 
	systemwide file.</p>

	<p>It is possible to specify a number of these options as command-line arguments
	when running Anna^. Refer to the output of `anna --help` for more info.</p>

	<p><b>4) First run</b></p>
	<p>The first time you run Anna^, she will copy the default database and 
	configuration-file to your home-directory. She will then prompt you for
	a username and a password for the root-user. The root-user will be able to 
	control various aspects of Anna^ from within IRC.
	On the first run after an upgrade, Anna^ will perform updates to the database
	structure or content if necessary. Should these fail, a backup copy of the
	database will be stored in ~/.anna.</p>

	<p><b>5) In-IRC setup</b></p>
	<p>It is possible to control various settings from within IRC. Most notably is the 
	auto-op interface. Anna^ can maintain a list of registered users, that should 
	be opped. In order to modify that list, you must be flagged as a bot admin. 
	Currently, the user you created on the first run has this flag.
	The two functions addop and rmop will allow you to add or remove a user 
	registered with Anna^ from the list of channel operators.</p>

	<p><b>6) Features</b></p>

	<p><i>6.1) Standard features</i></p>
<p>Anna^ has a multitude of features available in the public channel Anna^ resides
in as well as in private conversations. 
Anna^ will respond to most of these either through !&lt;cmd&gt; or Anna^[ :,-] &lt;cmd&gt;
The current list of commands (as of 0.40) is as follows:
&lt;int&gt; is an integer, &lt;str&gt; is a string

!dice &lt;int1&gt;d&lt;int2&gt;<br />	
Returns the result of a dicethrow of int1 dice with int2 sides<br />
	
!voice/!voiceme<br />
Voices a (registered) user in the channel, if enabled in the configuration<br />
	
!rstats<br />
Prints statistical information about played roulette-games<br />

!search &lt;str1&gt; [&lt;str2&gt;]<br />
Searches the database for notes or quotes matching a string.
If str2 is present, Anna^ will treat str1 as a content indicator and str2
as the search-string. Possible content indicators are 'notes', 'quotes' and 
'all'.
If str2 isn't present, Anna^ will implicitly assume that !search all str1
was called.<br />

!rot13 &lt;str&gt;<br />
Return rot13-encrypted str.<br />
rot13 is a very weak encryption, often used to avoid spoiling in forums, IRC or
newsgroups.<br />

!note [&lt;str1&gt;[ = &lt;str2&gt;]]<br />
!note without any arguments prints a random note from the database.
!note str1 prints the note with the matching key str1
!note str1 = str2 adds a new note to the database, with str1 as key and
str2 as the actual note.<br />

!google [&lt;int&gt;] &lt;str&gt;<br />
Searches google for str. If int is set to a positive integer, it returns 
the first int hits, otherwise it returns the first hit.<br />

!fortune [&lt;str&gt;]<br />
fortune calls the good ol' fortune from *nix systems. Fortune accepts some 
optional parameters, such as -a, -e and -o (refer to fortune documentation) as
well as a package-name, to select fortunes from.<br />

!karma &lt;str&gt;<br />
Returns karma information for the nick <str>. Refer to karma documentation in 
section 6.4.<br />

!quote<br />
Returns a random quote from the database.<br />

!addquote &lt;str&gt;<br />
Add the str-quote to the database<br />

!bash [&lt;str&gt;]<br />
Returns a quote from the bash online collection of IRC-quotes.<br />
If str is a number (with or without a # prefixed), Anna^ will print that 
specific quote# from the bash database. If str is 'random' or unset, Anna^
will print a random quote.<br />

!roulette<br />
Test your luck in this game of russian roulette. If you lose in a public 
channel, Anna^ will boot you out (if she can). Don't be a coward!<br />

!reload<br />
Reload is for sissies, but will nonetheless allow you to reload Anna^'s gun in
a game of roulette.<br />

!question &lt;str&gt;<br />
Ask a question of Anna^ and she will give you the profound truth... sometimes.
You can also ask Anna^ directly: Anna^: question?<br />

!addanswer &lt;str&gt;<br />
Add yet another profound truth to Anna^'s collection.<br />

!up/!uptime<br />
Returns the time the current session has lasted.<br />

!lart &lt;str&gt;<br />
A LART (Luser Attitude Readjustment Tool). Throws a random insult after str.
If str is 'me', Anna^ will insult YOU!<br />

!addlart &lt;str&gt;<br />
Adds another insult to Anna^'s collection. <str> _must_ contain '##' (two 
hashmarks) which will be substituted with the name of the luser.<br />

!haiku<br />
Returns a random haiku<br />

!addhaiku &lt;str1&gt; ## &lt;str2&gt; ## &lt;str3&gt;<br />
Add a threeline (str1, str2 and str3) haiku to Anna^'s collection.<br />

!order &lt;str1&gt;[ for &lt;str2&gt;]<br />
Go ahead, why not order a nice str1 from the bar? Or why not order
str1 for your good friend, str2? Anna^ has a large assortment of goods, 
including beer, peanuts, coffee, chimay and anything else you can think up<br />

!addorder &lt;str1&gt; = &lt;str2&gt;<br />
Add a custom item, str1 to Anna^'s assortment. str2 is the message you will
get when you order the item. This _must_ include '##' (two hashmarks) which is
substituted for the username.<br />

!seen &lt;str&gt;<br />
Return information on when Anna^ last saw <str> (a nickname).<br />

!op<br />
Op yourself, if you have the rights.<br />

Besides these commands, there are a couple or shortcuts and other features:<br />

"Anna^: &lt;str1&gt; or &lt;str2&gt;"<br />
Anna^ will decide for you whether str1 or str2 is the right thing.<br />

"Anna^: &lt;int1&gt;d&lt;int2&gt;"<br />
A shortcut to !dice &lt;int1&gt;d&lt;int2&gt;<br />

"Anna^: &lt;str&gt;?"<br />
Shortcut to !question &lt;str&gt;<br />

"str++" or "str--"<br />
Increase or descrease the karma of str (see section 6.4 for more info on 
karma)

There are various other things Anna^ will respond to, so don't get surprised if
she yaps all of a sudden.</p>

	<p><i>6.2) Private features</i></p>
<p>There are a couple of commands, that Anna^ will only respond to in private:<br />
&lt;int&gt; = integer, &lt;str&gt; = string<br />

auth &lt;str1&gt; [&lt;str2&gt;]<br />
(NOTE: there's no trigger prefix for this!)<br />
If both str1 and str2 are set, Anna^ will attempt to authenticate the user
with str1 as username and str2 as password. Otherwise, Anna^ will assume 
that the nickname is the same as the username. See section 6.3 for more on 
sessions.<br />

!addop &lt;str&gt;<br />
Add str to the list of channel operators (requires admin privs)<br />

!rmop &lt;str&gt;
Remove str from the list of channe loperators (requires admin privs)<br />

!register &lt;str1&gt; &lt;str2&gt;<br />
Register with Anna^ with <str1> as username and <str2> as password.</p>

	<p><i>6.3) Sessions</i></p>
	<p>Sessions are new from 0.40. Sessions allow you to register with Anna^ and
	later on identify yourself towards the bot. This makes it possible to keep a
	list of operators or to store information for yourself within Anna^'s database.
	Keep in mind, that no matter what, the bot operator can snoop both the 
	information and you password, because IRC operates in plaintext, so don't use
	your $TOPSECRET password for this.
	You can register with the !register directive, identify yourself with the auth
	command, and as an admin, you can add or remove users from the channel operator
	list with !addop and !rmop. If enabled, registered users can be voiced in 
	channel.</p>

	<p><i>6.4) Misc. features and concepts</i></p>
	<b>The karma principle</b>
	<p>Everything in lives revolves around karma. Whenever you do something in life, a
	samskara-seed is stored for you for later use. You can't control this, it just 
	happens. In IRC, like everywhere else, you have karma. In IRC, however, your 
	peers judge you - so you better behave :)
	Anna^ keeps track of karma, and you can reward or subtract good karma with the
	<str>++ and <str>-- directives (see 6.1). You can see the karma of <str> with 
	the !karma command.</p>
	</div><br />
	<div class='main_box_head'><span class='main_head'>Miscallaneous traps</span></div>
	<div class='main_box_content'>
		<p><b>Why do I get a 'connect error 111: Connection refused'?</b><br />
			The most probable reason, is that the server recently changed it's address. You can either use the IP-address of the server instead or (if you're connecting to a network) you can use another server on the network</p>
	</div><br />
		

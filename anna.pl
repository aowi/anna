#!/usr/bin/perl
# vim: et:ts=4:sw=4
use strict;
use warnings;

## Anna^ IRC Bot
# Copyright (C) 2006-2009 Anders Ossowicki <and@vmn.dk>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Questions, comments, general bitching, nude pics and beer goes to 
# Anders Ossowicki <and@vmn.dk>.

## Set basic stuff like vars and the like up
use lib "lib";
use Anna::Utils;
use Anna::Debug qw(_default);
use Anna::Config;
use Anna::Output qw(irclog);
use Anna::Connection;
use Anna::Log;
use Anna::CTCP;
use Anna::DB;
use Anna::Module;
use Anna::ModuleHandler;
use Anna::Auth;
use File::Copy;
use Term::ReadKey;
use POE;
use POE::Component::IRC;
use DBI;
use LWP::UserAgent;
use HTML::Entities;

## Trap signals
$SIG{'INT'} = 'ABORT';

# Clean out remnants from last session
#Anna::Config::empty_db;
# Anna::Module::empty_db; # XXX: Makes firstrun fail

my $config = new Anna::Config;

## Read config-file (overrides default)
# By making two seperate if-conditions, the values of /etc/anna.conf will be
# overridden _if_, and only if, they are also set in ~/.anna/config. This 
# seems to be the most failsafe method.
$config->parse_configfile("/etc/anna.conf") if (-r "/etc/anna.conf");
$config->parse_configfile($ENV{'HOME'}."/.anna/config") if (-r $ENV{'HOME'}."/.anna/config");


# Capture temporary vars.
{
    my %conf;
    ## Read command-line arguments (overrides config-file)
    use Getopt::Long qw(:config bundling);
    GetOptions(
        'verbose|v!' => \$conf{'verbose'},
        'color!' => \$conf{'colour'},
        'server|s=s' => \$conf{'server'},
        'channel|c=s' => \$conf{'channel'},
        'nick|n=s' => \$conf{'nick'},
        'name|a=s' => \$conf{'name'},
        'username|u=s' => \$conf{'username'},
        'port|p=i' => \$conf{'port'},
        'nspasswd|P=s' => \$conf{'nspasswd'},
        'silent!' => \$conf{'silent'},
        'debug|d!' => \$conf{'debug'},
        'version|V' => sub { version(0) },
        'help|h|?' => sub { usage(0) }
    ) or die( usage(1) );
    foreach (keys %conf) {
        $config->set($_, $conf{$_}) if (defined $conf{$_});
    }
}

# Enable debug stuff
if ($config->get('debug')) {
    eval { require Data::Dumper; };
    if ($@) {
        error_print "Please install module Data::Dumper if you want to run Anna^ in debugging mode";
        $config->toggle('debug');
    }
}

# Make verbose override silent
$config->delete('silent') if ($config->get('verbose') && $config->get('silent'));

## Done with basic setup

# Print welcome
version() unless $config->get('silent');


# XXX: temp
warn_print("Testing warning level");
error_print("Testing error level");
debug_print("Testing debug level");
verbose_print("Testing verbose level");

# Check for first-run
if (!(-e Anna::Utils->CONFIGDIR."/anna.db") || !(-e "anna.db")) {
    # First run
    my $dbf = Anna::Utils->CONFIGDIR."/anna.db";
    print "This seems to be the first time you're running Anna^... welcome!\n";
    unless (-e $ENV{'HOME'}."/.anna") {
        verbose_print "Creating ~/.anna directory structure to store information...";
        mkdir $ENV{'HOME'}."/.anna" or die "\nFailed to create ~/.anna/ directory. $!";
        mkdir $ENV{'HOME'}."/.anna/registry" or die "\nFailed to create ~/.anna/registry directory. $!";
    }
    # Copy database to home
    print "Creating database for Anna^ and filling it... " if ($config->get('verbose'));
    copy("/usr/local/share/anna/anna.db", $dbf) 
        or die "\nFailed to copy /usr/local/share/anna/anna.db to $dbf: $!";
    print "done\n" if ($config->get('verbose'));
    unless (-e $ENV{'HOME'}."/.anna/config") {
        # Copy config to locale
        print "Creating standard configuration file in ~/.anna/config... " 
            if ($config->get('verbose'));
        copy("/etc/anna.conf", $ENV{'HOME'}."/.anna/config") 
            or die "Failed to copy /etc/anna.conf to ~/.anna/config: $!";
        print "done\n" if ($config->get('verbose'));
    }
    create_rootuser();
    print "You're all set!\n";
}

# Do we have sufficient configuration to create a connection?
unless ($config->exists('name') && $config->exists('username') && $config->exists('port') && $config->exists('server')  && $config->exists('nick')) {
    print "All of the following variables must be set. Bailing out:\n";
    for(qw(name nick username server port)) {
        printf("%8s: ", $_);
        $config->exists($_) ? print $config->get($_)."\n" : print "\n";
    }
    print "Please update your configuration file with the missing parameters\n";
    exit 1;
}

# Create POE Session
POE::Session->create(
    inline_states => {
        _start          => \&_start,
        _default        => \&_default,

        connect         => \&do_connect,
        reconnect       => \&do_reconnect,
        autoping        => \&do_autoping,

        irc_error       => \&on_error,
        irc_socketerr       => \&on_socketerr,
        irc_disconnected    => \&on_disconnected,

        irc_001         => \&on_connect,
        irc_connected       => \&on_connected,
        irc_join        => \&on_join,
#       irc_invite      => \&on_invite, # Not handled yet!
        irc_kick        => \&on_kick,
        irc_mode        => \&on_mode,
        irc_msg         => \&on_msg,
        irc_nick        => \&on_nick,
        irc_kill        => \&on_kill,
        irc_notice      => \&on_notice,
        irc_part        => \&on_part,
        irc_public      => \&on_public,
        irc_quit        => \&on_quit,
        irc_topic       => \&on_topic,
#       irc_whois       => \&on_whois, # Not handled yet!
#       irc_whowas      => \&on_whowas, # Ditto

        irc_324         => \&on_324,    # channelmodeis
        irc_329         => \&on_329,    # channelcreate
        irc_332         => \&on_332,
        irc_333         => \&on_333,
        irc_353         => \&on_namreply,

        # CTCP stuff
        irc_ctcp_ping       => \&on_ctcp_ping,
        irc_ctcpreply_ping  => \&on_ctcpreply_ping,
        irc_ctcp_version    => \&on_ctcp_version,
        irc_ctcpreply_version   => \&on_ctcpreply_version,
        irc_ctcp_time       => \&on_ctcp_time,
        irc_ctcp_finger     => \&on_ctcp_finger,

        # Error handling
        irc_401         => \&err_4xx_default, # nosuchnick
        irc_402         => \&err_4xx_default, # nosuchserver
        irc_403         => \&err_4xx_default, # nosuchchannel
        irc_404         => \&err_4xx_default, # cannotsendtochan
        irc_405         => \&err_4xx_default, # toomanychannels
        irc_406         => \&err_4xx_default, # wasnosuchnick
        irc_407         => \&err_4xx_default, # toomanytargets
        irc_433         => \&err_nick_taken,  # nicknameinuse

        # Dummy stuff (we don't care about)
        _child          => sub { "DUMMY" },
        irc_isupport        => sub { "DUMMY" },
        irc_ping        => sub { "DUMMY" },
        irc_registered      => sub { "DUMMY" },
        irc_plugin_add      => sub { "DUMMY" },
        irc_plugin_del      => sub { "DUMMY" },
    },
);

## Go for it!
$poe_kernel->alias_set('irc');
$poe_kernel->run();

# Sayoonara
verbose_print("Closing down... sayoonara");
exit(0);

## _start
# Called when POE start the session. Take care of connecting, joining and the like
sub _start {
    my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];

    # Connect to database
    verbose_print(sprintf("Connecting to SQLite database %s...", Anna::Utils->CONFIGDIR."/anna.db"));
    my $dbh = new Anna::DB or die "Couldn't connect to SQLite DB";

    # Syncronize the database (update if version doesn't match script)
    Anna::DB::sync($dbh);

    # Create IRC-connection object
    verbose_print(sprintf("Creating connection to irc server: %s...", $config->get('server')));
    my $irc = POE::Component::IRC->spawn(
        ircname     => $config->get('name'),
        port        => $config->get('port'),
        username    => $config->get('username'),
        server      => $config->get('server'),
        nick        => $config->get('nick'),
        debug       => $config->get('debug')
    ) or die "\nCan't create connection to ".$config->get('server');
    $irc->yield(register => 'all');

    # Create logfile
    my $log = new Anna::Log(
        format  => 'service',
        name    => 'core',
        heap    => \$heap
    );
        
    # Get stuff into the heap
    $heap->{log} = $log;
    $heap->{irc} = $irc;
    
    # Load modules from homedir first, so they will mask system-wide modules
    Anna::ModuleHandler::loaddir(Anna::Utils->CONFIGDIR."/modules/core/");
    Anna::ModuleHandler::loaddir(Anna::Utils->CONFIGDIR."/modules/auto/");
    Anna::ModuleHandler::loaddir("/usr/share/anna/modules/core/");
    Anna::ModuleHandler::loaddir("/usr/share/anna/modules/auto/");
    # Connect
    $kernel->yield("connect");
}


sub create_rootuser {
    my $config = new Anna::Config;
    print "You will need a root user to control Anna^ from within IRC. Please create one now:\n";
    my $newroot;
    my $dbh = new Anna::DB or die $DBI::errstr;
    do {
        print "Username: ";
        chomp($newroot = ReadLine(0));
    } while (!$newroot);
    ReadMode(2); # No echo
    my ($newpasswd, $newpasswd2, $i);
    do {
        print "\nPassword mismatch - try again\n" if ($i);
        print "Password: ";
        chomp($newpasswd = ReadLine(0));
        print "\nRetype password: ";
        chomp($newpasswd2 = ReadLine(0));
        $i++;
    } while ($newpasswd ne $newpasswd2);
    ReadMode(1); # Restore
    # The additional \n's are for ReadMode-restoration
    print "\nCreating root user... ";
    my $query = q{
        INSERT INTO users (username, password, admin) 
        VALUES (?, ?, 1)
    };
    my @salt_chars = ('a'..'z','A'..'Z','0'..'9');
    my $salt = $salt_chars[rand(63)] . $salt_chars[rand(63)];
    $dbh->do($query, undef, $newroot, crypt($newpasswd, $salt))
        or die error("\nFailed to create root user:".$DBI::errstr."\n"); 
    print "done\n";
}

## parse_message
# This is where everything take place. Both on_msg (privmsgs) and 
# on_public (privmsgs to channels) send the message along with 
# important information to this subroutine.
# parse_message should return either text to be printed, or nothing.
# The subroutines called from within parse_message may print stuff, but
# should return 'FALSE' in that case, to avoid printing things twice.
sub parse_message {
    my ($kernel, $heap, $from, $to, $msg, $type) = @_;
    my ($nick, $host) = split(/!/, $from);
    my $c = new Anna::Config;
    my $trigger = $c->get('trigger');
    my $botnick = $c->get('nick');

    # Trim whitespace. This shouldn't give any trouble.
    $msg = trim($msg);
    
    my $out = 'FALSE';
    
    my $target;
    if ($type eq 'public') {
        # Sent to a channel, so this is default return target
        $target = $c->get('channel');
    } else {
        $target = $nick;
    }
    
    # Check for module-bound commands
    Anna::ModuleHandler::execute($msg, $heap, $target, $nick, $host, $type) 
        or error_print "Error while handling $msg.";

    if ($type eq "public") {
        # Public message (to a channel)
        # This part is meant for things that _only_ should
        # be monitored in channels
        
        # Lastseen part
        if ($msg !~ /^!seen .*$/) {
            bot_lastseen_newmsg($heap, $nick, $msg);
        }
        # Only follow karma in channels
        if ($msg =~ /^(.+)(\+\+|\-\-)$/) {
            $out = bot_karma_update($heap, $1, $2, $nick);
        }
        foreach ($c->get('bannedwords')) {
            if ($msg =~ /$_/i) {
                $heap->{irc}->yield(kick => $c->get('channel') => $nick => $_);
            }
        }
    } elsif ($type eq "msg") {
        # Private message (p2p)
        # This is meant for things that anna should _only_
        # respond to in private (ie. authentications).
        if ($msg =~ /^(\Q$trigger\E|)op$/i) {
            $out = bot_op($heap, $from);
        } elsif ($msg =~ /^(\Q$trigger\E|)addop\s+(.*)$/) {
            $out = bot_addop($heap, $2, $from);
        } elsif ($msg =~ /^(\Q$trigger\E|)rmop\s+(.*)$/) {
            $out = bot_rmop($heap, $2, $from);
        }
    }
    
    ## This part reacts to special words/phrases in the messages
    if ($msg =~ /^\Q$botnick\E[ :,-].*poke/i) {
        $out = "Do NOT poke the bot!";
        return $out;
    }

    if ($msg =~ /^n., anime$/) {
        $out = $nick . ": get back to work, loser!";
        return $out;
    }
    if ($msg =~ /dumb bot/i) {
        $out = "Stupid human!";
        return $out;
    }
    if ($msg =~ /dance/i) {
        $heap->{irc}->delay(['ctcp' => $c->get('channel') => 'ACTION dances o//'], 1);
        $heap->{irc}->delay(['ctcp' => $c->get('channel') => 'ACTION dances \\\\o'], 2);
        $heap->{irc}->delay(['ctcp' => $c->get('channel') => 'ACTION DANCES \\o/'], 3);
        return;
    }
        
    if ($msg =~ /^\Q$botnick\E[ :,-]+(.*)\s+or\s+(.*)\?$/) {
        my @rep = ($1,$2);
        return $nick . ": ".$rep[rand(2)]."!";
    }
=cut out until regexp bindings are implemented
    if ($msg =~ /^\Q$botnick\E[ :,-]+.*\?$/) {
        $out = $nick . ": ".bot_answer();
        return $out;
    }
=cut back

    # Return now, unless there's a trigger
    # In case of a trigger, trim it and parse the remaining message
    return $out if ($msg !~ /^(\Q$trigger\E|\Q$botnick\E[ :,-]+)/);
    my $cmd = $msg;
    $cmd =~ s/^(\Q$trigger\E|\Q$botnick\E[ :,-]+\s*)//;
    



    ## Bot commands
    
    if ($cmd =~ /^voice(me|)$/) {
        $out = bot_voice($heap, $from);
    } elsif ($cmd =~ /^search\s+(.*)$/) {
        $out = bot_search($heap, $1);
    } elsif ($cmd =~ /^rot13\s+(.*)$/i) {
        $out = bot_rot13($heap, $1);
    } elsif ($cmd =~ /^google\s+(.*)$/i) {
        $out = bot_googlesearch($heap, $1);
    } elsif ($cmd =~ /^fortune(\s+.*|)$/i) {
        $out = bot_fortune($heap, $1);
    } elsif ($cmd =~ /^karma\s+(.*)$/i) {
        $out = bot_karma($heap, $1);
    } elsif ($cmd =~ /^quote$/i) {
        $out = bot_quote($heap);
    } elsif ($cmd =~ /^addquote\s+(.*)$/i) {
        $out = bot_addquote($heap, $nick, $1);
    } elsif ($cmd =~ /^up(time|)$/i) {
        $out = bot_uptime($heap);
    } elsif ($cmd =~ /^seen\s+(.*)$/i) {
        $out = bot_lastseen($heap, $nick, $1, $type);
    } elsif ($cmd =~ /^meh$/i) {
        $out = "meh~";
    } elsif ($cmd =~ /^op$/i) {
        $out = bot_op($heap, $from);
    }

    return $out;
}

## Bot-routines
# These are the various subs for the bot's commands.


## bot_addop
# Takes params: username to give op rights, the hostmask of the sender and the 
# heap
# Modifies the op-value in the users table.
sub bot_addop {
    my ($heap, $user, $from) = @_;
    return "Error - you must supply a username to op" unless $user;
    return "Error - invalid argument count - this is likely a software bug"
        unless ($heap && $user && $from);

    $user = trim($user);
    my ($nick, $host) = split(/!/, $from);
    
    return "Error - you must be authenticated first" 
        unless defined $heap->{auth}->{$host};

    my $dbh = new Anna::DB;
    my $query = "SELECT admin FROM users WHERE username = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($heap->{auth}->{$host}->{user});

    if (my @row = $sth->fetchrow()) {
        return "Error - you are not an admin!" unless $row[0];

        # User is admin - proceed
        $query = "SELECT id, op FROM users WHERE username = ?";
        $sth = $dbh->prepare($query);
        $sth->execute($user);
        @row = $sth->fetchrow();
        return sprintf "Error - no such user exists: %s!", $user 
            unless @row;
        return sprintf "%s is already an op!", $user 
            if ($row[1]);

        $query = "UPDATE users SET op = ? WHERE username = ?";
        $sth = $dbh->prepare($query);
        $sth->execute(1, $user);
        return sprintf "User %s successfully added to list of opers", $user;
    }
    return "Error - couldn't verify your rights - this is probably a bug"
}

## bot_addquote 
# This is used to add a quote to the database
sub bot_addquote {
    my ($heap, $nick, $quote) = @_;
    my $query = "INSERT INTO quotes (quote, author) VALUES (?, ?)";
    my $sth = Anna::DB->new->prepare($query);
    $sth->execute($quote, $nick);
    return "Quote inserted. Thanks ".$nick;
}

## bot_fortune
# Prints a fortune, if fortune is installed
sub bot_fortune {
    my ($heap, $args) = @_;
    
    my @path = split(':', $ENV{'PATH'});
    foreach (@path) {
        if (-x "$_/fortune") {
            my $fortune_app = $_."/fortune";
            
            # Parse arguments
            my $cmd_args = "";
            $cmd_args .= " -a" if ($args =~ s/\W-a\W//);
            $cmd_args .= " -e" if ($args =~ s/\W-e\W//);
            $cmd_args .= " -o" if ($args =~ s/\W-o\W//);
            
            my $fortune = qx($fortune_app -s $cmd_args 2>/dev/null);
            return "No fortunes found" if $fortune eq '';
            $fortune =~ s/^\t+/   /gm;
            return $fortune;
        }
    }
    irclog('status' => "Failed to fetch fortune - make sure fortune is installed, and in your \$PATH\n");
    warn_print "Failed to fetch fortune - make sure fortune is installed, and in your \$PATH";
    return "No fortune, sorry :-(";
}

## bot_googlesearch
# Search google. Returns the first hit
sub bot_googlesearch {
    my ($heap, $query) = @_;
    return 'FALSE' if ($query eq '');
    $query = trim($query);

    # Check if user wants specific number of results. 
    # We're geeks, so we count from zero
    my $results = 0;
    
    if ($query =~ /^(\d+)\s+(.*)$/) {
        # -1 because we prefer to count from zero
        $results = $1 - 1;
        $query = $2;
    }
    
    # Print a max of twenty results 
    # TODO: Make it configurable once the admin iface exists
    $results = 19 if ($results >= 20);

    # Format query-string
    $query =~ s/\s/\+/g;
    
    # Initiate useragent
    my $ua = new LWP::UserAgent;
    $ua->agent("Mozilla/5.0" . $ua->agent);
    
    # Search
    my $request = new HTTP::Request GET => "http://www.google.com/search?hl=en&ie=ISO-8859-1&q=".$query;
    my $get = $ua->request($request);
    my $content = $get->content;

    # Format results. Replace <br> with newlines and remove tags
    $content =~ s/\<br\>/\n/g;
    $content =~ s/\<.+?\>//sg;
    $content =~ s/#//s;

    # Make array with all results
    my @lines = split('\n', $content);
    my @pages = grep(/Similar( |&nbsp;)pages/, @lines);
    
    return "Sorry - google didn't return any results :(" if (scalar(@pages) == 0);
    
    # Remove empty results and decode entities.
    my $i;
    for ($i = 0; $i < scalar(@pages); $i++) {
        $pages[$i] =~ s/\s+.*//g;
        $pages[$i] = decode_entities($pages[$i]);
        if ($pages[$i] =~ /(^\n|\s+\n)/){ splice(@pages, $i, 1) };
        if ($pages[$i] !~ /\./){ splice(@pages, $i, 1) };
    }
    
    my $out;
    for ($i = 0; $i <= $results; $i++) {
        # Return if no more results were returned
        return $out if (!$pages[$i]);
        $out .= "http://".$pages[$i]."\n";
    }
    return $out;
}

# bot_karma
# Returns the current karma for a word
sub bot_karma {
    my ($heap, $word) = @_;

    my $query = "SELECT * FROM karma WHERE word = ? LIMIT 1";
    my $sth = Anna::DB->new->prepare($query);
    $sth->execute($word);
    my @row;
    if (@row = $sth->fetchrow()) {
        return "Karma for '".$word."': ".$row[2];
    }
    return "Karma for ".$word.": 0";
}

## bot_karma_update
# This is used to update the karma-stats in the database
# Takes three arguments - word, karma change and user
sub bot_karma_update {
    my ($heap, $word, $karma, $nick) = @_;
    if ($word eq '') {
        # This should NOT happen lest there's a bug in the 
        # script
        return "Karma not updated (Incorrect word)";
    }
    my $dbh = new Anna::DB;
    my $query = "SELECT * FROM karma WHERE word = ? LIMIT 1";
    my $sth = $dbh->prepare($query);
    $sth->execute($word);
    my @row;
    if (@row = $sth->fetchrow()) {
        if ($karma eq "++") {
            $karma = $row[2] + 1;
        } elsif ($karma eq "--") {
            $karma = $row[2] - 1;
        } else {
            # This should NOT happen lest there's a bug in
            # the script
            return "Karma not updated (Incorrect modifier)";
        }
        $query = "UPDATE karma 
            SET karma = ?, user = ? 
            WHERE id = ?";
        $sth = $dbh->prepare($query);
        $sth->execute($karma, $nick, $row[0]);
        return 'FALSE';
    } else {
        # Word does not exist
        if ($karma eq "++") {
            $karma = 1;
        } elsif ($karma eq "--") {
            $karma = -1;
        } else {
            # This should NOT happen lest there's a bug in
            # the script
            return "Karma not updated (Incorrect modifier)";
        }
        $query = "INSERT INTO karma (word, karma, user) 
            VALUES (?, ?, ?)";
        $sth = $dbh->prepare($query);
        $sth->execute($word, $karma, $nick);
        # No need to inform of the karma-change
        return 'FALSE';
    }
}

## bot_lastseen
# This returns information on when a nick last was seen
sub bot_lastseen {
    my ($heap, $nick, $queried_nick, $type) = @_;
    my ($query, $sth);
    
    if ($type eq 'public') {
        # Update lastseen table
        $query = "DELETE FROM lastseen WHERE nick = ?";
        $sth = Anna::DB->new->prepare($query);
        $sth->execute($nick);
        my $newmsg = $nick . ' last queried information about ' . $queried_nick;
        $query = "INSERT INTO lastseen (nick, msg, time) 
                VALUES (?, ?, ".time.")";
        $sth = Anna::DB->new->prepare($query);
        $sth->execute($nick, $newmsg);
    }

    if (lc($queried_nick) eq lc(Anna::Config->new->get('nick'))) {
        return "I'm right here, dumbass";
    }
    if (lc($queried_nick) eq lc($nick)) {
        return "Just look in the mirror, okay?";
    }
    if (lc($queried_nick) =~ /^(me|myself|I)$/) {
        return "Selfcentered, eh?";
    }
    if (lc($queried_nick) eq "jimmy hoffa") {
        return "I don't know either, try the Piranha Club";
    }
    if (lc($queried_nick) =~ /^dokuro(-chan|)$/) {
        return "I don't know either, try the Wood Glue Club";
    }
    if (lc($queried_nick) eq "the answer to life, the universe and everything") {
        return "42";
    }

    $query = "SELECT * FROM lastseen 
            WHERE nick = ? LIMIT 1";
    $sth = Anna::DB->new->prepare($query);
    $sth->execute(lc($queried_nick));
    
    my @row;
    if (@row = $sth->fetchrow()) {
        my ($out, $time, $msg);
        $msg = $row[2];
        $time = $row[3];
        $time = calc_diff($time);
        $out = $msg . ' ' . $time . ' ago.';
        return $out;
    } 

    return "Sorry, I couldn't find any information for $queried_nick";
}

## bot_lastseen_newmsg
# This handles new messages in the channel, stores them in sqlite db
# for later retrieval with !seen command.
sub bot_lastseen_newmsg {
    my ($heap, $nick, $msg) = @_;
    my $time = time;
    
    my $dbh = new Anna::DB;
    # Delete previous (if any) messages
    my $query = "DELETE FROM lastseen WHERE nick = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute(lc($nick));
    
    # Insert new quote
    $msg = $nick .' last said \''.$msg.'\'';
    
    $query = "INSERT INTO lastseen (nick, msg, time) 
            VALUES (?, ?, ?)";
    $sth = $dbh->prepare($query);
    $sth->execute(lc($nick), $msg, $time);
    return;
}



## bot_op
# Takes two parameters (the hostmask of the user and the heap)
# Ops the user is he/she has the rights
sub bot_op {
    my ($heap, $from) = @_;
    return "Error - no hostmask or heap supplied. This is probably a bug"
        unless (defined $heap && defined $from);

    my ($nick, $host) = split(/!/, $from);
    return "Error - you must authenticate first" unless defined $heap->{auth}->{$host};
    my $query = "SELECT op FROM users WHERE username = ?";
    my $sth = Anna::DB->new->prepare($query);
    $sth->execute($heap->{auth}->{$host}->{user});
    if (my @row = $sth->fetchrow()) {
        if ($row[0]) {
            $heap->{irc}->yield(mode => Anna::Config->new->get('channel') => "+o" => $nick);
            return;
        }
    }
    return "I am not allowed to op you!";
}

## bot_quote
# This returns a random quote from a local quote database
sub bot_quote {
    my $heap = shift;
    return unless defined $heap;

    my $query = "SELECT * FROM quotes";
    my $sth = Anna::DB->new->prepare($query);
    $sth->execute;

    my (@rows, @quotes);
    my $i = 0;
    while (@rows = $sth->fetchrow()) {
        $quotes[$i] = $rows[1];
        $i++;
    }
    if ($i == 0) {
        return "No quotes were found. You're a boring lot!";
    }
    my $quote = $quotes[rand scalar @quotes];
    # Yes, it's ugly but we need this to get proper linebreaking...
    $quote =~ s/\Q\n\E/\n/g;
    return $quote;
}

## bot_rmop
# Removes a user from list of opers. Takes three params - username to remove, 
# sender and the heap
sub bot_rmop {
    my ($heap, $user, $from) = @_;
    return "Error - you must supply a username" unless defined $user;
    return "Error - invalid argument count - this is likely a software bug"
        unless (defined $heap && defined $from);

    $user = trim($user);
    my ($nick, $host) = split(/!/, $from);
    
    return "Error - you must be authenticated first" 
        unless defined $heap->{auth}->{$host};
    
    my $dbh = new Anna::DB;
    my $query = "SELECT admin FROM users WHERE username = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($heap->{auth}->{$host}->{user});

    if (my @row = $sth->fetchrow()) {
        return "Error - you are not an admin!" unless $row[0];

        # User is admin - proceed
        $query = "SELECT id FROM users WHERE username = ?";
        $sth = $dbh->prepare($query);
        $sth->execute($user);
        return sprintf "Error - no such user exists: %s!", $user 
            unless $sth->fetchrow();

        $query = "UPDATE users SET op = ? WHERE username = ?";
        $sth = Anna::DB->new->prepare($query);
        $sth->execute(0, $user);
        return sprintf "User %s successfully removed from list of opers", $user;
    }
    return "Error - couldn't verify your rights - this is probably a bug"
}
    
## bot_rot13
# Encrypts and decrypts rot13-strings
sub bot_rot13 {
    my ($heap, $str) = @_;
    return unless defined $str;

    $str =~ y/A-Za-z/N-ZA-Mn-za-m/;
    return $str;
}

## bot_search
# Searches various tables in the database
# Syntax is !search <table> <string>. Possible values are "notes" and "quotes"
sub bot_search {
    my ($heap, $where) = @_;
    return unless defined $heap;
    return 'FALSE' unless defined $where;

    my ($table, $string);
    if ($where =~ /(notes|quotes|all)\s+(.*)/) {
        $table = $1;
        $string = $2;
    } else {
        $table = 'all';
        $string = $where;
    }
    if ($table eq 'notes') {
        my $query = qq|SELECT * FROM notes WHERE word LIKE ?|;
        my $sth = Anna::DB->new->prepare($query);
        # No... the error wasn't here... I fail miserably
        $sth->execute("%".$string."%") or die(error($sth->errstr));
        my ($i, $j) = 0;
        my (@row, @words);
        while (@row = $sth->fetchrow()) {
            $words[$i] = $row[1];
            $i++;
        }
        
        return "No results for '".$string."'" if (scalar(@words) == 0);

        my $result = "Search results for '".$string."': ";
        if (scalar(@words) > 15) {
            for ($j = 0; $j <= 15; $j++) {
                $result .= "'" . $words[$j] . "', ";
            }
            $result =~ s/(.*), /$1/;
            $result .= " (search returned too many results)";
            return $result;
        }
        
        my $words;
        foreach (@words) {
            $words .= "'$_', ";
        }
        $words =~ s/(.*), /$1/;
        return $result . $words;
    } 

    if ($table eq 'quotes') {
        my $query = qq|SELECT * FROM quotes WHERE quote LIKE ?|;
        my $sth = Anna::DB->new->prepare($query);
        $sth->execute("%".$string."%") or die(error($sth->errstr));
        my ($i, $j) = 0;
        my (@row, @quotes);
        while (@row = $sth->fetchrow()) {
            $quotes[$i] = $row[1];
            $i++;
        }
        
        return "No results for '".$string."'" if ($i == 0);

        my $result = "Search results for '".$string."':\n";
        if ($i > 3) {
            for ($j = 0; $j <= 3; $j++) {
                $result .= "'" . $quotes[$j] . "'\n";
            }
            $result .= "(search returned too many results)\n";
            return $result;
        }
        for ($j = 0; $j < $i; $j++) {
            $result .= "'" . $quotes[$j] . "'\n";
        }
        $result =~ s/\Q\n\E/\n /ig;
        return $result;
    }
    
    if ($table eq 'all') {
        my $out = "Search results in quotes: ";
        $out .= bot_search("quotes ".$string);
        # The following line adds linebreak in case of no results
        $out =~ s/(No results for '$string')/$1\n/ig;
        $out .= "Search results in notes: ";
        $out .= bot_search("notes ".$string);
        $out =~ s/Search results for '$string'://ig;
        $out =~ s/\Q\n\E/\n /ig;
        return $out;
    }
}

## bot_uptime
# Returns current uptime of the bot
sub bot_uptime {
    return "Uptime: " . calc_diff(Anna::Utils::STARTTIME);
}

## bot_voice
# Takes two params (the hostmask of the user and the heap)
# Voices the user if setting is set.
sub bot_voice {
    my ($heap, $from) = @_;
    return "Error - no hostmask or heap supplied. This is likely a bug"
        unless (defined $heap && defined $from);

    my $c = new Anna::Config;
    my ($nick, $host) = split(/!/, $from);
    return "Error - you must authenticate first" unless defined $heap->{auth}->{$host};
    
    return "Error - Thou mvst remain voiceless" unless $c->get('voiceauth');
    $heap->{irc}->yield(mode => $c->get('channel') => "+v" => $nick);
    return;
}

## Err-routines
# We get these when the irc server returns a numeric 4xx error. Print it to the 
# user and react if nescessary

## err_nick_taken
# This gets called whenever a connection attempt returns '433' - nick taken.
# The subroutine swaps between several different nicks
sub err_nick_taken {
    my $c = new Anna::Config;
    my $newnick = $c->get('nick') . int(rand(100));
    irclog('status', sprintf "Nick taken, trying %s...", $newnick);
    verbose_print(sprintf("Nick taken, trying %s...", $newnick));
    $_[HEAP]->{irc}->yield(nick => $newnick);
    $_[HEAP]->{nickrecover} = 1;
    $c->set('oldnick' => $c->get('nick'));
    $c->set('nick' => $newnick);
}

## err_4xx_default
# Oh my... we tried to do someting we couldn't...
# Defaults handler for 4xx-errors. Everything we don't care about should go 
# through here
sub err_4xx_default {
    my $args = $_[ARG2];
    irclog('status' => sprintf "%s: %s", $args->[0], $args->[1]);
    warn_print(sprintf("%s: %s", $args->[0], $args->[1]));
}

## Handle subroutines
# These are the standard handle subroutines... nothing to see here, please move along

## on_324
# channelmodeis (refer to the rfc...)
sub on_324 {
    return if ($_[ARG2]->[1] eq '+'); # No modes set
    irclog('status' => sprintf "-!- Mode/%s %s", $_[ARG2]->[0], $_[ARG2]->[1]);
    verbose_print(sprintf("Mode/%s %s", colour($_[ARG2]->[0], 96), $_[ARG2]->[1]));
}

## on_329
# This signal contains the creation date of the channel as an epoch timestamp
sub on_329 {
    my $msg = $_[ARG2];
    irclog('status' => sprintf "-!- Channel %s created %s", $msg->[0], scalar localtime $msg->[1]);
    verbose_print(sprintf("Channel %s created %s", colour($msg->[0], 96), scalar localtime $msg->[1]));
}

## on_332
# This is the topic announcement we recieve whenever we join a channel
# ->[0] is the channel, ->[1] is the topic
sub on_332 {
    my $msg = $_[ARG2];
    irclog('status' => sprintf "-!- Topic for %s: %s", $msg->[0], $msg->[1]);
    verbose_print(sprintf("Topic for %s: %s", colour($msg->[0], '96'), $msg->[1]));
}

## on_333
# This numeric gives us the name of the person who sat the topic as well as the
# time he/she did that.
# ->[0] is the channel, ->[1] is the nick who sat the topic, ->[2] is the epoch
# timestamp the topic was set
sub on_333 {
    my $msg = $_[ARG2];
    irclog('status' => sprintf "-!- Topic set by %s [%s]", $msg->[1], scalar localtime $msg->[2]);
    verbose_print(sprintf("Topic set by %s [%s]", $msg->[1], scalar localtime $msg->[2]));
}

## on_namreply
# Whenever we join a channel the server returns irc_353. Print a list of users
# in the channel
sub on_namreply {
    return unless Anna::Config->new->get('verbose');
    my @args = @{$_[ARG2]};
    shift (@args); # discard the "="-sign
    my $channel = shift(@args);
    my @users = split(/ /, shift(@args));
    my $out = sprintf "[".colour('Users', 32)." %s]\n", colour($channel, 92);
    # FIXME: Do some automatic calculation instead of just printing in 
    # five rows
    my ($i, $j) = (0, 0);
    for ($i = 0; $i <= $#users; $i++) {
        $out .= sprintf "[%s] ", $users[$i];
        if ($j == 4) {
            $out .= sprintf "\n";
            $j = 0;
        } else {
            $j++;
        }
    }
    ## FIXME
#   irclog('status' => $out);
    verbose_print($out);
}

## on_msg
# This is called whenever the client recieves a privmsg. 
sub on_msg {
    my ($kernel, $heap, $from, $to, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my ($nick) = split(/!/, $from);

    # if this is a message from anna herself, send it to recipients log - 
    # else to sender's log
    irclog($nick => sprintf "<%s> %s", $nick, $msg);
    $heap->{seen_traffic} = 1;

    # Kill her own messages
    return if ($nick eq Anna::Config->new->get('nick'));

    my $out = parse_message($kernel, $heap, $from, $to, $msg, 'msg');
    
    # Return if there's nothing to print
    return unless defined $out;
    return if ($out eq 'FALSE'); 
    
    my @lines = split(/\n/, $out);
    foreach(@lines) {
        irclog($nick => sprintf "<%s> %s", $heap->{irc}->nick_name, $_);
        $heap->{irc}->yield(privmsg => $nick => $_);
        $heap->{irc}->yield(ctcp => Anna::Config->new->get('channel') => 'ACTION reloads...') if ($_ =~ /chamber \d of \d => \*bang\*/);
    }
}

## on_public
# This runs whenever someone post to a channel the bot is watching
sub on_public {
    my ($kernel, $heap, $from, $to, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my ($nick) = split(/!/, $from);
    my $c = new Anna::Config;
    
    irclog($to->[0] => sprintf "<%s> %s", $nick, $msg);
    $heap->{seen_traffic} = 1;

    # Kill her own messages
    return if ($nick eq $c->get('nick'));

    my $out = parse_message($kernel, $heap, $from, $to, $msg, 'public');
    return unless defined($out);
    return if ($out eq 'FALSE');


    # $to is the target recipients. On public
    # messages, this is where the reply should be 
    # sent to.
    my @lines = split(/\n/, $out);
    foreach(@lines) {
        irclog($to->[0] => sprintf "<%s> %s", $heap->{irc}->nick_name, $_);
        $heap->{irc}->yield(privmsg => $to => $_);
        if ($out =~ /chamber \d of \d => \*bang\*/) {
            $heap->{irc}->yield(kick => $c->get('channel') => $nick => "Bang! You die...");
            $heap->{irc}->yield(ctcp => $c->get('channel') => 'ACTION reloads...');
        }
    }
}

## on_notice
# This is for notices...
sub on_notice {
    my ($from, $msg) = @_[ARG0, ARG2];
    
    my $c = new Anna::Config;
    $_[HEAP]->{seen_traffic} = 1;
    # No ! should indicate server message
    if ($from !~ /!/) {
        irclog('status' => sprintf "!%s %s", $from, $msg);
        verbose_print(sprintf("%s %s", colour("!".$from, '92'), $msg)); 
        return;
    }

    my ($nick, $host) = split(/!/, $from);
    irclog($nick => sprintf "-%s(%s)- %s", $nick, $host, $msg);
    verbose_print(sprintf("-%s(%s)- %s", colour($nick, "95"), colour($host, '35'), $msg));
}


## on_connect
# This gets called whenever the script receives the event '376' - the 
# server code for "End of MOTD".
# on_connect takes responsibility for connecting to the appropriate channels
# and for negotiating with nickserv
sub on_connect {
    my $h = $_[HEAP];
    $h->{seen_traffic} = 1;
    my $irc = $h->{irc};
    my $c = new Anna::Config;
    
    # Should we recover out nick?
    if (defined $h->{nickrecover} && $h->{nickrecover} && $c->get('nspasswd')) {
        verbose_print "Nick taken. Reclaiming custody from services... ";
        $irc->yield(privmsg => 'nickserv' => "GHOST ".$c->get('oldnick')." ".$c->get('nspasswd'));
        $irc->yield(privmsg => 'nickserv' => "RECOVER ".$c->get('oldnick')." ".$c->get('nspasswd'));
        $irc->yield(nick => $c->get('oldnick'));
        $c->delete('oldnick');
    }
    
    if ($c->get('nspasswd')) {
        verbose_print "Identifying with services... ";
        $irc->yield(privmsg => 'nickserv' => "IDENTIFY ".$c->get('nspasswd'));
    }
    
    irclog('status' => sprintf "Joining %s", $c->get('channel'));
    verbose_print(sprintf("Joining %s...", $c->get('channel')));
    $irc->yield(mode => $c->get('nick') => '+i');
    $irc->yield(join => $c->get('channel'));
    $irc->yield(mode => $c->get('channel'));
#   $self->privmsg($server{'channel'}, "all hail your new bot");
}

## on_connected
# We recieve this once a connection is established. This does NOT mean the 
# server has accepted us yet, so we can't send anything
sub on_connected {
    my $kernel = $_[KERNEL];
    my $c = new Anna::Config;
    
    $_[HEAP]->{seen_traffic} = 1;
    $kernel->delay(autoping => 300);
    irclog('status' => sprintf "Connected to %s", $c->get('server'));
    verbose_print(sprintf("Connected to %s", $c->get('server')));
}

## on_join
# This is used when someone enters the channel. Use this for 
# auto-op'ing or welcome messages
sub on_join {
    my ($from, $channel) = @_[ARG0, ARG1];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $c = new Anna::Config;
    my $dbh = new Anna::DB;
    $h->{seen_traffic} = 1;

    # Update lastseen table
    if ($channel eq $c->get('channel')) {
        my ($query, $sth, $msg);
        
        $msg = $nick . " joined " . $channel;
        
        # Delete old record
        $query = "DELETE FROM lastseen WHERE nick = ?";
        $sth = $dbh->prepare($query);
        $sth->execute(lc($nick));

        $query = "INSERT INTO lastseen (nick, msg, time) 
            VALUES (?, ?, ".time.")";
        $sth = $dbh->prepare($query);
        $sth->execute(lc($nick), $msg);
    }

    irclog($channel => sprintf "-!- %s [%s] has joined %s", $nick, $host,
        $channel);
    verbose_print(sprintf("%s [%s] has joined %s", colour($nick, '96'), colour($host, '96'), $channel));
}

## on_kill
# This is called when you get killed. As it is followed by the standard 
# disconnect, don't sign up for a reconnect. ARG1 = $server{'nick'}
sub on_kill {
    my ($from, $reason) = @_[ARG0, ARG2];
    my ($user, $host) = split(/!/, $from);
    irclog('status' => sprintf "-!- You were killed by %s [%s] [%s]", $user, $host, $reason);
    warn_print(sprintf("You were %s by %s [%s] [%s]", colour('killed', 91), $user, $host, $reason));
}

## on_part
# This is called when someone leaves the channel
sub on_part {
    my ($from, $channel, $msg) = @_[ARG0, ARG1, ARG2];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $c = new Anna::Config;

    $h->{seen_traffic} = 1;
    # Update lastseen table
    if (lc $channel  eq lc $c->get('channel')) {
        my ($query, $sth, $ls_msg);
        
        if ($msg) {
            $ls_msg = $nick . " left from " . $channel . " stating '" . $msg . "'";
        } else {
            $ls_msg = $nick . " left from " . $channel . " with no reason";
        }
        
        my $dbh = new Anna::DB;
        # Delete old record
        $query = "DELETE FROM lastseen WHERE nick = ?";
        $sth = $dbh->prepare($query);
        $sth->execute(lc($nick));

        $query = "INSERT INTO lastseen (nick, msg, time) 
            VALUES (?, ?, ".time.")";
        $sth = $dbh->prepare($query);
        $sth->execute(lc($nick), $msg);
    }

    $msg ||= '';
    
    irclog($channel => sprintf "-!- %s has left %s [%s]", $nick, $channel, $msg);
    verbose_print(sprintf("%s has left %s [%s]", $nick, colour($channel, "96"), $msg));
}

## on_quit
# This signal is recieved when someone sends a QUIT notice (the disconnect)
sub on_quit {
    my ($from, $msg) = @_[ARG0, ARG1];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $dbh = new Anna::DB;

    $h->{seen_traffic} = 1;
    # Update lastseen table
    my ($query, $sth, $ls_msg);
    
    if ($msg) {
        $ls_msg = $nick . " quit IRC stating '" . $msg . "'";
    } else {
        $ls_msg = $nick . " quit IRC with no reason";
    }
    
    # Delete old record
    $query = "DELETE FROM lastseen WHERE nick = ?";
    $sth = $dbh->prepare($query);
    $sth->execute(lc($nick));
    $query = "INSERT INTO lastseen (nick, msg, time) 
        VALUES (?, ?, ".time.")";
    $sth = $dbh->prepare($query);
    $sth->execute(lc($nick), $ls_msg);
    $msg = '' if !defined($msg);

    irclog('status' => sprintf "%s (%s) has quit IRC [%s]", $nick, $host, $msg);
    verbose_print(sprintf("%s (%s) has quit IRC [%s]", $nick, $host, $msg));
}

## on_nick
# This gets called whenever someone on the channel changes their nickname
sub on_nick {
    my ($from, $newnick) = @_[ARG0, ARG1];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $c = new Anna::Config;
    my $dbh = new Anna::DB;
    $h->{seen_traffic} = 1;
    # Update lastseen table
    my ($query, $sth, $msg);
    
    # Delete old record
    $query = "DELETE FROM lastseen WHERE nick = ? OR nick = ?";
    $sth = $dbh->prepare($query);
    $sth->execute(lc($nick), lc($newnick));
    
    # Insert new record under old name
    $msg = $nick . " changed nick to " . $newnick;
    $query = "INSERT INTO lastseen (nick, msg, time) 
        VALUES (?, ?, ".time.")";
    $sth = $dbh->prepare($query);
    $sth->execute(lc($nick), $msg);

    # Insert new record under new name
    $msg = $newnick . " changed nick from " . $nick;
    $query = "INSERT INTO lastseen (nick, msg, time) 
        VALUES (?, ?, ".time.")";
    $sth = $dbh->prepare($query);
    $sth->execute(lc($newnick), $msg);
    
    # FIXME: find the channel in a supplied parameter to this function
    irclog($c->get('channel') => sprintf "-!- %s is now known as %s", $nick, $newnick);
    verbose_print(sprintf("%s is now known as %s", $nick, $newnick));
}

## on_topic
# How can we possibly be on-topic here? ;)
# This runs whenever the channel changes topic 
sub on_topic {
    my ($from, $channel, $topic) = @_[ARG0, ARG1, ARG2];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $c = new Anna::Config;

    $h->{seen_traffic} = 1;
    
    unless ($topic) {
        irclog($channel => sprintf "-!- Topic unset by %s on %s", $nick, $channel);
        verbose_print(sprintf("Topic unset by %s on %s", $nick, $channel));
        return;
    }
    
    irclog($channel => sprintf "-!- %s changed the topic of %s to: %s", $nick, $channel, $topic);
    verbose_print(sprintf("%s changed the topic of %s to: %s", $nick, $channel, $topic));
}


## on_mode
# This gets called when channel modes are changed.
sub on_mode {
    my ($from, $to, $mode, $operands) = @_[ARG0, ARG1, ARG2, ARG3];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $c = new Anna::Config;

    $h->{seen_traffic} = 1;
    $mode .= " ".$operands if ($operands);

    if (lc $to eq lc $c->get('nick')) {
        irclog('status' => sprintf "-!- Mode change [%s] for user %s", $mode, $nick);
        verbose_print(sprintf("Mode change [%s] for user %s", $mode, $nick));
        return;
    }
    irclog($to => sprintf "-!- Mode/%s [%s] by %s", $to, $mode, $nick);
    verbose_print(sprintf("Mode/%s [%s] by %s", colour($to, "96"), $mode, $nick));
}

## on_disconnected
# This gets called whenever we get disconnected from a server. Will
# attempt to reconnect after sleeping for five seconds
sub on_disconnected {
    my ($kernel, $server) = @_[KERNEL, ARG0];

    irclog('status' => sprintf "-!- Disconnected from %s", $server);
    warn_print(sprintf("Disconnected from %s", $server));
    $kernel->yield("reconnect");
}

## on_error
# We get this whenever we recieve an error, usually followed by a dropping of 
# the connection. Print message and reconnect
sub on_error {
    my ($kernel, $error) = @_[KERNEL, ARG0];
    irclog('status' => sprintf "-!- ERROR: %s", $error);
    error_print($error);
}

## on_socketerr
# This is for whenever we fail to establish a connection. But let's try again!
sub on_socketerr {
    my ($kernel, $error) = @_[KERNEL, ARG0];
    my $h = $_[HEAP];
    my $c = new Anna::Config;

    irclog('status' => sprintf "-!- Failed to establish connection to %s: %s", $c->get('server'), $error);
    error_print(sprintf("Failed to establish connection to %s: %s", $c->get('server'), $error));
    $kernel->yield("reconnect");
}

## on_kick
# Whenever someone (possibly yourself) recieves a kick, this is run.
sub on_kick {
    my ($from, $channel, $to, $msg) = @_[ARG0, ARG1, ARG2, ARG3];
    my ($nick, $host) = split(/!/, $from);
    my $h = $_[HEAP];
    my $c = new Anna::Config;

    $h->{seen_traffic} = 1;

    if ($to eq $h->{irc}->nick_name) {
        # We were kicked...
        irclog('status' => sprintf "-!- Recieved KICK by %s from %s [%s]", $nick, $channel, $msg);
        warn_print(sprintf("Recieved KICK by %s from %s [%s]", $nick, $channel, $msg));
        return;
    }

    irclog('status' => sprintf "-!- %s was kicked from %s by %s [%s]", $to, $channel, $nick, $msg);
    verbose_print(sprintf("%s was kicked from %s by %s [%s]", colour($to, '96'), $channel, $nick, $msg));
}

## ABORT
# Trap routine for SIGINT.
# Params: N/A
# Return: N/A
sub ABORT {
    irclog('status' => sprintf "-!- Log closed %s", scalar localtime);
    print "Caught Interrupt (^C), Aborting\n";
    # Messy as hell, but fast!
    exit(1);
}

__END__

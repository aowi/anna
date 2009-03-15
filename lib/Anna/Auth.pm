# vim: set expandtab:tabstop=4:shiftwidth=4
package Anna::Auth;
use strict;
use warnings;

use Anna::DB;
use Anna::Utils;
use POE; 

=head1 NAME

Anna::Auth - authentication and user management for the Anna^ IRC Bot

=head1 SYNOPSIS

Anna::Auth is responsible for handling addition of new users and modification
of existing users as well as identification and permissions.

=head1 DESCRIPTION

IRC users have the option of registering with Anna^ for added value. 
Registration makes it possible to allow each user to maintain "personal info",
it enables Anna^ to grant different users permission to do certain things, most
importantly, it is used to identify the owner of the bot.

Rather than using this module directly, a number of core bot modules exists
such as the auth.pl module, for managing users. Any bot module can then use
this perl module to check for correct permissions before accepting commands
from users. A bot module for managing a channel topic could test if a user
has the 'channel::settopic' permission before allowing said user to change 
the topic.

Any bot module can test for permissions, add permission types and classes to
the system and modify existing permission types. There is no "internal 
security".

=head1 CONSTRUCTORS

In order to use Anna::Auth you will need an Auth-object. There is currently 
only one way to obtain it.

=over

=cut
my %auth = ();

=item new()

Returns a new Anna::Auth object. Doesn't take any arguments.

=cut
sub new {
    return bless {}, shift;
}

=back

=head1 METHODS

These are the methods supported by the Anna::Auth object.

=over

=item identify()

Takes four arguments: 

=over

=item The username (not the IRC name of the user, but the name the user wishes
to identify with)

=item The user's password (cleartext)

=item The user's nickname. This is the nickname the user has on the IRC server

=item The user's host. This is the entire host including the username (ie. user@host)

=back

Returns 1 upon succesful identification (ie. the user is now "logged in").

Returns 0 in case of error and sets an appropriate error message.

=cut
sub identify {
    my ($self, $user, $pass, $nick, $host) = @_;

    my $query = "SELECT * FROM users WHERE username = ?";
    my $sth = Anna::DB->new->prepare($query);
    $sth->execute($user);
    if (my @row = $sth->fetchrow()) {
        if (crypt($pass, substr($row[2], 0, 2)) eq $row[2]) {
            # We have a match! Light it
            $auth{$host} = { user => $user, nick => $nick };
            debug_print(sprintf("Nick %s [%s] successfully identified as %s", $nick, $host, $user));
            return 1;
        }
    }
    $self->{_errstr} = "Error: Invalid username or password";
    debug_print(sprintf("Nick %s [%s] failed identificatation as %s", $nick, $host, $user));
    return 0;
}

=pod

=item register()

Takes two parameters:

=over

=item A username

=item A password (in cleartext)

=back

Returns 1 upon successful user creation.

Returns 0 in case of any error and also sets an appropriate (human readable) 
error message that can be accessed with the errstr() method. 

=cut
sub register {
    my ($self, $user, $pass) = @_;
    
    unless (defined $user && defined $pass) {
        $self->{_errmsg} = "Error: you must supply a username and a password";
        return 0;
    }
    
    my $dbh = new Anna::DB;
    my $query = "SELECT id FROM users WHERE username = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($user);
    if ($sth->fetchrow) {
        $self->{_errmsg} = "Error: username already exists";
        return 0;
    }
    
    $query = "INSERT INTO users (username, password) VALUES (?, ?)";
    $sth = $dbh->prepare($query);
    my @salt_chars = ('a'..'z','A'..'Z','0'..'9');
    my $salt = $salt_chars[rand(63)] . $salt_chars[rand(63)];
    $sth->execute($user, crypt($pass, $salt));
    return 1;
}

=pod

=item errstr()

Takes no parameters. Returns the last error message (if any) or undefined if
no errors have occured yet.

=cut
sub errstr {
    my $self = shift;
    defined ($self->{_errmsg}) ?
        return $self->{_errmsg} : return undef;
}

=pod

=item add_user_to_role()

NOT YET IMPLEMENTED

=cut
sub add_user_to_role {}

=pod

=item user_can()

NOT YET IMPLEMENTED

=cut
sub user_can {}

=pod

=item host2user()

Takes one parameter - a host (user@host). 

Returns the associated username for the bot if the user@host is currently
identified.

Returns 0 if the user isn't identified and sets an appropriate error 
message (see errstr())

=cut
sub host2user {
    my ($self, $host) = @_;
    if (exists $auth{$host}) {
        return $auth{$host};
    } else {
        $self->{_errmsg} = sprintf "Error: not identified";
        return 0;
    }
}

=pod

=back

=head1 BUGS 

Some functions not yet implemented

All bugs should be reported to the author of the Anna^ IRC Bot

=head1 AUTHOR

Anders Ossowicki <and@vmn.dk>

=head1 LICENCE 

Copyright (c) 2008-2009 Anders Ossowicki.

Released under the terms of the GNU General Public License v2

=head1 SEE ALSO

The documentation for the Anna^ IRC Bot, available on 
L<http://frokostgruppen.dk/~arkanoid/anna>

=cut

1;

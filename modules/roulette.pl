use strict;
use warnings;
# vim: et:sw=3:ts=3

use Anna::Module;

my $m = new Anna::Module 'roulette';

$m->bindcmd('roulette', 'roulette');
$m->bindcmd('rstats', 'stats');
$m->bindcmd('reload', 'reload');

sub roulette {
    my $nick = $_[NICK];
    
    my ($shot, $hit, $out);

    my $query = "SELECT * FROM roulette_shots";
    my $sth = $m->db->prepare($query);
    $sth->execute();
    my @row;
    if (@row = $sth->fetchrow()) {
        $shot = $row[0];
        $hit = $row[1];
    } else {
        $shot = 0;
        $hit = int(rand(6));
        $hit = 6 if ($hit == 0);
    }
    $shot += 1;
    $query = "DELETE FROM roulette_shots";
    $sth = $m->db->prepare($query);
    $sth->execute();
    if ($shot == $hit) {
        # Bang, you're dead
        $out = "chamber " . $shot . " of 6 => *bang*";
        $shot = 0;
        reload();
    } else {
        $out = "chamber " . $shot . " of 6 => *click*";
        $query = "INSERT INTO roulette_shots (shot, hit) 
              VALUES (?, ?)";
        $sth = $m->db->prepare($query);
        $sth->execute($shot, $hit);
    }
    
    # Update roulette_stats
    $query = "SELECT * FROM roulette_stats WHERE user = ?";
    $sth = $m->db->prepare($query);
    $sth->execute($nick);
    if (@row = $sth->fetchrow()) {
        # Update
        if ($out =~ /\*bang\*/) {
            # User is dead
            $query = "UPDATE roulette_stats SET shots = ?, hits = ?, deathrate = ?, liverate = ? 
                  WHERE user = ?";
            $sth = $m->db->prepare($query);
            $sth->execute($row[2] + 1, $row[3] + 1, sprintf("%.1f", (($row[3] + 1) / ($row[2] + 1)) * 100), sprintf("%.1f", (100 - ((($row[3] + 1) / ($row[2] + 1)) * 100))), $nick);
        } else {
            # User lives
            $query = "UPDATE roulette_stats SET shots = ?, deathrate = ?, liverate = ?
                  WHERE user = ?";
            $sth = $m->db->prepare($query);
            $sth->execute($row[2] + 1, sprintf("%.1f", (($row[3] / ($row[2] + 1)) * 100)), sprintf("%.1f", (100 - (($row[3] / ($row[2] + 1)) * 100))), $nick);
        }
    } else {
        # Insert
        if ($out =~ /\*bang\*/) {
            # User is dead
            $query = "INSERT INTO roulette_stats (user, shots, hits, deathrate, liverate)
                  VALUES (?, ?, ?, ?, ?)";
            $sth = $m->db->prepare($query);
            $sth->execute($nick, 1, 1, 100, 0);
        } else {
            # User lives
            $query = "INSERT INTO roulette_stats (user, shots, hits, deathrate, liverate)
                  VALUES (?, ?, ?, ?, ?)";
            $sth = $m->db->prepare($query);
            $sth->execute($nick, 1, 0, 0, 100);
        }
    }

    $m->irc->reply_hilight($out);
}

sub stats {
    
    # Most hits
    my $dbh = $m->db;
    my $query = "SELECT * FROM roulette_stats ORDER BY hits DESC LIMIT 1";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @row;
    my $most_hits;
    if (@row = $sth->fetchrow()) {
        $most_hits = $row[1] . " (".$row[3]." hits)";
    } else {
        $m->irc->reply("You haven't played any roulette yet!");
        return;
    }

    # Most shots
    $query = "SELECT * FROM roulette_stats ORDER BY shots DESC LIMIT 1";
    $sth = $dbh->prepare($query);
    $sth->execute();
    @row = $sth->fetchrow();
    my $most_shots = $row[1] . " (".$row[2]." shots)";

    # Highest deathrate
    $query = "SELECT * FROM roulette_stats ORDER BY deathrate DESC LIMIT 1";
    $sth = $dbh->prepare($query);
    $sth->execute();
    @row = $sth->fetchrow();
    my $highest_deathrate = $row[1] . " (".$row[4]."%)";

    # Highest liverate
    $query = "SELECT * FROM roulette_stats ORDER BY liverate DESC LIMIT 1";
    $sth = $dbh->prepare($query);
    $sth->execute();
    @row = $sth->fetchrow();
    my $highest_liverate = $row[1] . " (".$row[5]."%)";
    
    $m->irc->reply("Roulette stats: Most shots - ".$most_shots.". Most hits - ".$most_hits.". Highest deathrate - ".$highest_deathrate.". Highest survival rate - ".$highest_liverate.".");
}


sub reload {
    my $query = "DELETE FROM roulette_shots";
    $m->db->do($query);
    $m->irc->action('reloads...');
}

sub init {
   $m->db->do(q(
      CREATE TABLE IF NOT EXISTS roulette_shots (shot INTEGER, hit INTEGER)
   ));
   $m->db->do(q(
      CREATE TABLE IF NOT EXISTS roulette_stats 
         (
          id INTEGER PRIMARY KEY UNIQUE,
          user TEXT UNIQUE,
          shots INTEGER,
          hits INTEGER,
          deathrate TEXT,
          liverate TEXT
         )
   ));
}

1;

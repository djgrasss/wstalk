#!/usr/bin/perl
# WStalk
# Position estimator
# Oona Räisänen 2012
use warnings;
use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ":utf8");
$|++;

use DBI;
print "read database .. ";
my $dbh = DBI->connect("dbi:SQLite:dbname=ratio.sqlite","","",
  {
    RaiseError     => 1,
    sqlite_unicode => 1,
    AutoCommit     => 1
  }
);

# Read config
open(SIS,"wstalk.cfg") or die("Unable to read config ($!)");
for (<SIS>) {
  chomp;
  $conf{$1} = $2 if (/^(\S+)\s+(.+)/);
}
close(SIS);

$conf{'Device'} = "wlan0" unless (($conf{'Device'} // "") =~ /^[a-z0-9_\.-]+$/i);
$dev = $conf{'Device'};


# Read names of locations
$sth = $dbh->prepare("SELECT * FROM Locations");
$sth->execute();
$pnimet[$row[0]] = $row[1] while ( @row = $sth->fetchrow_array );

$sth = $dbh->prepare("SELECT * FROM AccessPoints");
$sth->execute();
$smacs[$row[0]] = $row[1] while ( @row = $sth->fetchrow_array );
@smacs = sort @smacs;

# Read radio map
$sth = $dbh->prepare("SELECT * FROM Ratios");
$sth->execute();

while ( @row = $sth->fetchrow_array ) {
  ($a,$b,$paikka) = ($row[0],$row[1],$row[2]);
  ($mean{$paikka}{$smacs[$a]}{$smacs[$b]}, $sdev{$paikka}{$smacs[$a]}{$smacs[$b]}) = ($row[3],$row[4]);
}

print "ok\n";

while (1) {
  print "scan .. ";

  %qua = ();
  @pr = ();

  # Scan for nearby APs
  for (0 .. 1) {
    for (`gksudo iwlist $dev scan`) {
      $adr       = $1 if (/^\s+Cell \d+ - Address: (\S+)/);
      if (/^\s+Quality=(\d+)/ && defined $adr) {
        if (exists $qua{$adr}) {
          # Average
          $qua{$adr} = ($qua{$adr} + $1) / 2;
        } else {
          $qua{$adr} = $1;
        }
      }
    }
  }

  print "got ".scalar(keys %qua)." APs\n";

  if (scalar keys %qua < 2) {
    print "can't work with < 2 access points\n";
    next;
  }

  print "\n";

  # Generate UTC timestamp
  #@ctime     = gmtime(time);
  #$timestamp = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
  #  $ctime[5]+1900,$ctime[4]+1,$ctime[3],$ctime[2],$ctime[1],$ctime[0]);

  # Compare the scan results with all mapped locations
  $mostprob = $leastprob = $mostincommon = 0;
  for $paikka (sort { $a <=> $b } keys %mean) {
    $prob = 1;
    %incommon = ();
    #print "\n";
    for $a (0..$#smacs-1) {
      for $b ($a+1..$#smacs) {
        if (exists ($qua{$smacs[$a]}) &&
            exists ($qua{$smacs[$b]}) &&
            exists ($mean{$paikka}{$smacs[$a]}{$smacs[$b]})) {
          $incommon{$a} = $incommon{$b} = 1;
          ($m, $s) = ($mean{$paikka}{$smacs[$a]}{$smacs[$b]}, $sdev{$paikka}{$smacs[$a]}{$smacs[$b]});
          $nlr = log( $qua{$smacs[$a]} / $qua{$smacs[$b]} ) - log(1/71);
          $p   = .01 + 1/($s*sqrt(2*3.141592653589793)) * exp( -(($nlr-$m)**2)/ (2*($s**2)));
          $prob *= $p;
        } else {
          $prob *= 0.985;
          #print " $smacs[$a] x $smacs[$b] not in scan\n";
        }
      }
    }
    $totincommon[$paikka] = scalar keys %incommon;
    $mostincommon = $totincommon[$paikka] if ($totincommon[$paikka] > $mostincommon);
    $pr[$paikka] = $prob;
  }
 
  # If place has less than half the max number of common APs, prob=0
  for $paikka (sort { $a <=> $b } keys %mean) {
    $pr[$paikka] = 0 if ($totincommon[$paikka] < 0.5 * $mostincommon || $totincommon[$paikka] < 2);
    $mostprob  = $paikka if ($pr[$paikka] > $pr[$mostprob]);
    $leastprob = $paikka if (($pr[$paikka] < $pr[$leastprob] && $pr[$paikka] > 0) || $pr[$leastprob] == 0);
  }

  system("clear");

  print "Hearing ".scalar(keys(%qua))." APs\n";

  print ("┌".("─" x 30)."┐\n");
  for $paikka (sort { $a <=> $b } keys %mean) {

    print "│";
    if ($pr[$mostprob] == 0 || $pr[$paikka] == 0) {
      $BarLen = 0;
    } elsif ($paikka == $mostprob) {
      $BarLen = 30;
    } elsif ($pr[$leastprob] == 0) {
      $BarLen = log10($pr[$paikka]);
    } else {
      $BarLen = sprintf("%.0f", ((log10($pr[$paikka])   - log10($pr[$leastprob])) /
                                 (log10($pr[$mostprob]) - log10($pr[$leastprob])))
                                 * 30);
      $BarLen = 1 if ($BarLen == 0);
    }
    print (("═" x $BarLen).(" " x (30 - $BarLen)).("│  "));
    printf("%-10.3e %3d $pnimet[$paikka]\n",$pr[$paikka], $totincommon[$paikka]);
  }
  print ("└".("─" x 30)."┘\n");

  if ($pr[$mostprob] > 0) {
    print "\nwe're in: --> $pnimet[$mostprob] <--\n";
  } else {
    print "\n[we're outside map range]\n";
  }
}

sub log10 {
  return log($_[0])/log(10);
}

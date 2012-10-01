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
open(SIS,"good-essids");
for (<SIS>) {
  chomp;
  $good_essid{$_} = 1;
}
close(SIS);
open (SIS,"ex-paikat.csv");
for (<SIS>) {
  chomp;
  ($n,$p,$map,$x,$y) = split(/,/,$_);
  $pnimi[$n] = $p;
  $pmap[$n] = $map;
  $pmapx[$n] = $x;
  $pmapy[$n] = $y;
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
  ($mean{$paikka}{$smacs[$a]}{$smacs[$b]}, $sdev{$paikka}{$smacs[$a]}{$smacs[$b]})
    = ($row[3],$row[4]);
}

print "ok\n";

while (1) {
  print "scan .. ";

  %qua = ();
  @pr = ();

  # Scan for nearby APs

  for (0 .. 1) {
    for (`sudo iwlist $dev scan`) {
      chomp;
      $adr       = $1 if (/^\s+Cell \d+ - Address: (\S+)/);
      $essid     = $1 if (/^\s+ESSID:"(.*)"$/);
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

  # Compare the scan results with all mapped locations

  $mostprob = $leastprob = $mostincommon = 0;
  for $paikka (sort { $a <=> $b } keys %mean) {
    $prob = 1;
    %incommon = ();
    for $a (0..$#smacs) {
      if ($a == $#smacs) {
        $b = 0;
      } else {
        $b = $a + 1;
      }
      if (exists ($qua{$smacs[$a]}) &&
          exists ($qua{$smacs[$b]}) &&
          exists ($mean{$paikka}{$smacs[$a]}{$smacs[$b]})) {
        $incommon{$a} = $incommon{$b} = 1;
        ($m, $s) = ($mean{$paikka}{$smacs[$a]}{$smacs[$b]},
                    $sdev{$paikka}{$smacs[$a]}{$smacs[$b]});
        $nlr = log( $qua{$smacs[$a]} / $qua{$smacs[$b]} ) - log(1/71);
        $p   = .01 + 1/($s*sqrt(2*3.141592653589793)) * exp( -(($nlr-$m)**2)/ (2*($s**2)));
        $prob *= $p;
      } else {
        $prob *= 0.2;
      }
    }
    $totincommon[$paikka] = scalar keys %incommon;
    $mostincommon = $totincommon[$paikka] if ($totincommon[$paikka] > $mostincommon);
    $pr[$paikka] = $prob;
  }
 
  # If place has less than half the max number of common APs, prob=0

  for $paikka (sort { $a <=> $b } keys %mean) {
    $pr[$paikka] = 0 if ($totincommon[$paikka] < 0.5 * $mostincommon ||
      $totincommon[$paikka] < 2);
    $mostprob  = $paikka if ($pr[$paikka] > $pr[$mostprob]);
    $leastprob = $paikka if (($pr[$paikka] < $pr[$leastprob] && $pr[$paikka] > 0) ||
      $pr[$leastprob] == 0);
  }

  system("clear");

  print "Hearing ".scalar(keys(%qua))." APs\n";

  # Print bar graph of probabilities

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
    $b[$paikka] = $BarLen;
    print (("═" x $BarLen).(" " x (30 - $BarLen)).("│  "));
    printf("%-10.3e %3d $pnimet[$paikka]\n",$pr[$paikka], $totincommon[$paikka]);
  }
  print ("└".("─" x 30)."┘\n");

  # Report our location

  if ($pr[$mostprob] > 0) {
    ($sc,$mn,$hr,$dy,$qqk,$yr,$wday,$ydat,$isdst) = localtime();
    print "\nwe're in: --> $pnimet[$mostprob] <--\n";
    system("convert -size 867x650 ".$pmap[$mostprob].".png -draw \"image over ".
           ($pmapx[$mostprob]-39).",".($pmapy[$mostprob]-39).
           " 77,77 'dot.png'\" -fill black -undercolor red -draw \"text ".($pmapx[$mostprob]+39).",".($pmapy[$mostprob]-29)." \'windytan\n$pnimet[$mostprob]\n".sprintf("%04d-%02d-%02d %02d:%02d",$yr+1900,$qqk+1,$dy,$hr,$mn)."\'\" where-doton.png");
    system("convert -delay 60 -size 867x650 $pmap[$mostprob].png where-doton.png where-t.gif");
    system("mv where-t.gif where.gif");
    print "done\n";
  } else {
    print "\n[we're outside map range]\n";
  }
}

sub log10 {
  return log($_[0])/log(10);
}

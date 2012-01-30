#!/usr/bin/perl
# WStalk
# Position estimator
# Oona Räisänen 2012
use warnings;
use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ":utf8");

use DBI;
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

print "reading databases\n";

# Read names of locations
$sth = $dbh->prepare("SELECT * FROM LocNames");
$sth->execute();
$pnimet[$row[0]] = $row[1] while ( @row = $sth->fetchrow_array );

# Read radio map
$sth = $dbh->prepare("SELECT * FROM Ratios");
$sth->execute();

while ( @row = $sth->fetchrow_array ) {
  ($a,$b,$paikka) = ($row[0],$row[1],$row[2]);
  ($mean{$paikka}{$a}{$b}, $sdev{$paikka}{$a}{$b}, $n) = ($row[3],$row[4],$row[5]);
}

print "scanning\n";

# Scan for nearby APs
for (`gksudo iwlist $dev scan`) {
#for (`cat scan`) {
  $adr       = $1 if (/^\s+Cell \d+ - Address: (\S+)/);
  $qua{$adr} = $1 if (/^\s+Quality=(\d+)/ && defined $adr);
}

print "got ".scalar(keys %qua)."\n";

die if (scalar keys %qua == 0);

# Generate UTC timestamp
@ctime     = gmtime(time);
$timestamp = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
  $ctime[5]+1900,$ctime[4]+1,$ctime[3],$ctime[2],$ctime[1],$ctime[0]);

# Compare the scan results with all mapped locations
$n = 0;
@smacs = sort keys %{$mean{0}};

$mostprob = 0;
for $paikka (sort { $a <=> $b } keys %mean) {
  $prob = 1;
  $incommon = 0;
  #print "\n";
  for $a (0..$#smacs-1) {
    for $b ($a+1..$#smacs) {
      if (exists ($qua{$smacs[$a]}) && exists ($qua{$smacs[$b]})) {
        $incommon ++;
        #print "$qua{$smacs[$a]} v. $qua{$smacs[$b]}: ";
        ($m, $s) = ($mean{$paikka}{$smacs[$a]}{$smacs[$b]}, $sdev{$paikka}{$smacs[$a]}{$smacs[$b]});
        #print "mean $m sdev $s\n";
        $nlr = log( $qua{$smacs[$a]} / $qua{$smacs[$b]} ) - log(1/71);
        #print "  nlr = $nlr\n";
        $p   = .01 + 1/sqrt(2*3.141592653589793*($s**2)) * exp( -(($nlr-$m)**2)/ (2*($s**2)));
        #$p   = .01 + exp( -(($nlr-$m)**2)/ (2*($s**2)));
        #print "  p = $p\n";
        $prob *= $p;
        #print "  prob = $prob\n";
      } else {
        #print " $smacs[$a] x $smacs[$b] not in scan\n";
      }
    }
  }
  $prob = 0 if ($incommon < 3);
  printf( "%03d: %f\n",$paikka,$prob);
  $pr[$paikka] = $prob;
  $mostprob = $paikka if ($prob > $pr[$mostprob]);
}

if ($pr[$mostprob] > 0) {
  print "\n$pnimet[$mostprob]\n";
} else {
  print "\n[outside map range]\n";
}

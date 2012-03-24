#!/usr/bin/perl
use warnings;
binmode(STDIN, ":utf8");
use DBI;

unlink("ratio.sqlite");
my $dbh = DBI->connect("dbi:SQLite:dbname=ratio.sqlite","","",
  {
    RaiseError     => 1,
    sqlite_unicode => 1,
    AutoCommit     => 1
  }
);
$dbh->do("PRAGMA synchronous = OFF");

# Database initialization
$sth = $dbh->prepare(q{
  CREATE TABLE Locations (id INTEGER, name TEXT)
});
$sth->execute();

$sth = $dbh->prepare(q{
  CREATE TABLE AccessPoints (id INTEGER, mac TEXT)
});
$sth->execute();

$sth = $dbh->prepare(q{
  CREATE TABLE Ratios (location INTEGER, ap1 INTEGER, ap2 INTEGER, expected REAL, sdev REAL)
});
$sth->execute();

while (<>) {
  ($pvm,$klo,$paikka,$mac,$dbm) = split(/,/);
  $paikka =~ s/"//g;
  # Pack the address string
  #$mac = join("",map {chr(hex($_))} split(/:/,$mac));
  $macs{$mac} = 1;
  $rss{$paikka}{$pvm.$klo}{$mac} = $dbm + 111;
}

@paikat = sort keys %rss;
$dbh->begin_work;
for (0..$#paikat) {
  $sth = $dbh->prepare(q{
    INSERT INTO Locations VALUES ( ?, ? )
  });
  $sth->execute($_, $paikat[$_]);
  $pnum{$paikat[$_]} = $_;
}
$dbh->commit;

@macs = sort keys %macs;
$dbh->begin_work;
for (0..$#macs) {
  $sth = $dbh->prepare(q{
    INSERT INTO AccessPoints VALUES ( ?, ? )
  });
  $sth->execute($_, $macs[$_]);
}
$dbh->commit;

# Ratios
for $paikka (@paikat) {
  for $klo (keys %{$rss{$paikka}}) {
    for $a (0..$#macs-1) {
      for $b ($a+1..$#macs) {
        if (exists ($rss{$paikka}{$klo}{$macs[$a]}) && exists ($rss{$paikka}{$klo}{$macs[$b]})) {
          $suhe = log($rss{$paikka}{$klo}{$macs[$a]} / $rss{$paikka}{$klo}{$macs[$b]}) - log(1/71);
          push(@{$suhteet{$paikka}{$macs[$a]}{$macs[$b]}}, $suhe);
        }
      }
    }
  }
}

# Gaussian parameters
$dbh->begin_work;
for $a (0..$#macs-1) {
  for $b ($a+1..$#macs) {
    for $paikka (@paikat) {
      if (exists($suhteet{$paikka}{$macs[$a]}{$macs[$b]})) {
        $m = mean(@{$suhteet{$paikka}{$macs[$a]}{$macs[$b]}});
        $s =   sd(@{$suhteet{$paikka}{$macs[$a]}{$macs[$b]}});
        $s = .1 if ($s == 0);
        $sth = $dbh->prepare(q{
          INSERT INTO Ratios VALUES ( ?, ?, ?, ?, ? )
        });
        $sth->execute($a,$b,$pnum{$paikka},$m,$s);
      } else {
        # Default parameters for missing values
        #$m = 100;
        #$s =  .1;
      }
    }
  }
}
$dbh->commit;



sub mean {
  my $sum = 0;
  $sum += $_ for (@_);
  $sum /= scalar @_;
  $sum;
}

sub sd {
  my $me = mean(@_);
  my @devs = ();
  for (@_) {
    push (@devs, ($_ - $me) ** 2);
  }
  return sqrt(mean(@devs));
}

#!/usr/bin/perl
use warnings;
use open ':encoding(utf8)';
binmode(STDIN, ":utf8");
use IO::Select;

$s = IO::Select->new();
$s->add(\*STDIN);

# Read ESSIDs
open(SIS,"essid.csv");
for (<SIS>) {
  chomp;
  $essid{$1} = $2 if (/^([^,]+),(.+)/);
}
close(SIS);


open(UL,">>raw_recorded.csv");
while (1) {
  $i=0;
  print "Next location (empty quits)? ";
  chomp($loc = <STDIN>);
  last if ($loc eq "");
  $loc = "\"$loc\"";
  while (1) {
    %qua = %lastb = ();
    $adr = 0;
    $i++;
    printf( "%3d: ",$i);

    # Scan for APs
    for (`gksudo iwlist wlan0 scan`) {
      $adr         = $1 if (/^\s+Cell \d+ - Address: (\S+)/);
      $qua{$adr}   = $1-110 if (/^\s+Quality=(\d+)/);
      $lastb{$adr} = $1 if (/^\s+Extra: Last beacon: (\d+)ms/);
      $essid{$adr} = $1 if (/^\s+ESSID:"(.*)"/);
    }

    # Nothing found
    if (scalar keys %qua == 0) {
      print "?\n";
      $i--;

    } else {
      print "*" x scalar(keys %qua);
      print "\n";
      @ctime = localtime(time);
      $date = sprintf("%04d-%02d-%02d,%02d:%02d:%02d",
        $ctime[5]+1900,$ctime[4]+1,$ctime[3],$ctime[2],$ctime[1],$ctime[0]);
      for $adr (keys %qua) {
        print UL "$date,$loc,$adr,$qua{$adr}\n";
      }
    }

    # Enter in stdin terminates
    last if ($s->can_read(5));
  }
  $a = <STDIN>;
}
close(UL);

# Save ESSIDs
open(UL,">essid.csv");
print UL "$_,$essid{$_}\n" for (keys %essid);
close(UL);

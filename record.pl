#!/usr/bin/perl
# Oona Räisänen 2012
use warnings;
use 5.010;
use open ':encoding(utf8)';
binmode(STDIN, ":utf8");

use Config::Simple;
use XML::Simple qw(:strict);

# Read device from config
Config::Simple->import_from('wstalk.cfg', \%conf)
   or die ("Unable to read config ($!)");

$conf{'Device'} = "wlan0" unless (($conf{'Device'} // "") =~ /^[a-z0-9_\.-]+$/);
$dev = $conf{'Device'};

print "Select file:\n";
$n = 0;
print "0) NEW\n";
for (<*.xml>) {
  if (`grep wifiscan $_`) {
    $n++;
    push(@filelist,$_);
    print "$n) $_\n";
  }
}

print "\n? ";

chomp($choice = <STDIN>);

if ($choice == 0) {
  print "New filename (without extension): ";
  chomp($fn = <STDIN>);
  $fn .= ".xml";
  if (-e $fn) {
    print "Overwrite $fn? [y/N] ";
    chomp($a = <STDIN>);
    if ($a =~ /^y/i) {
      &writexml;
    } else {
      ...
    }
  } else {
    &writexml;
  }

  $scan = XMLin($fn,
    KeyAttr    => { "loc" => "id", "ap" => "mac" },
    ForceArray => [ "loc", "ap" ]) or die ("Unable to read map ($!)");

  $maxid = 0;
} else {
  $fn = $filelist[$choice-1];
  $scan = XMLin($fn,
    KeyAttr    => { "loc" => "id", "ap" => "mac" },
    ForceArray => [ "loc", "ap" ]) or die ("Unable to read map ($!)");
  $maxid = 0;
  for (keys %{$scan->{loc}}) {
    $maxid = $_ if ($_ > $maxid);
  }
}

while (1) {
  print "Press enter to initiate scan, ^C to terminate\n";
  $a = <STDIN>;
  $adr = 0;
  %qua = ();
  print "Scanning ... ";
  for (`gksudo iwlist $dev scan`) {
    $adr       = $1 if (/^\s+Cell \d+ - Address: (\S+)/);
    $qua{$adr} = $1 if (/^\s+Quality=(\d+)/);
  }
  if (scalar keys %qua == 0) {
    print "No APs could be heard\n";
  } else {
    print "Found ".scalar(keys %qua)." APs\n";
    print "Describe this location (empty string cancels): ";
    chomp($a = <STDIN>);
    if ($a eq "") {
      print "Nothing was saved\n";
    } else {
      $maxid++;
      @ctime = gmtime(time);
      for (keys %qua) {
        $scan->{loc}->{$maxid}->{ap}->{$_}->{q} = $qua{$_};
        $scan->{loc}->{$maxid}->{desc} = $a;
        $scan->{loc}->{$maxid}->{date} = 
          sprintf("%04d-%02d-%02d", $ctime[5]+1900,$ctime[4]+1,$ctime[3]);
      }
      &writexml;
    }
  }
}

sub writexml {
  open(UL,">$fn") or die ($!);
  print UL "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<wifiscan>\n";
  for $loc (keys %{$scan->{loc}}) {
    $desc = $scan->{loc}->{$loc}->{desc};
    $desc =~ s/&/&amp;/g;
    $desc =~ s/"/&quot;/g;
    print UL "  <loc id=\"$loc\" desc=\"$desc\" date=\"".
      $scan->{loc}->{$loc}->{date}."\">\n";
    for $ap (keys %{$scan->{loc}->{$loc}->{ap}}) {
      print UL "    <ap mac=\"$ap\" q=\"".$scan->{loc}->{$loc}->{ap}->{$ap}->{q}.
        "\"/>\n";
    }
    print UL "  </loc>\n";
  }
  print UL "</wifiscan>\n";
  close(UL);
  print "Saved $fn\n";
}

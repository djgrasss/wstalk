#!/usr/bin/perl
# Oona Räisänen 2012
use warnings;
use open ':encoding(utf8)';
binmode(STDOUT, ":utf8");

use Config::Simple;
use XML::Simple qw(:strict);

# Read config
Config::Simple->import_from('wstalk.cfg', \%conf)
  or die ("Unable to read config ($!)");

$conf{'NumAPs'} = 1 unless ($conf{'NumAPs'} > 0);
$conf{'Device'} = "wlan0" unless (($conf{'Device'} // "") =~ /^[a-z0-9_\.-]+$/);
$dev = $conf{'Device'};

# Read Wi-Fi map
$scan = XMLin($conf{'ScanFile'},
  KeyAttr    => { "loc" => "id", "ap" => "mac" },
  ForceArray => [ "loc", "ap" ]) or die ("Unable to read map ($!)");

# Find strongest APs in every map location
for $loc (keys %{$scan->{loc}}) {
  @s = (sort { $scan->{loc}->{$loc}->{ap}->{$b}->{q} <=>
    $scan->{loc}->{$loc}->{ap}->{$a}->{q} }
    keys %{$scan->{loc}->{$loc}->{ap}})[0..$conf{'NumAPs'}-1];
  @s = grep (defined, @s);
  $strongest{$loc}{$_} = 1 for (@s);
}

# Scan for nearby APs
for (`gksudo iwlist $dev scan`) {
  $adr       = $1 if (/^\s+Cell \d+ - Address: (\S+)/);
  $qua{$adr} = $1 if (/^\s+Quality=(\d+)/ && defined $adr);
}

# Generate UTC timestamp
@ctime     = gmtime(time);
$timestamp = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
  $ctime[5]+1900,$ctime[4]+1,$ctime[3],$ctime[2],$ctime[1],$ctime[0]);

# Compare the scan results with all mapped locations
$n = 0;
for $adr (sort {$qua{$b} <=> $qua{$a}} keys %qua) {
  $match{$_} += exists($strongest{$_}{$adr}) for (keys %strongest);
  last if (++$n >= $conf{'NumAPs'});
}

# Print most similar location
if (scalar keys %qua == 0) {
  print STDERR "No APs could be heard\n";
} elsif (scalar keys %match == 0) {
  print "$timestamp Outside map range\n";
} else {
  print ("$timestamp ".$scan->{loc}->{(sort {$match{$b} <=> $match{$a}} keys %match)[0]}->{desc}."\n");
}

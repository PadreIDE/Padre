use strict;
use warnings;

my $j = 12;
our @foo;
if (1) {
  foreach my $i (1..10) {
    $i += $j;
  }
  for our $k (@foo) {
    $k += $j;
  }
  my $i = 2;
}


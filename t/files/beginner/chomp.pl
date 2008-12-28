#!perl 
use strict;
use warnings;

my $line = "abc\n";
$line = chomp $line;
print $line;

# problem: chomp returns the number of characters removed and not the actual string
# should be "chomp $line;" and nothing else.
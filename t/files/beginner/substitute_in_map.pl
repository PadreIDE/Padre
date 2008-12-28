#!perl 
use strict;
use warnings;

my @data = qw(foo bar baz);
@data = map { s/./X/; } @data;
print "@data\n";

# problem: s/// does not return the substituted string so the above should be written as
# @data = map { s/./X/; $_ } @data;
# substitute actually returns the number of substitutions which is of course will alway be 1 
# unless we use global matching: /g
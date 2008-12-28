#!perl 
use strict;
use warnings;

my @data = qw(foo bar baz);
@data = map { s/./X/; } @data;
print "@data\n";

# problem: s/// does not return the substituted string so the above should be written as
# @data = map { s/./X/; $_ } @data;
#!perl
use strict;
use warnings;

my @arg = ("abcdXezXq");
my @view = split "X" , @arg ;
print @view;

# problem: @arg is in scalar context here so it returns the number of elements

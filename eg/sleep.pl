#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

$| = 1;

my $n = 10;
print "First line\n";
print "Going to sleep $n seconds\n";
sleep $n;
print "Finished sleeping\n";

#!/usr/bin/perl 
use strict;
use warnings;

my @names = qw(A B C);
foreach my $name (<@names>) {
	print "$name\n";
}

# problem: the user wants to iterate over strings
# by mistake she creates a glob that returns the strings
# she added

# The annoying part here is that this works
# despite being incorrect

# the correct coude would be:
# foreach my $name (@names) {

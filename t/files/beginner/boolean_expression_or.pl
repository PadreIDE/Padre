#!perl 
use strict;
use warnings;

my $user = 'foo';
if ($user eq 'bar' or 'baz') {
    print "$user is either bar or baz\n";
}

# problem: user really meant to check if $user eq 'bar' or $user eq 'baz'
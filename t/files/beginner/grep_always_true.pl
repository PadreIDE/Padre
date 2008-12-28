#!perl 
use strict;
use warnings;

my $arg = shift || 'boo';
my @valid = qw( goo moo foo voo doo poo );
print "$arg matches\n" if grep $arg, @valid;

# problem this grep is always true

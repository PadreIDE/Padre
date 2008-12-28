#!perl 
use strict;
use warnings;

my $x = 42;
if ($x = /x/) {
	print "ok\n";
}

# problem:
# that will try to match $_ with /x/ if you are lucky you get
# Use of uninitialized value $_ in pattern match (m//) at xx.pl line 32.
# if you are unlicky $_ already had a value and the above will make
# the mistake silently

# The above code is legitimate and some people use it but beginners
# usually write it by mistake.
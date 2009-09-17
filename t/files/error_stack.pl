use strict;
use warnings;
use diagnostics '-traceonly';

my $name;
print "Hello $name\n"; 

sub dying { my $illegal = 10 / 0;}
sub calling {dying()}

calling();


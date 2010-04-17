use strict;
use warnings;

# This script was written to allow us to check various features
# of the debugger

use t::files::Debugger;

main();

sub main {
	my $fname = 'foo';
	my $lname = 'bar';
	
	print "$fname $lname";
	my $f = factorial(4); # test a recursive functions
	print "$f\n";
}

sub factorial {
	my $n = shift;
	return 1 if $n == 0 or $n == 1;
	return $n * factorial($n-1);
}

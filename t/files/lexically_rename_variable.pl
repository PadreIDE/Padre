#!/usr/bin/perl

use strict;
use warnings;

my $x = 23;
{
	my $x = 42;
	{
		my $x = 19;
		print $x;
	}
	print $x;
}

print $x;

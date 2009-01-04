#!/usr/bin/perl -w

# Compile testing for Config::Tiny

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 2;

ok( $] >= 5.004, "Your perl is new enough" );
use_ok('Config::Tiny');

exit(0);

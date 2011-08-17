#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
	}
	plan( tests => 2 );
}

use Test::NoWarnings;
use t::lib::Padre ();
use Padre::Config ();
use Padre::Wx     ();

# Attempt to load the second-generation constants
ok( Padre::Wx->import(':api2'), 'Enabled API2' );

#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 2;
use Test::NoWarnings;

use File::Temp ();
$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );

use_ok( 'Padre::Config2' );

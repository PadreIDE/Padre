#!/usr/bin/perl

# Tests for the Padre::MIME module and the mime types in it

use strict;
use warnings;
use Test::More;
BEGIN {
	if ( -d '.svn' ) {
		plan tests => 4;
	} else {
		plan skip_all => 'Not in an SVN checkout';
	}
}
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use t::lib::Padre;
use Padre::SVN;

my $t = catfile( 't', '12_svn.t' );
ok( -f $t, "Found file $t" );





######################################################################
# Basic checks 

# Find the property file
my $file = Padre::SVN::find_props($t);
ok( -f $file, "Found property file $file" );

# Parse the property file
my $hash = Padre::SVN::parse_props($file);
is_deeply(
	$hash,
	{ 'svn:eol-style' => 'LF' },
	'Found expected properties',
);

#!/usr/bin/perl

# Tests for the Padre::MIME module and the mime types in it

use strict;
use warnings;
use Test::More;

BEGIN {
	if ( -d '.svn' || -d '../.svn' ) {
		plan tests => 4;
	} else {
		plan skip_all => 'Not in an SVN checkout';
	}
}
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use t::lib::Padre;
use Padre::SVN;
use Padre::Util::SVN;


SKIP: {
	skip( "svn version 1.7.x is not supported by Padre::SVN", 3 ) if Padre::Util::SVN::local_svn_ver();
	skip( 'svn not in PATH', 3 ) unless File::Which::which('svn');

	my $t = catfile( 't', '11_svn.t' );
	ok( -f $t, "Found file $t" );

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

}


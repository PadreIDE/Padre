#!/usr/bin/perl

# Tests for the Padre::MIME module and the mime types in it

use strict;
use warnings;
use Test::More;
BEGIN {
	if ( -d '.svn' ) {
		plan( tests => 2 );
	} else {
		plan( skip_all => 'Not in an SVN checkout' );
	}
}
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use t::lib::Padre;
use Padre::SVN;





######################################################################
# Basic checks 

my $file = File::Spec->catfile( qw{
	t .svn props-base File.pm.svn-base
} );
ok( -f $file, 'Found property file' );

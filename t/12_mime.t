#!/usr/bin/perl

# Tests for the Padre::MIME module and the mime types in it

use strict;
use warnings;
use Test::More tests => 758;
use Test::NoWarnings;
use File::Spec::Functions;
use t::lib::Padre;
use Padre::MIME;
use Padre::Util::SVN;




######################################################################
# Basic checks

# Check an known-bad type
my $unknown = Padre::MIME->find('foo/bar');
isa_ok( $unknown, 'Padre::MIME' );
is( $unknown->name, 'UNKNOWN', '->name ok' );

# Check all of the created mime types
foreach my $type ( sort Padre::MIME->types ) {
	ok( $type, "$type: Got MIME type" );
	my $mime = Padre::MIME->find($type);
	isa_ok( $mime, 'Padre::MIME' );
	is( $mime->type, $type, "$type: ->type ok" );
	ok( $mime->name,           "$type: ->name ok" );
	ok( defined $mime->binary, "$type: ->binary ok" );
	SKIP: {
		skip( 'Binary files are not supported', 1 ) if $mime->binary;
		ok( $mime->document, "$type: ->document ok" );
	}
}

# Check all known file extensions map to real mime types
foreach my $ext ( sort Padre::MIME->exts ) {
	ok( $ext, "$ext: Got file extension" );
	my $type = Padre::MIME->detect(
		file => "file.$ext",
	);
	ok( $type, "$ext: Got MIME type $type" );
	my $mime = Padre::MIME->find($type);
	isa_ok( $mime, 'Padre::MIME' );
	ok( $mime->type, "$ext: Resolved $type to " . $mime->type );
}

# Detect the mime type of a sample file
SCOPE: {
	my $file = catfile( 't', '12_mime.t' );
	ok( -f $file, "Found test file $file" );
	my $type = Padre::MIME->detect(
		file => $file,
	);
	is( $type, 'application/x-perl', '->detect(file=>perl)' );
}

# Detect the mime type using svn metadata
SKIP: {
	skip( "Not an SVN checkout", 3 ) unless -e '.svn' and Padre::Util::SVN::local_svn_ver();
	skip( 'svn not in PATH', 3 ) unless File::Which::which('svn');

	my $file = catfile( 't', 'perl', 'zerolengthperl' );
	ok( -f $file, "Found zero length perl file $file" );

	my $type1 = Padre::MIME->detect(
		file => $file,
	);
	is( $type1, 'text/plain', '->detect(zerolengthsvn)' );

	my $type2 = Padre::MIME->detect(
		file => $file,
		svn  => 1,
	);
	is( $type2, 'application/x-perl', '->detect(zerolengthsvn)' );
}

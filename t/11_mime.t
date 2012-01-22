#!/usr/bin/perl

# Tests for the Padre::MIME module and the mime types in it

use strict;
use warnings;
use Test::More tests => 248;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::MIME;





######################################################################
# Basic checks 

# Check an known-bad type
my $unknown = Padre::MIME->find('foo/bar');
isa_ok( $unknown, 'Padre::MIME' );
is( $unknown->name, 'UNKNOWN', '->name ok' );

# Check all of the created mime types
foreach my $type ( Padre::MIME->types ) {
	ok( $type, 'Got MIME type' );
	my $mime = Padre::MIME->find($type);
	isa_ok( $mime, 'Padre::MIME' );
	is( $mime->type, $type, '->type ok' );
	ok( $mime->name, '->name ok' );
	ok( $mime->document, '->document ok' );
}

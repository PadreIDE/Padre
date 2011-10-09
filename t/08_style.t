#!/usr/bin/perl

# Test the style subsystem

use strict;
use warnings;
use Test::More;


BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use t::lib::Padre;

plan( tests => 21 );

my $dir = catdir( 'share', 'themes' );
ok( -d $dir, "Found theme directory $dir" );

my @styles = qw{
	default
	night
	notepad
	ultraedit
	solarized_dark
	solarized_light
};





######################################################################
# Tests for the Style 2.0 API

use_ok('Padre::Wx::Theme');

SCOPE: {

	# Search for the list of styles
	my $files = Padre::Wx::Theme->files;
	is( ref($files), 'HASH', 'Found style hash' );
	ok( $files->{default},    'The default style is defined' );
	ok( -f $files->{default}, 'The default style exists' );

	# Find the file by name
	my $file = Padre::Wx::Theme->file('default');
	ok( $file,    'Found file by name' );
	ok( -f $file, 'File by name exists' );

	# Load the default style
	my $style = Padre::Wx::Theme->find('default');
	isa_ok( $style, 'Padre::Wx::Theme' );
	ok( scalar( @{ $style->mime } ), 'Found a list of methods' );

	# Find the localised name for a style
	my $label = Padre::Wx::Theme->label( 'default', 'en-gb' );
	is( $label, 'Padre', 'Got expected label for default style' );

	# Find the localised name for all available styles
	my $labels = Padre::Wx::Theme->labels('de');
	is( ref($labels),       'HASH',  '->labels returns a HASH' );
	is( $labels->{default}, 'Padre', '->labels contains expected default' );
	is( $labels->{night},   'Nacht', '->labels contains translated string' );
}





######################################################################
# Make sure all style files load

my $files = Padre::Wx::Theme->files;
foreach my $name ( sort keys %$files ) {
	my $style = Padre::Wx::Theme->find($name);
	isa_ok( $style, 'Padre::Wx::Theme', "Style '$name' loads correctly" );
}

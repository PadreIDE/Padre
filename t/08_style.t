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

plan( tests => 54 );

my $dir = catdir( 'share', 'styles' );
ok( -d $dir, "Found style directory $dir" );

my @styles = qw{
	default
	night
	notepad
	ultraedit
	solarized_dark
	solarized_light
};





######################################################################
# Check the new Padre::Style API

use_ok('Padre::Config::Style');
my $hash = Padre::Config::Style->core_styles;
is( scalar( keys %$hash ), 7, 'Found 7 core styles' );
my @user = Padre::Config::Style->user_styles;





######################################################################
# Make sure the bundled styles all load

foreach my $name (@styles) {
	my $file = catfile( $dir, "$name.yml" );
	ok( -f $file, "Found style file $file" );
	my $style = Padre::Config::Style->load( $name => $file );
	isa_ok( $style, 'Padre::Config::Style' );
	is( $style->name,        $name,  '->name ok' );
	is( ref( $style->data ), 'HASH', '->data is a HASH' );
	foreach (qw{ plain padre perl }) {
		is( ref( $style->data->{$_} ), 'HASH', "->data->{$_} is defined" );
	}
}





######################################################################
# Ensure the new style API loads as well

use_ok('Padre::Wx::Style');

# Search for the list of styles
my $styles = Padre::Wx::Style->search;
is( ref($styles), 'HASH', 'Found style hash' );
ok( $styles->{default}, 'The default style is defined' );
ok( -f $styles->{default}, 'The default style exists' );

# Find the file by name
my $file = Padre::Wx::Style->file('default');
ok( $file, 'Found file by name' );
ok( -f $file, 'File by name exists' );

# Load the default style
my $style2 = Padre::Wx::Style->find('default');
isa_ok( $style2, 'Padre::Wx::Style' );
ok( scalar( @{ $style2->mime } ), 'Found a list of methods' );

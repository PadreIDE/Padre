#!/usr/bin/perl

# Test the style subsystem

use strict;
use warnings;
use Test::More tests => 32;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use t::lib::Padre;

my $dir = catdir( 'share', 'styles' );
ok( -d $dir, "Found style directory $dir" );

my @styles = qw{
	default
	night
	notepad
	ultraedit
};





######################################################################
# Check the new Padre::Style API

use_ok('Padre::Config::Style');
my %hash = Padre::Config::Style->core_styles;
is( scalar( keys %hash ), 5, 'Found 5 core styles' );
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





1;

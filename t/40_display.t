#!/usr/bin/perl

# Tests for Padre::Wx::Display

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 13 );
}
use Test::NoWarnings;
use t::lib::Padre;
use Padre::Wx::Display ();





######################################################################
# Wx::Rect Handling

SCOPE: {
	my $string = '1,2,3,4';
	my $rect   = Padre::Wx::Display::_rect_from_string($string);
	isa_ok( $rect, 'Wx::Rect' );
	is( $rect->x,         1, '->x ok' );
	is( $rect->y,         2, '->y ok' );
	is( $rect->width,     3, '->width ok' );
	is( $rect->height,    4, '->height ok' );
	is( $rect->GetTop,    2, '->GetTop ok' );
	is( $rect->GetBottom, 5, '->GetBottom ok' );
	is( $rect->GetLeft,   1, '->GetLeft ok' );
	is( $rect->GetRight,  3, '->GetRight ok' );

	my $round = Padre::Wx::Display::_rect_as_string($rect);
	is( $round, $string, 'Wx::Rect round-strips ok' );
}





######################################################################
# Display Methods

SCOPE: {
	my $primary = Padre::Wx::Display::primary();
	isa_ok( $primary, 'Wx::Display' );

	my $default = Padre::Wx::Display::primary_default();
	isa_ok( $default, 'Wx::Rect' );
}

#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 16 );
}
use Test::NoWarnings;
use t::lib::Padre;
use t::lib::Padre::Editor;

my $e = t::lib::Padre::Editor->new;

my $text = <<"END_TEXT";
This is the first line
A second line
and there is even a third line
END_TEXT

SCOPE: {

	# diag "Testing the t::lib::Padre::Editor a bit";
	$e->SetText($text);
	is( $e->GetText($text), $text );

	is( $e->GetCurrentPos, 0 );

	is( $e->LineFromPosition(0),  0 );
	is( $e->LineFromPosition(20), 0 );
	is( $e->LineFromPosition(22), 0 );
	is( $e->LineFromPosition(23), 1 );
	is( $e->LineFromPosition(24), 1 );

	is( $e->GetLineEndPosition(0), 23 );

	is( $e->PositionFromLine(0), 0 );
	is( $e->PositionFromLine(1), 23 );

	is( $e->GetColumn(0),  0 );
	is( $e->GetColumn(5),  5 );
	is( $e->GetColumn(22), 22 );
	is( $e->GetColumn(23), 0 );
	is( $e->GetColumn(24), 1 );
}

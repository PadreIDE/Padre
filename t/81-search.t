#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 13;
}
use Test::NoWarnings;
use t::lib::Padre;
use Padre::Util ();

SCOPE: {
	my ( $start, $end, @matches ) = Padre::Util::Padre::Util::get_matches( "abc", qr/x/, 0, 0 );
	is_deeply( \@matches, [], 'no match' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abc", qr/(b)/, 0, 0 );
	is_deeply( \@matches, [ 1, 2, [ 1, 2 ] ], 'one match' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b)/, 0, 0 );
	is_deeply( \@matches, [ 1, 2, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b)/, 1, 2 );
	is_deeply( \@matches, [ 3, 4, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b)/, 3, 4 );
	is_deeply( \@matches, [ 5, 6, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b)/, 5, 6 );
	is_deeply( \@matches, [ 1, 2, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches, wrapping' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b)/, 5, 6, 1 );
	is_deeply( \@matches, [ 3, 4, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches backwards' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b)/, 1, 2, 1 );
	is_deeply( \@matches, [ 5, 6, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches backwards wrapping' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b(.))/, 1, 2 );
	is_deeply( \@matches, [ 3, 5, [ 1, 3 ], [ 3, 5 ] ], '2 matches' );
}

SCOPE: {
	my (@matches) = Padre::Util::get_matches( "abcbxb", qr/(b(.?))/, 1, 2, 1 );
	is_deeply( \@matches, [ 5, 6, [ 1, 3 ], [ 3, 5 ], [ 5, 6 ] ], 'three matches bw, wrap' );
}

SCOPE: {
	my $str = qq( perl ("שלום"); perl );
	my (@matches) = Padre::Util::get_matches( $str, qr/(perl)/, 0, 0 );

	# TODO are these really correct numbers?
	is_deeply( \@matches, [ 1, 5, [ 1, 5 ], [ 28, 32 ] ], '2 matches with unicode' );
	is( substr( $str, 1, 4 ), 'perl' );
}

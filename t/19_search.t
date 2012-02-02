#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 27;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::Search ();





######################################################################
# Basic tests for the core matches method

SCOPE: {
	my ( $start, $end, @matches ) = Padre::Search->matches(
		text  => "abc",
		regex => qr/x/,
		from  => 0,
		to    => 0,
	);
	is_deeply( \@matches, [], 'no match' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text  => "abc",
		regex => qr/(b)/,
		from  => 0,
		to    => 0,
	);
	is_deeply( \@matches, [ 1, 2, [ 1, 2 ] ], 'one match' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text  => "abcbxb",
		regex => qr/(b)/,
		from  => 0,
		to    => 0,
	);
	is_deeply( \@matches, [ 1, 2, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text  => "abcbxb",
		regex => qr/(b)/,
		from  => 1,
		to    => 2,
	);
	is_deeply( \@matches, [ 3, 4, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text  => "abcbxb",
		regex => qr/(b)/,
		from  => 3,
		to    => 4,
	);
	is_deeply( \@matches, [ 5, 6, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text  => "abcbxb",
		regex => qr/(b)/,
		from  => 5,
		to    => 6,
	);
	is_deeply( \@matches, [ 1, 2, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches, wrapping' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text      => "abcbxb",
		regex     => qr/(b)/,
		from      => 5,
		to        => 6,
		backwards => 1,
	);
	is_deeply( \@matches, [ 3, 4, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches backwards' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text      => "abcbxb",
		regex     => qr/(b)/,
		from      => 1,
		to        => 2,
		backwards => 1,
	);
	is_deeply( \@matches, [ 5, 6, [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ], 'three matches backwards wrapping' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text  => "abcbxb",
		regex => qr/(b(.))/,
		from  => 1,
		to    => 2,
	);
	is_deeply( \@matches, [ 3, 5, [ 1, 3 ], [ 3, 5 ] ], '2 matches' );
}

SCOPE: {
	my (@matches) = Padre::Search->matches(
		text      => "abcbxb",
		regex     => qr/(b(.?))/,
		from      => 1,
		to        => 2,
		backwards => 1,
	);
	is_deeply( \@matches, [ 5, 6, [ 1, 3 ], [ 3, 5 ], [ 5, 6 ] ], 'three matches bw, wrap' );
}

SCOPE: {
	my $str = qq( perl ("שלום"); perl );
	my (@matches) = Padre::Search->matches(
		text  => $str,
		regex => qr/(perl)/,
		from  => 0,
		to    => 0,
	);

	# TODO are these really correct numbers?
	is_deeply( \@matches, [ 1, 5, [ 1, 5 ], [ 28, 32 ] ], 'two matches with unicode' );
	is( substr( $str, 1, 4 ), 'perl' );
}

SCOPE: {
	my $str = 'müssen';
	my (@matches) = Padre::Search->matches(
		text  => $str,
		regex => qr/(üss)/,
		from  => 0,
		to    => 0,
	);
	is_deeply( \@matches, [ 1, 7, [ 1, 7 ] ], 'one match with unicode regex' );
	is( substr( $str, 1, 4 ), 'üss' );
}





######################################################################
# Searching within a selection

my $text = <<'END_TEXT';
Roses are red,
Violets are blue,
All your base are belong to us.
END_TEXT

SCOPE: {
	my $search = new_ok( 'Padre::Search', [ find_term => 'are' ] );
	my ( $first_char, $last_char, @all ) = $search->matches(
		text  => $text,
		regex => qr/are/,
		from  => 0,
		to    => length($text),
	);

	ok( $first_char, 'calling matches with proper parameters should work' );
	is( $first_char, 6, 'found first entry at position 6' );
	is( $last_char,  9, 'found first entry ending at position 9' );
	is(
		substr( $text, $first_char, $last_char - $first_char ),
		'are',
		'position is correct',
	);

	is_deeply(
		\@all,
		[
			[ 6,  9 ],
			[ 23, 26 ],
			[ 47, 50 ],
		],
		'matches returns a correct structure',
	);
}

SCOPE: {
	my $search    = new_ok( 'Padre::Search', [ find_term => 'are' ] );
	my $sel_begin = 5;
	my $sel_end   = 30;
	my ( $first_char, $last_char, @all ) = $search->matches(
		text  => substr( $text, $sel_begin, $sel_end - $sel_begin ),
		regex => qr/are/,
		from  => 0,
		to    => $sel_end - $sel_begin,
	);
	ok( $first_char, 'calling matches with proper parameters should work' );
	is( $first_char, 1, 'found relative entry at position 1' );
	is( $last_char,  4, 'found relative entry ending at position 4' );
	is(
		substr( $text, $first_char + $sel_begin, $last_char - $first_char ),
		'are',
		'relative position is correct',
	);

	is_deeply(
		\@all,
		[
			[ 1,  4 ],
			[ 18, 21 ],
		],
		'matches returns a correct relative structure (within selection)',
	);
}

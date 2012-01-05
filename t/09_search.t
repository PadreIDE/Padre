#!/usr/bin/perl

# Tests for the Padre::Search API

use strict;
use warnings;
use Test::More tests => 11;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use t::lib::Padre;
use Padre::Search;

my $FILENAME = catfile( 'lib', 'Padre.pm' );
ok( -f $FILENAME, "Test file $FILENAME exists" );

my $SAMPLE = <<'END_TEXT';
foo

foo
foobar
foo bar
barfoo
bar foo
foofoofoo
END_TEXT





######################################################################
# Basics

SCOPE: {
	my $search = Padre::Search->new(
		find_term => 'foo',
	);
	isa_ok( $search, 'Padre::Search' );

	# Find a count of matches
	my $count = $search->search_count( \$SAMPLE );
	is( $count, 9, '->search_count ok' );

	# Find the list of matches
	my @lines = $search->match_lines( $SAMPLE, $search->search_regex );
	is_deeply(
		\@lines,
		[   [ 1, 'foo' ],
			[ 3, 'foo' ],
			[ 4, 'foobar' ],
			[ 5, 'foo bar' ],
			[ 6, 'barfoo' ],
			[ 7, 'bar foo' ],
			[ 8, 'foofoofoo' ],
		],
	);
}

SCOPE: {
	my $replace = Padre::Search->new(
		find_term    => 'foo',
		replace_term => 'abc',
	);
	isa_ok( $replace, 'Padre::Search' );

	# Replace all terms
	my $copy    = $SAMPLE;
	my $changes = $replace->replace_all( \$copy );
	is( $changes, 9, '->replace_all ok' );

	# There should now be 9 copies of abc in it instead
	my $abc = Padre::Search->new(
		find_term => 'abc',
	)->search_count( \$copy );
	is( $abc, 9, 'Found 9 copies of the replace_term' );
}





######################################################################
# Regression Tests

SCOPE: {
	my $replace = new_ok(
		'Padre::Search' => [
			find_term    => 'Padre',
			replace_term => 'Padre2',
		]
	);

	# Load a known-bad file
	open( my $fh, '<', $FILENAME ) or die "open: $!";
	my $buffer = do { local $/; <$fh> };
	close $fh;

	# Apply the replace
	local $@;
	my $count = eval { $replace->replace_all( \$buffer ); };
	is( $@, '', '->replace_all in unicode file does not crash' );
	diag($@) if $@;
	ok( $count, 'Replaced ok' );
}

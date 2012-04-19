#!/usr/bin/perl

# Tests for the Padre::Comment module and the mime types in it

use strict;
use warnings;
use Test::More;
use Params::Util;
use t::lib::Padre;
use Padre::MIME;
use Padre::Comment;

BEGIN {

	# Calculate the plan automatically
	my $types = scalar Padre::MIME->types;
	my $tests = $types * 7 + 1;
	plan( tests => $tests );
}
use Test::NoWarnings;

# Some mime types do not need comments
my %nocomment = (
	'text/plain'   => 1,
	'text/csv'     => 1,
	'text/rtf'     => 1,
	'text/x-patch' => 1,
);





######################################################################
# Basic tasks

foreach my $type ( sort Padre::MIME->types ) {
	my $mime = Padre::MIME->find($type);
	isa_ok( $mime, 'Padre::MIME' );
	is( $mime->type, $type, "$type: Found Padre::MIME" );

	SKIP: {

		# We are only interested in cases where there are multiple comments
		my @path = map { $_->key } grep { defined $_ } map { Padre::Comment->get($_) } $mime->superpath;

		# Skip on various conditions
		if ( $mime->binary ) {
			skip( "$type: No comments in binary files", 5 );
		}
		if ( $nocomment{$type} ) {
			skip( "$type: File does not support comments", 5 );
		}
		ok( scalar(@path), "$type: Found at least one comment" );

		# Look for nested duplicates
		my $bad = grep { $path[ $_ - 1 ] eq $path[$_] } ( 1 .. $#path );
		is( $bad, 0, "$type: No duplicate comments in the path" );

		# Can we find the comment object via the find method
		my $comment = Padre::Comment->find($type);
		isa_ok( $comment, 'Padre::Comment' );
		my $comment2 = Padre::Comment->find($mime);
		isa_ok( $comment2, 'Padre::Comment' );

		# Can we get the comment line detection regexp
		my $line = $comment->line_match;
		ok( Params::Util::_REGEX($line), "$type: ->is_line ok" );
	}
}

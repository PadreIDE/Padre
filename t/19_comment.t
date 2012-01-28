#!/usr/bin/perl

# Tests for the Padre::Comment module and the mime types in it

use strict;
use warnings;
use Test::More tests => 221;
use Test::NoWarnings;
use t::lib::Padre;
use Padre::MIME;
use Padre::Comment;

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
		my @path = map {
			ref $_ ? join( ' ', @$_ ) : $_
		} grep {
			defined $_
		} map {
			Padre::Comment->find($_)
		} $mime->superpath;

		# Skip on various conditions
		if ( $mime->binary ) {
			skip( "$type: No comments in binary files", 2 );
		}
		if ( $nocomment{$type} ) {
			skip( "$type: File does not support comments", 2 );
		}
		ok( scalar(@path), "$type: Found at least one comment" );

		# Look for nested duplicates
		my $bad = grep { $path[$_-1] eq $path[$_] } ( 1 .. $#path );
		is( $bad, 0, "$type: No duplicate comments in the path" );
	}
}

#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan tests => 6;
}

use Test::NoWarnings;
use t::lib::Padre;
use Padre::DB ();

SCOPE: {
	my @files = Padre::DB::History->recent('files');
	is_deeply \@files, [], 'no files yet';

	Padre::DB::History->create(
		type => 'files',
		name => 'Test.pm',
	);
	Padre::DB::History->create(
		type => 'files',
		name => 'Test2.pm',
	);
	@files = Padre::DB::History->recent('files');
	is_deeply \@files, [ 'Test2.pm', 'Test.pm' ], 'files';

	# test delete_recent
	@files = Padre::DB::History->recent('files');
	is_deeply \@files, [ 'Test2.pm', 'Test.pm' ], 'files still remain after delete_recent pod';
	ok( Padre::DB::History->delete( 'where type = ?', 'files' ) );
	@files = Padre::DB::History->recent('files');
	is_deeply \@files, [], 'no files after delete_recent files';
}

1;

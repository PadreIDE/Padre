#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 32;
use FindBin qw($Bin);
use File::Spec ();
use File::Temp ();
use Test::NoWarnings;

use Padre::Autosave;

my $dir = File::Temp::tempdir( CLEANUP => 1 );
my $db_file = File::Spec->catfile( $dir, 'backup.db' );
my $autosave = Padre::Autosave->new( dbfile => $db_file );
my $ts = qr/^\d{10}$/;

isa_ok( $autosave, 'Padre::Autosave' );
ok( -e $db_file, 'database file created' );

SCOPE: {
	my @files = $autosave->list_files;
	is_deeply( \@files, [], 'no files yet' );
	my $revs = $autosave->list_revisions('a.pl');
	is_deeply( $revs, [], 'no revisions yet' );
}

my @a_pl = (
	"Some text\n",
	"Some text\nsecond line\n",
	"Some text changed\nsecond line\n",
);

SCOPE: {
	$autosave->save_file( 'a.pl', 'initial', $a_pl[0] );
	my @files = $autosave->list_files;
	is_deeply( \@files, ['a.pl'], 'a.pl in database' );
	my $revs = $autosave->list_revisions('a.pl');
	is( $revs->[0]->[0], 1, 'list revisions 1' );
	like( $revs->[0]->[1], $ts, 'list revisions 2' );
	is( $revs->[0]->[2], 'initial', 'list revisions 3' );
}

SCOPE: {
	sleep 1;
	$autosave->save_file( 'a.pl', 'usersave', $a_pl[1] );
	my @files = $autosave->list_files;
	is_deeply( \@files, ['a.pl'], 'a.pl in database' );
	my $revs = $autosave->list_revisions('a.pl');
	is( $revs->[0]->[0], 1, 'list revisions 1' );
	like( $revs->[0]->[1], $ts, 'list revisions 2' );
	is( $revs->[0]->[2], 'initial', 'list revisions 3' );
	is( $revs->[1]->[0], 2,         'list revisions 4' );
	like( $revs->[1]->[1], $ts, 'list revisions 5' );
	is( $revs->[1]->[2], 'usersave', 'list revisions 6' );
}

my $buffer_1 = 'buffer://1234';
my @buffer_1 = (
	"Text in the unsaved buffer\n",
	"Text in the unsaved buffer\nwith a second line\n",
);

SCOPE: {
	sleep 1;
	$autosave->save_file( $buffer_1, 'autosave', $buffer_1[0] );
	sleep 1;
	$autosave->save_file( 'a.pl',    'autosave', $a_pl[2] );
	$autosave->save_file( $buffer_1, 'autosave', $buffer_1[1] );

	my @files = $autosave->list_files;
	is_deeply( \@files, [ 'a.pl', $buffer_1 ], 'a.pl and buffer in database' );
	my $revs = $autosave->list_revisions('a.pl');
	is( $revs->[0]->[0], 1, 'list revisions 1' );
	like( $revs->[0]->[1], $ts, 'list revisions 2' );
	is( $revs->[0]->[2], 'initial', 'list revisions 3' );
	is( $revs->[1]->[0], 2,         'list revisions 4' );
	like( $revs->[1]->[1], $ts, 'list revisions 5' );
	is( $revs->[1]->[2], 'usersave', 'list revisions 6' );
	is( $revs->[2]->[0], 4,          'list revisions 7' );
	like( $revs->[2]->[1], $ts, 'list revisions 8' );
	is( $revs->[2]->[2], 'autosave', 'list revisions 9' );
	$revs = $autosave->list_revisions($buffer_1);
	is( $revs->[0]->[0], 3, 'list revisions 1' );
	like( $revs->[0]->[1], $ts, 'list revisions 2' );
	is( $revs->[0]->[2], 'autosave', 'list revisions 3' );
	is( $revs->[1]->[0], 5,          'list revisions 4' );
	like( $revs->[1]->[1], $ts, 'list revisions 5' );
	is( $revs->[1]->[2], 'autosave', 'list revisions 6' );
}

# TODO do we really need the 'initial' type ?
# TODO the user saves the file that is in the buffer
# TODO crash ? how to recognize unsaved files

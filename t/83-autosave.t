#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;
use FindBin      qw($Bin);
use File::Spec   ();
use File::Temp   ();
use Data::Dumper qw(Dumper);
use Test::NoWarnings;

use Padre::Autosave;

my $dir      = File::Temp::tempdir( CLEANUP => 1);
my $db_file  = File::Spec->catfile($dir, 'backup.db');
my $autosave = Padre::Autosave->new(dbfile => $db_file);
my $ts       = re('^\d{10}$');

isa_ok( $autosave, 'Padre::Autosave' );
ok( -e $db_file, 'database file created' );

SCOPE: {
	my @files = $autosave->list_files;
	is_deeply( \@files, [], 'no files yet');
	my $revs = $autosave->list_revisions('a.pl');
	is_deeply( $revs, [], 'no revisions yet');
}

my @a_pl = (
	"Some text\n",
	"Some text\nsecond line\n",
	"Some text changed\nsecond line\n",
);

SCOPE: {
	$autosave->save_file('a.pl', 'initial', $a_pl[0]);
	my @files = $autosave->list_files;
	is_deeply( \@files, ['a.pl'], 'a.pl in database' );
	my $revs = $autosave->list_revisions('a.pl');
	is_deeply( $revs, [[1, $ts, 'initial']], 'list revisions' );
}

SCOPE: {
	sleep 1;
	$autosave->save_file('a.pl', 'usersave', $a_pl[1]);

	my @files = $autosave->list_files;
	is_deeply( \@files, ['a.pl'], 'a.pl in database');
	my $revs = $autosave->list_revisions('a.pl');
	is_deeply( $revs, [[1, $ts, 'initial'], [2, $ts, 'usersave']], 'list revisions' );
}

my $buffer_1 = 'buffer://1234';
my @buffer_1 = (
	"Text in the unsaved buffer\n",
	"Text in the unsaved buffer\nwith a second line\n",
);

SCOPE: {
	sleep 1;
	$autosave->save_file($buffer_1, 'autosave', $buffer_1[0]);
	sleep 1;
	$autosave->save_file('a.pl', 'autosave', $a_pl[2]);
	$autosave->save_file($buffer_1, 'autosave', $buffer_1[1]);

	my @files = $autosave->list_files;
	is_deeply( \@files, ['a.pl', $buffer_1], 'a.pl and buffer in database');
	my $revs = $autosave->list_revisions('a.pl');
	is_deeply( $revs, [[1, $ts, 'initial'], [2, $ts, 'usersave'], [4, $ts, 'autosave']], 'list revisions' );
	$revs = $autosave->list_revisions($buffer_1);
	is_deeply( $revs, [[3, $ts, 'autosave'], [5, $ts, 'autosave']], 'list revisions' );
}

# TODO do we really need the 'initial' type ?
# TODO the user saves the file that is in the buffer
# TODO crash ? how to recognize unsaved files

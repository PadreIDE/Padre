#!/usr/bin/perl

use strict;
use warnings;

use FindBin      qw($Bin);
use File::Spec   ();
use File::Temp   ();
use Data::Dumper qw(Dumper);

use Test::More;
use Test::NoWarnings;
my $tests;
plan tests => $tests+1;

use Padre::Autosave;

my $dir = File::Temp::tempdir( CLEANUP => 1);

my $db_file = File::Spec->catfile($dir, 'backup.db');
my $autosave = Padre::Autosave->new(dbfile => $db_file);

{
	isa_ok($autosave, 'Padre::Autosave');
	ok(-e $db_file, 'database file created');
	BEGIN { $tests += 2; }
}

{
	my @files = $autosave->list_files;
	is_deeply( \@files, [], 'no files yet');
	BEGIN { $tests += 1; }
}

my $a_pl = 'Some text';

{
	$autosave->save_file('a.pl', 'initial', $a_pl);
	my @files = $autosave->list_files;
	is_deeply( \@files, ['a.pl'], 'a.pl in database');
	BEGIN { $tests += 1; }
}


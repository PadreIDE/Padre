#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 27;
use Test::NoWarnings;
use Storable                   ();
use File::Spec                 ();
use Padre::Wx::Directory::Path ();

my @bits = qw{ Foo Bar Baz };





######################################################################
# Testing a file

SCOPE: {
	my $file = Padre::Wx::Directory::Path->file(@bits);
	isa_ok( $file, 'Padre::Wx::Directory::Path' );
	is( $file->type, Padre::Wx::Directory::Path::FILE, '->type ok' );
	is( $file->name, 'Baz',                            '->name ok' );
	is( $file->unix, 'Foo/Bar/Baz',                    '->unix ok' );
	is_deeply( [ $file->path ], \@bits, '->path ok' );
	is( $file->is_file,      1, '->is_file ok' );
	is( $file->is_directory, 0, '->is_directory ok' );
}





######################################################################
# Testing a directory

SCOPE: {
	my $directory = Padre::Wx::Directory::Path->directory(@bits);
	isa_ok( $directory, 'Padre::Wx::Directory::Path' );
	is( $directory->type, Padre::Wx::Directory::Path::DIRECTORY, '->type ok' );
	is( $directory->name, 'Baz',                                 '->name ok' );
	is( $directory->unix, 'Foo/Bar/Baz',                         '->unix ok' );
	is_deeply( [ $directory->path ], \@bits, '->path ok' );
	is( $directory->is_file,      0, '->is_file ok' );
	is( $directory->is_directory, 1, '->is_directory ok' );
}





######################################################################
# Storable Compatibility

SCOPE: {
	my $file = Padre::Wx::Directory::Path->file(@bits);
	isa_ok( $file, 'Padre::Wx::Directory::Path' );
	my $string = Storable::freeze($file);
	ok( length $string, 'Got a string' );
	my $round = Storable::thaw($string);
	is_deeply( $file, $round, 'File round-trips ok' );
	$string = Storable::nfreeze($file);
	ok( length $string, 'Got a string' );
	$round = Storable::thaw($string);
	is_deeply( $file, $round, 'File round-trips ok' );
}





######################################################################
# Test the null directory case

SCOPE: {
	my $directory = Padre::Wx::Directory::Path->directory;
	isa_ok( $directory, 'Padre::Wx::Directory::Path' );
	is( $directory->type, Padre::Wx::Directory::Path::DIRECTORY, '->type ok' );
	is( $directory->name, '',                                    '->name ok' );
	is( $directory->unix, '',                                    '->unix ok' );
	is_deeply( [ $directory->path ], [], '->path ok' );
	is( $directory->is_file,      0, '->is_file ok' );
	is( $directory->is_directory, 1, '->is_directory ok' );
}

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 16;
use Test::NoWarnings;
use Storable                   ();
use File::Spec                 ();
use Padre::Wx::Directory::Path ();





######################################################################
# Testing a file

SCOPE: {
	my @bits = qw{ Foo Bar Baz };
	my $file = Padre::Wx::Directory::Path->file(@bits);
	isa_ok( $file, 'Padre::Wx::Directory::Path' );
	is( $file->type, Padre::Wx::Directory::Path::FILE, '->type ok' );
	is( $file->spec, File::Spec->catfile(@bits), '->spec ok' );
	is_deeply( [ $file->path ], \@bits, '->path ok' );
	is( $file->is_file, 1, '->is_file ok' );
	is( $file->is_directory, 0, '->is_directory ok' );
}





######################################################################
# Testing a directory

SCOPE: {
	my @bits = qw{ Foo Bar Baz };
	my $directory = Padre::Wx::Directory::Path->directory(@bits);
	isa_ok( $directory, 'Padre::Wx::Directory::Path' );
	is( $directory->type, Padre::Wx::Directory::Path::DIRECTORY, '->type ok' );
	is( $directory->spec, File::Spec->catdir(@bits), '->spec ok' );
	is_deeply( [ $directory->path ], \@bits, '->path ok' );
	is( $directory->is_file, 0, '->is_file ok' );
	is( $directory->is_directory, 1, '->is_directory ok' );
}





######################################################################
# Storable Compatibility

SCOPE: {
	my @bits = qw{ Foo Bar Baz };
	my $file = Padre::Wx::Directory::Path->file(@bits);
	isa_ok( $file, 'Padre::Wx::Directory::Path' );
	my $string = Storable::freeze($file);
	ok( length $string, 'Got a string' );
	my $round = Storable::thaw($string);
	is_deeply( $file, $round, 'File round-trips ok' );
}

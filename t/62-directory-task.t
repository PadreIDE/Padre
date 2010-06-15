#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;
use Test::NoWarnings;
use File::Spec                 ();
use Padre::Wx::Directory::Path ();
use Padre::Wx::Directory::Task ();

my $plugins = 'plugins/Padre/Plugin';
my $root    = File::Spec->catdir( 't', 'files' );
ok( -d $root, 'Root path exists' );





######################################################################
# Scan a known tree

my $task = new_ok( 'Padre::Wx::Directory::Task', [
	root => $root,
	skip => [
		"\\B\\.svn\\b",
	],
] );
ok( $task->run, '->run ok' );
is( $task->{root}, $root, '->{root} ok' );
is( ref($task->{model}), 'ARRAY', '->{model} ok' );
my @files = @{$task->{model}};
is(
	scalar( grep { ! $_->isa('Padre::Wx::Directory::Path') } @files ), 0,
	'All files are Padre::Wx::Directory::Path objects',
);
my @directories = grep { $_->is_directory } @files;
is( scalar(@directories), 4, 'Found four directories' );

# Test the deepest of them (also confirms the sorting worked)
my $deepest = $directories[3];
is( $deepest->type, Padre::Wx::Directory::Path::DIRECTORY, '->type ok' );
is( $deepest->unix, $plugins, '->path ok' );
is_deeply(
	[ $deepest->path ],
	[ 'plugins', 'Padre', 'Plugin' ],
	'->spec ok',
);
is( $deepest->is_file, 0, '->is_file' );
is( $deepest->is_directory, 1, '->is_directory' );

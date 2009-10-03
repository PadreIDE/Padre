#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;
use Padre::Util;
use File::Basename ();
use File::Spec     ();
use FindBin;

my $current_dir = $FindBin::RealBin;
my $project_dir = File::Basename::dirname($current_dir); # one above /t

is( Padre::Util::get_project_dir($current_dir),
	$project_dir,
	"Finding Padre's project dir"
);

my @path = File::Spec->splitdir($current_dir);
$current_dir = File::Spec->catdir(
	@path,
	File::Spec->updir,                                   # /..
	$path[-1],                                           # /t
	File::Spec->updir,                                   # /..
	$path[-1]
);

if ( $^O =~ /Win32/i ) {
	$project_dir =~ s{/}{\\}g;
}
is( Padre::Util::get_project_dir($current_dir),
	$project_dir,
	"Finding Padre's project dir from relative path"
);

# the OS's root directory should not be a project
# TODO: improve this test
is( Padre::Util::get_project_dir( File::Spec->rootdir() ),
	undef,
	'Searching for a non-existant project'
);

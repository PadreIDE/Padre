#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2 + 1;
use FindBin qw($Bin);
use File::Spec ();
use File::Temp qw(tempdir);
use Test::NoWarnings;

# Testing the stand-alone Padre::Util::CommandLine

my $files_dir = tempdir( CLEANUP => 1 );
mkdir File::Spec->catdir( $files_dir, 'beginner' );
foreach my $file ('Debugger.pm') {
	open my $fh, '>', File::Spec->catfile( $files_dir, $file );
	close($fh);
}

use Padre::Util::CommandLine;
use Cwd ();
SCOPE: {
	no warnings;
	sub Cwd::cwd { $files_dir }
}

is(
	Padre::Util::CommandLine::tab(':e'),
	':e Debugger.pm',
	'TAB 1',
);
is(
	Padre::Util::CommandLine::tab(':e Debugger.pm'),
	':e beginner/',
	'TAB 2',
);

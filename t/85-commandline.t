#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2+1;
use FindBin qw($Bin);
use File::Spec ();
use File::Temp ();
use Data::Dumper qw(Dumper);
use Test::NoWarnings;

# Testing the stand-alone Padre::Util::CommandLine

use Padre::Util::CommandLine;
use Cwd qw(abs_path);
my $files_dir = File::Spec->catdir(abs_path(File::Basename::dirname($0)), 'files');
{
	no warnings;
	sub Cwd::cwd {	$files_dir }
}


is Padre::Util::CommandLine::tab(':e'), ':e Debugger.pm', 'TAB 1';
is Padre::Util::CommandLine::tab(':e Debugger.pm'), ':e beginner/', 'TAB 2';

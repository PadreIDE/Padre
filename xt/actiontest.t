#!/usr/bin/perl

###
# Put any tests here which badly crash Padre
###

use strict;
use warnings;
use Test::More;

# use Test::NoWarnings;
use File::Temp ();
use File::Spec ();

# Don't run tests for installs
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
}

unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
	plan skip_all => 'Needs DISPLAY';
}

# if ( $^O eq 'MSWin32' ) {
	# plan skip_all => 'Crashing currently blocks the entire test suite on Win32';
# }

my $devpl;

# Search for dev.pl
for ( '.', '..', '../..', 'blib/lib', 'lib' ) {
	if ( $^O eq 'MSWin32' ) {
		next if !-e File::Spec->catfile( $_, 'dev' );
	} else {
		next if !-x File::Spec->catfile( $_, 'dev' );
	}
	$devpl = File::Spec->catfile( $_, 'dev' );
	last;
}

my @actions = (
	'file.new',
	'file.open_last_closed_file',
	'file.new,file.close',
	'file.new,file.close_all',
	'file.new,file.new,file.close_all_but_current',
	'file.new,file.duplicate',
	'file.new,edit.select_all',
	'file.new,search.find',
	'file.new,search.find_next',
	'file.new,search.find_previous',

	# Twice to reset them to previous state
	'view.lockinterface,view.lockinterface',
	'view.output,view.output',
	'view.functions,view.functions',
	'view.todo,view.todo',
	'view.outline,view.outline',
	'view.directory,internal.wait10,view.directory', # Let it prepare the list
	'view.syntax,internal.wait10,view.syntax',
	'view.statusbar,view.statusbar',
	'view.toolbar,view.toolbar',
	'view.lines,view.lines',
	'view.folding,view.folding',
	'view.calltips,view.calltips',
	'view.currentline,view.currentline',
	'view.rightmargin,view.rightmargin',
	'view.eol,view.eol',
	'view.whitespaces,view.whitespaces',
	'view.indentation_guide,view.indentation_guide',
	'view.word_wrap,view.word_wrap',
	'view.font_increase,view.font_decrease,view.font_reset',
	'view.full_screen,view.full_screen,',
	'file.new,file.new,window.next_file',
	'file.new,file.new,window.previous_file',
);

plan( tests => scalar(@actions) * 3 + 1 );

use_ok('Padre::Perl');

my $cmd;
if ( $^O eq 'MSWin32' ) {

	# Look for Perl on Windows
	$cmd = Padre::Perl::cperl();
	plan skip_all => 'Need some Perl for this test' unless defined($cmd);
	$cmd .= ' ';
}

# Create temp dir
my $dir = File::Temp->newdir;
$ENV{PADRE_HOME} = $dir->dirname;

# Complete the dev.pl - command
$cmd .= $devpl . ' --invisible -- --home=' . $dir->dirname;
$cmd .= ' ' . File::Spec->catfile( $dir->dirname, 'newfile.txt' );
$cmd .= ' --actionqueue=';

for my $action (@actions) {
	ok( 1, 'Run ' . $action );

	my $cmd    = $cmd . $action . ',file.quit';
	my $output = `$cmd 2>&1`;

	$output =~ s/Scalars leaked: \d+//g;

	is( $? & 127, 0, 'Check exitcode' );
	like( $output, qr/^\s*$/, 'Check output' );
}

done_testing();

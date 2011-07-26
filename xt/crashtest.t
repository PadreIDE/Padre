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

if ( $^O eq 'MSWin32' ) {
	plan skip_all => 'Crashing currently blocks the entire test suite on Win32';
}

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

use_ok('Padre::Perl');

my $cmd;
if ( $^O eq 'MSWin32' ) {

	# Look for Perl on Windows
	$cmd = Padre::Perl::cperl();
	plan skip_all => 'Need some Perl for this test' unless defined($cmd);
	$cmd .= ' ';
}

#plan( tests => scalar( keys %TEST ) * 2 + 20 );

# Create temp dir
my $dir = File::Temp->newdir;
$ENV{PADRE_HOME} = $dir->dirname;

# Complete the dev.pl - command
$cmd .= $devpl . ' --invisible -- --home=' . $dir->dirname;
$cmd .= ' ' . File::Spec->catfile( $dir->dirname, 'newfile.txt' );
$cmd .= ' --actionqueue=file.new,search.goto,edit.join_lines,edit.comment_toggle';
$cmd .= ',edit.comment,edit.uncomment,edit.tabs_to_spaces,edit.spaces_to_tabs';
$cmd .= ',edit.show_as_hex,help.current,help.about,file.quit';

my $output = `$cmd 2>&1`;

is( $? & 127, 0, 'Check exitcode' );
TODO: {
	local $TODO = 'fix the bad_alloc exception';

	# The crash I have seen in r11212 is this:   terminate called after throwing an instance of 'std::bad_alloc'  what():  std::bad_alloc
	is( $output, '', 'Check output' );
}

done_testing();

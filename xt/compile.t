#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {

	# Don't run tests for installs
	unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
		plan( skip_all => "Author tests not required for installation" );
	}

	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
use Test::Script;
use File::Temp;
use File::Find::Rule;
use File::Spec;
use POSIX qw(locale_h);

local $ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');

plan( tests => 2 * @files + 1 );

# diag( "Locale: " . setlocale(LC_CTYPE) );

my $out = File::Spec->catfile( $ENV{PADRE_HOME}, 'out.txt' );
my $err = File::Spec->catfile( $ENV{PADRE_HOME}, 'err.txt' );

foreach my $file (@files) {
	my $module = $file;
	$module =~ s/[\/\\]/::/g;
	$module =~ s/\.pm$//;
	if ( $module eq 'Padre::CPAN' ) {
		foreach ( 1 .. 2 ) {
			Test::More->builder->skip("Cannot load CPAN shell under the CPAN shell");
		}
		next;
	}
	if ( $^O ne 'MSWin32' and $file eq 'Padre/Util/Win32.pm' ) {
		foreach ( 1 .. 2 ) {
			Test::More->builder->skip("'$file' is for Windows only");
		}
		next;
	}

	system qq($^X -e "require $module; print 'ok';" > $out 2>$err);
	my $err_data = slurp($err);
	is( $err_data, '', "STDERR of $file" );

	my $out_data = slurp($out);
	is( $out_data, 'ok', "STDOUT of $file" );
}

script_compiles('script/padre');

# Bail out if any of the tests failed
BAIL_OUT("Aborting test suite") if scalar grep { not $_->{ok} } Test::More->builder->details;





######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	my $buffer = <$fh>;
	close $fh;
	return $buffer;
}

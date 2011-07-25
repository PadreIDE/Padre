#!/usr/bin/perl

###
# This is mostly a demo test script for using the action queue for testing
###

use strict;
use warnings;
use Test::More;

use Capture::Tiny qw(capture);

#use Test::NoWarnings;
use File::Temp ();
use File::Spec();

plan skip_all => 'Needs DISPLAY'
	unless $ENV{DISPLAY}
		or ( $^O eq 'MSWin32' );

# Don't run tests for installs
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
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

# diag "devpl '$devpl'";

use_ok('Padre::Perl');

my $cmd;
my @chances = (
	Padre::Perl::cperl() . ' ', '"' . $^X . '" ', 'perl ', 'wperl ',
);
push @chances, map {"$_ "} grep { -e $_ } qw(/usr/bin/perl /usr/pkg/bin/perl);
push @chances, 'C:\\strawberry\\perl\\bin\\perl.exe ' if $^O =~ /MSWin32/i;

unshift @chances, '' if $^O eq 'linux';
push @chances, '' if $^O ne 'linux';
for my $prefix (@chances) {
	my $try = "$prefix$devpl --help";

	# diag "Try: '$try'";
	my $res = qx{$try};

	# diag "Result: $res";
	next if not defined $res;
	next unless $res =~ /(run Padre in the command line|\-\-fulltrace|\-\-actionqueue)/;
	$cmd = $prefix;
	last;
}

# The above will fail even if the user has not run
# perl Makefile.PL ; make
# so the error message below is not really good

plan skip_all => 'Need some Perl for this test' unless defined($cmd);

ok( 1, 'Using Perl: ' . $cmd );

#plan( tests => scalar( keys %TEST ) * 2 + 20 );

# Create temp dir
my $dir = File::Temp->newdir;
$ENV{PADRE_HOME} = $dir->dirname;

# Complete the dev.pl - command
$cmd .= $devpl . ' --invisible -- --home=' . $dir->dirname;
$cmd .= ' ' . File::Spec->catfile( $dir->dirname, 'newfile.txt' );
$cmd .= ' --actionqueue=internal.dump_padre,file.quit';

# diag "Command is: '$cmd'";
my ( $stdout, $stderr ) = capture { system($cmd); };

# diag $stdout;
# diag $stderr;

my $dump_fn = File::Spec->catfile( $dir->dirname, 'padre.dump' );

ok( -e $dump_fn, "Dump file '$dump_fn' exists" ) or exit;

our $VAR1;

# Read dump file into $VAR1
require_ok($dump_fn);

# Run the action checks...
foreach my $action ( sort( keys( %{ $VAR1->{actions} } ) ) ) {

	if ( $action =~ /^run\./ ) {

		# All run actions need a open editor window and a saved file
		if ( $action !~ /^run\.(stop|run_command)/ ) {
			ok( $VAR1->{actions}->{$action}->{need_editor}, $action . ' requires an editor' );
			ok( $VAR1->{actions}->{$action}->{need_file},   $action . ' requires a filename' );
		}
	}

	if ( $action =~ /^perl\./ ) {

		# All perl actions need a open editor window
		ok( $VAR1->{actions}->{$action}->{need_editor}, $action . ' requires an editor' );
	}

}

done_testing();

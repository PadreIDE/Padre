#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

# Handle various situations in which we should not run
unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
	plan skip_all => 'Needs DISPLAY';
}
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan skip_all => 'Author tests not required for installation';
}
unless (0) {

	# Test disabled as the --with-plugin mechanism was terrible
	plan skip_all => 'Required mechanism that violated encapsulation';
}

# use Test::NoWarnings;
use File::Temp    ();
use File::Spec    ();
use Capture::Tiny ();

plan tests => 5;

my $devpl;

# Search for dev.pl
for ( '.', '..', '../..', 'blib/lib', 'lib' ) {
	if ( $^O eq 'MSWin32' ) {
		next unless -e File::Spec->catfile( $_, 'dev' );
	} else {
		next unless -x File::Spec->catfile( $_, 'dev' );
	}
	$devpl = File::Spec->catfile( $_, 'dev' );
	last;
}

diag "devpl '$devpl'";

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
	diag "Try: '$try'";
	my $res = qx{$try};

	#diag "Result: $res";
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

# Create temp dir
my $dir = File::Temp->newdir;
$ENV{PADRE_HOME} = $dir->dirname;

# Complete the dev.pl - command
$cmd .= $devpl . ' --invisible -- --with-plugin=Padre::Plugin::Test --home=' . $dir->dirname;
$cmd .= ' ' . File::Spec->catfile( $dir->dirname, 'newfile.txt' );
$cmd .= ' --actionqueue=edit.copy_filename,edit.paste,file.save,file.quit';

diag "Command is: '$cmd'";
my ( $stdout, $stderr ) = Capture::Tiny::capture { system($cmd); };
diag $stdout;
diag $stderr;

like( $stdout, qr/\Q[[[TEST_PLUGIN:enable]]]\E/,      'plugin enabled' );
like( $stdout, qr/\Q[[[TEST_PLUGIN:before_save]]]\E/, 'before save hook' );
like( $stdout, qr/\Q[[[TEST_PLUGIN:after_save]]]\E/,  'before save hook' );

done_testing();

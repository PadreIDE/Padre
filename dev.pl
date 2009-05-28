#!/usr/bin/perl

use 5.008005;
use strict;
use warnings;
use Config;

# This script is only used to run the application from
# its development location
# No need to distribute it
use FindBin;
use File::Which    ();
use File::Basename ();
use Probe::Perl;
$ENV{PADRE_DEV}  = 1;
$ENV{PADRE_HOME} = $FindBin::Bin;

# Due to share functionality, we must have run make
unless ( -d "$FindBin::Bin/blib" ) {
	my $make = $Config::Config{make} || 'make';
	error("You must now have run 'perl Makefile.PL' and '$make' in order to run dev.pl");
}

my $msgfmt;
if ( $^O =~ /(linux|bsd)/ ) {
	$msgfmt = scalar File::Which::which('msgfmt');
} elsif ( $^O eq 'MSWin32' ) {
	eval {
		require File::Glob::Windows;
	};
	if( $@ ) {
		die("Default glob() will misinterpret spaces in folder names as seperators, install File::Glob::Windows to fix this behavior!");
	}
	my $p = "C:/Program Files/GnuWin32/bin/msgfmt.exe";
	if ( -e $p ) {
		$msgfmt = $p;
	} else {
		$msgfmt = scalar File::Which::which('msgfmt');
	}
}

if ( $msgfmt ) {
	convert_po_to_mo($FindBin::Bin);
}

my $perl = Probe::Perl->find_perl_interpreter;
if ( $^O eq 'darwin' ) {
	# I presume there's a proper way to do this?
	$perl = scalar File::Which::which('wxPerl');
	chomp($perl);
	unless ( -e $perl ) {
		error("padre needs to run using wxPerl on OSX");
	}
}
my @cmd = (
	qq[$perl],
	qq[-I$FindBin::Bin/lib],
	qq[-I$FindBin::Bin/blib/lib],
);
if ( grep { $_ eq '-a' } @ARGV ) {
	@ARGV = grep { $_ ne '-a' } @ARGV;
	require Class::Autouse;
	Class::Autouse->import( ':devel' );
if ( grep { $_ eq '-d' } @ARGV ) {
	@ARGV = grep { $_ ne '-d' } @ARGV;
	push @cmd, '-d';
}
if ( grep { $_ eq '-p' } @ARGV ) {
	@ARGV = grep { $_ ne '-p' } @ARGV;
	push @cmd, '-d:NYTProf';
}
if ( grep { $_ eq '-h' } @ARGV ) {
	@ARGV = grep { $_ ne '-h' } @ARGV;
	my $dir = File::Basename::dirname($ENV{PADRE_HOME});
	if ( opendir my $dh, $dir ) {
		my @plugins = grep { $_ =~ /^Padre-Plugin-/ } readdir $dh;
		foreach my $plugin ( @plugins ) {
			if( $msgfmt ) {
				convert_po_to_mo("$dir/$plugin");
			}
			push @cmd, "-I$dir/$plugin/lib";
		}
	}
}

system( @cmd, qq[$FindBin::Bin/script/padre], @ARGV );

sub error {
	my $msg = shift;
	$msg =~ s/\n$//s;
	print "\nError:\n$msg\n\n";
	exit(255);
}

sub convert_po_to_mo {
	my $path = shift;
	my @mo;
	if ( $^O eq 'MSWin32' ) {
		@mo = map {
			substr( File::Basename::basename($_), 0, -3 )
		} File::Glob::Windows::glob("$path/share/locale/*.po");
	} else {
		@mo = map {
			substr( File::Basename::basename($_), 0, -3 )
		} glob "$path/share/locale/*.po";
	}
	foreach my $locale ( @mo ) {
		system(
			$msgfmt, "-o",
			"$path/share/locale/$locale.mo",
			"$path/share/locale/$locale.po",
		);
	}
}

#!/usr/bin/perl

use 5.008005;
use strict;
use warnings;
use Config;

# This script is only used to run the application from
# its development location
# No need to distribute it
use FindBin;
use File::Basename ();
$ENV{PADRE_DEV}  = 1;
$ENV{PADRE_HOME} = $FindBin::Bin;
$ENV{PADRE_DIE}  = 1;

use lib $FindBin::Bin;
use privlib::Tools;
use Locale::Msgfmt;

# Due to share functionality, we must have run make
unless ( -d "$FindBin::Bin/blib" ) {
	my $make = $Config::Config{make} || 'make';
	error("You must now have run 'perl Makefile.PL' and '$make' in order to run dev.pl");
}

msgfmt($FindBin::Bin);

my $perl = get_perl();

my @cmd = (
	qq[$perl],
	qq[-I$FindBin::Bin/lib],
	qq[-I$FindBin::Bin/blib/lib],
    qq[-I$FindBin::Bin/../PPIx-EditorTools/lib],
);
if ( grep { $_ eq '-d' } @ARGV ) {
	# Command line debugging
	@ARGV = grep { $_ ne '-d' } @ARGV;
	push @cmd, '-d';
}
if ( grep { $_ eq '-p' } @ARGV ) {
	# Profiling
	@ARGV = grep { $_ ne '-p' } @ARGV;
	push @cmd, '-dt:NYTProf';
}
if ( grep { $_ eq '-h' } @ARGV ) {
	# Rebuild translations
	@ARGV = grep { $_ ne '-h' } @ARGV;
	my $dir = File::Basename::dirname($ENV{PADRE_HOME});
	if ( opendir my $dh, $dir ) {
		my @plugins = grep { $_ =~ /^Padre-Plugin-/ } readdir $dh;
		foreach my $plugin ( @plugins ) {
			(my $path = $plugin) =~ s{-}{/}g;
			if (-d  "$dir/$plugin/share/locale" ) {
				msgfmt("$dir/$plugin");
			} elsif (-d "$dir/$plugin/lib/$path/share/locale") {
				msgfmt("$dir/$plugin/lib/$path");
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


#!/usr/bin/perl

# This script is only used to run the application from
# its development location
# 
# It should not be distributed on CPAN or downstream distributions

use 5.008005;
use strict;
use warnings;
use FindBin;
use Config;

$ENV{PADRE_DEV}  = 1;
$ENV{PADRE_HOME} = $FindBin::Bin;

use lib $FindBin::Bin, "$FindBin::Bin/lib";
use privlib::Tools;
use File::Basename ();
use Locale::Msgfmt 0.12;
use Padre::Perl    ();

# Due to share functionality, we must have run make
unless ( -d "$FindBin::Bin/blib" ) {
	my $make = $Config::Config{make} || 'make';
	error("You must now have run 'perl Makefile.PL' and '$make' in order to run dev.pl");
}

vmsgfmt($FindBin::Bin);

my $perl = Padre::Perl::wxperl();
unless ( $perl ) {
	error("Failed to find windowing Perl to run with");
}

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
if ( grep { $_ eq '--die' } @ARGV ) {
	# Command line debugging
	@ARGV = grep { $_ ne '--die' } @ARGV;
	$ENV{PADRE_DIE}  = 1;
}
if ( grep { $_ eq '-p' } @ARGV ) {
	# Profiling
	@ARGV = grep { $_ ne '-p' } @ARGV;
	push @cmd, '-dt:NYTProf';
}
if ( grep { $_ eq '-h' } @ARGV ) {
	usage();
} elsif ( grep { $_ eq '-a' } @ARGV ) {
	# Rebuild translations
	@ARGV = grep { $_ ne '-a' } @ARGV;
	my $dir = File::Basename::dirname($ENV{PADRE_HOME});
	if ( opendir my $dh, $dir ) {
		my @plugins = grep { $_ =~ /^Padre-Plugin-/ } readdir $dh;
		foreach my $plugin ( @plugins ) {
			(my $path = $plugin) =~ s{-}{/}g;
			if (-d  "$dir/$plugin/share/locale" ) {
				vmsgfmt("$dir/$plugin");
			} elsif (-d "$dir/$plugin/lib/$path/share/locale") {
				vmsgfmt("$dir/$plugin/lib/$path");
			}
			push @cmd, "-I$dir/$plugin/lib";
		}
	}
}

system( @cmd, qq[$FindBin::Bin/script/padre], @ARGV );

sub vmsgfmt {
	msgfmt( {
		in      => "$_[0]/share/locale/",
		verbose => 0,
	} );
}

sub error {
	my $msg = shift;
	$msg =~ s/\n$//s;
	print "\nError:\n$msg\n\n";
	exit(255);
}

sub usage {
	print <<"END_USAGE";
Usage: $0
        -h     show this help
        -d     run Padre in the command line debugger (-d)
        -p     run Padre under -dt:NYTProf
        -a     add the pathe to the lib directory of all the plugins in trunk/
        --die  add DIE handler

       LIST OF FILES    list of files to open
END_USAGE
	exit 0;
}


#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

# This script is only used to run the application from
# its development location
# No need to distribute it
use FindBin;
use File::Basename ();
use Probe::Perl;
$ENV{PADRE_DEV}  = 1;
$ENV{PADRE_HOME} = $FindBin::Bin;

# Due to share functionality, we must have run make
unless ( -d "$FindBin::Bin/blib" ) {
	die "You must now have run make in order to run dev.pl";
}

if ($^O eq 'linux') {
	if( my $msgfmt = `which msgfmt`) {
		chomp $msgfmt;
		foreach my $locale (map { substr(File::Basename::basename($_), 0, -3) } glob "share/locale/*.po") {
			#print "$locale\n";
			system("$msgfmt -o share/locale/$locale.mo share/locale/$locale.po");	
		}
	}
}

my $perl = Probe::Perl->find_perl_interpreter;
if ( $^O eq 'darwin' ) {
	#I presume there's a proper way to do this?
	$perl = `which wxPerl`;
	chomp($perl);
	die "padre needs to run using wxPerl on OSX" unless (-e $perl);
}
my @cmd  = (
	qq[$perl],
	qq[-I$FindBin::Bin/lib],
	qq[-I$FindBin::Bin/blib/lib],
#	qq[-I$FindBin::Bin/../projects/Wx-Perl-Dialog/lib], # Why would we need this?
);
if ( grep { $_ eq '-d' } @ARGV ) {
	@ARGV = grep { $_ ne '-d' } @ARGV;
	push @cmd, '-d';
}
if ( grep { $_ eq '-p' } @ARGV ) {
	@ARGV = grep { $_ ne '-p' } @ARGV;
	push @cmd, '-d:NYTProf';
}
push @cmd, qq[$FindBin::Bin/script/padre], @ARGV;
system( @cmd );

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

# Collect options early
use Getopt::Long ();
use vars qw{
	$DEBUG
	$TRACE
	$DIE
	$PROFILE
	$PLUGINS
	$USAGE
	$FULLTRACE
	$INVISIBLE
	@INCLUDE
};

BEGIN {
	$DEBUG     = 0;
	$DIE       = 0;
	$PROFILE   = 0;
	$PLUGINS   = 0;
	$USAGE     = 0;
	$FULLTRACE = 0;
	$INVISIBLE = 0;
	@INCLUDE   = ();
	Getopt::Long::GetOptions(
		'usage|help' => \$USAGE,
		'debug|d'    => \$DEBUG,
		'trace'      => sub {
			$ENV{PADRE_DEBUG} = 1;
		},
		'die'         => \$DIE,
		'profile'     => \$PROFILE,
		'a'           => \$PLUGINS,
		'fulltrace'   => \$FULLTRACE,
		'invisible'   => \$INVISIBLE,
		'include|i:s' => \@INCLUDE,
	);
}

$USAGE and usage();

$ENV{PADRE_DEV}  = 1;
$ENV{PADRE_HOME} = $FindBin::Bin;
$ENV{PADRE_DIE}  = $DIE;

use lib $FindBin::Bin, "$FindBin::Bin/lib";
use privlib::Tools;
use File::Basename ();
use Locale::Msgfmt 0.12;
use Padre::Perl ();

# Due to share functionality, we must have run make
unless ( -d "$FindBin::Bin/blib" ) {
	my $make = $Config::Config{make} || 'make';
	error("You must now have run 'perl Makefile.PL' and '$make' in order to run dev.pl");
}

vmsgfmt($FindBin::Bin);

my $perl =
	( $^O eq 'MSWin32' )
	? Padre::Perl::cperl()
	: Padre::Perl::wxperl();
unless ($perl) {
	error("Failed to find windowing Perl to run with");
}

my @cmd = (
	qq[$perl],
	qq[-I$FindBin::Bin/lib],
	qq[-I$FindBin::Bin/blib/lib],
	qq[-I$FindBin::Bin/../PPIx-EditorTools/lib],
);
push @cmd, '-MPadre::Test' if $INVISIBLE;
push @cmd, '-d'            if $DEBUG;
push @cmd, '-dt:NYTProf'   if $PROFILE;
push @cmd, map {qq[-I$_]} @INCLUDE;

if ($FULLTRACE) {
	eval { require Devel::Trace; };
	if ($@) {
		print "Error while initilizing --fulltrace while trying to load Devel::Trace:\n"
			. "$@Maybe Devel::Trace isn't installed?\n";
		exit 1;
	}
	push @cmd, '-d:Trace';
}

# Rebuild translations
if ($PLUGINS) {
	my $dir = File::Basename::dirname( $ENV{PADRE_HOME} );
        $dir =~ s/\bbranches$/trunk/;
	if ( opendir my $dh, $dir ) {
		my @plugins = grep { $_ =~ /^Padre-Plugin-/ } readdir $dh;
		foreach my $plugin (@plugins) {
			( my $path = $plugin ) =~ s{-}{/}g;
			if ( -d "$dir/$plugin/share/locale" ) {
				vmsgfmt("$dir/$plugin");
			} elsif ( -d "$dir/$plugin/lib/$path/share/locale" ) {
				vmsgfmt("$dir/$plugin/lib/$path");
			}
			push @cmd, "-I$dir/$plugin/lib";
		}
	}
}

push @cmd, qq[$FindBin::Bin/script/padre], @ARGV;

push @cmd, '--help' if $USAGE;

$DEBUG and print "Running " . join( ' ', @cmd ) . "\n";

system(@cmd);

sub vmsgfmt {
	msgfmt(
		{   in      => "$_[0]/share/locale/",
			verbose => 0,
		}
	);
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
        -h          show this help
        -d          run Padre in the command line debugger (-d)
	-t          write tracing information to .padre/debug.log
        -p          profile using Devel::NYTProf
        -a          load all plugins in the svn checkout
        --die       add DIE handler
        --fulltrace full sourcecode trace to STDERR

       LIST OF FILES    list of files to open

The following Padre options are accepted if you put a -- between
$0 and Padre options (like "$0 --die -- --version"):

END_USAGE
}


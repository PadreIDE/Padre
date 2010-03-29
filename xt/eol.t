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

# Checks for UNIX end of lines (aka newlines)
use File::Find::Rule;
use t::lib::Padre;
use Padre::Util ();

my @files =
	File::Find::Rule->file->name( '*.pm', '*.pod', '*.pl', '*.p6', '*.t', '*.yml', '*.txt' )->in( 'lib', 't', 'share' );
@files = ( @files, 'Artistic', 'COPYING', 'Makefile.PL', 'Changes', 'padre.yml' );

plan( tests => scalar @files );
foreach my $file (@files) {
	my $eol = Padre::Util::newline_type( slurp($file) );
	ok( ( $eol eq 'UNIX' ) || ( $eol eq 'None' ), "$file has UNIX-EOLs or none" );
}

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	binmode $fh;
	local $/ = undef;
	return <$fh>;
}

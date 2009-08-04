package privlib::Tools;

use strict;
use warnings;
use Exporter ();

our @ISA    = 'Exporter';
our @EXPORT = qw(convert_po_to_mo get_perl);

use File::Which    ();
use File::Basename ();

if ( $^O eq 'MSWin32' ) {
	# "Default glob() will misinterpret spaces in folder names as seperators, install File::Glob::Windows to fix this behavior!");
	require File::Glob::Windows;
}

sub get_perl {
	require Padre::Perl;
	my $perl = Padre::Perl::wxperl();
	unless ( -e $perl ) {
		error("padre needs to run using wxPerl on OSX");
	}
	return $perl;
}

1;

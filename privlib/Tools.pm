package privlib::Tools;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(convert_po_to_mo get_perl);

use File::Which    ();
use Probe::Perl    ();
use File::Basename ();
if ( $^O eq 'MSWin32' ) {
	# "Default glob() will misinterpret spaces in folder names as seperators, install File::Glob::Windows to fix this behavior!");
	require File::Glob::Windows;
}

sub get_perl {
	my $perl = Probe::Perl->find_perl_interpreter;
	if ( $^O eq 'darwin' ) {
		# I presume there's a proper way to do this?
		$perl = scalar File::Which::which('wxPerl');
		chomp($perl);
		unless ( -e $perl ) {
			error("padre needs to run using wxPerl on OSX");
		}
	}
	return $perl;
}

1;

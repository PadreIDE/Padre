package Padre::Wx::Print;

use strict;
use warnings;

use Wx::Print;
use Padre::Wx::Print::Printout;

our $VERSION = '0.20';

sub OnPrint {
	my ( $win, $event ) = @_;

	my $printer = Wx::Printer->new;
	my $printout = Padre::Wx::Print::Printout->new( $win->selected_editor, "Print" );

	$printer->Print( $win, $printout, 1 );

	$printout->Destroy;
	return;
}

1;



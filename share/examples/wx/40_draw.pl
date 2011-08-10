#!/usr/bin/perl 
use strict;
use warnings;


#############################################################################
## Name:        lib/Wx/DemoModules/wxPrinting.pm
## Based on the Printing demo by Mattia Barbon distribured in the Wx::Demo
## Copyright:   (c) 2001, 2003, 2005-2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Demo::App;
use strict;
use warnings;

use base 'Wx::App';

sub OnInit {
	my $frame = Demo::Frame->new;
	$frame->Show(1);
}

#####################
package Demo::Frame;
use strict;
use warnings FATAL => 'all';

use Wx ':everything';
use Wx::Event ':everything';

use base 'Wx::Frame';

our $VERSION = '0.01';


sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'Draw',
		[ -1,  -1 ],
		[ 750, 700 ],
	);

	my $canvas = Demo::Canvas->new($self);
	EVT_CLOSE( $self, \&on_close_window );

	return $self;
}

sub on_close_window {
	my ( $self, $event ) = @_;
	$event->Skip;
}


#####################
package Demo::Canvas;
use strict;
use warnings;

use Wx ':everything';
use Wx::Event ':everything';

use base qw(Wx::ScrolledWindow);

my ( $x_size, $y_size ) = ( 750, 650 );

sub new {
	my $class = shift;
	my $this  = $class->SUPER::new(@_);

	$this->SetScrollbars( 1, 1, $x_size, $y_size );
	$this->SetBackgroundColour(wxWHITE);
	$this->SetCursor( Wx::Cursor->new(wxCURSOR_PENCIL) );

	EVT_MOTION( $this, \&OnMouseMove );
	EVT_LEFT_DOWN( $this, \&OnButton );
	EVT_LEFT_UP( $this, \&OnButton );

	return $this;
}

sub OnDraw {
	my $this = shift;
	my $dc   = shift;

	#  my $font = Wx::Font->new( 20, wxSCRIPT, wxSLANT, wxBOLD );

	#  $dc->SetFont( $font );
	$dc->DrawRotatedText( "Draw Here", 200, 200, 35 );

	$dc->DrawEllipse( 20, 20, 50, 50 );

	$dc->SetPen( Wx::Pen->new( wxBLACK, 3, 0 ) );
	$dc->DrawEllipse( 20, $y_size - 50 - 20, 50, 50 );

	$dc->SetPen( Wx::Pen->new( wxGREEN, 5, 0 ) );
	$dc->DrawEllipse( $x_size - 50 - 20, 20, 50, 50 );
	$dc->SetPen( Wx::Pen->new( wxBLUE, 5, 0 ) );
	$dc->DrawEllipse( $x_size - 50 - 20, $y_size - 50 - 20, 50, 50 );

	$dc->CrossHair( 100, 100 );
	$dc->SetPen( Wx::Pen->new( wxRED, 5, 0 ) );


}


sub OnMouseMove {
	my ( $this, $event ) = @_;

	return unless $event->Dragging;

	my $dc = Wx::ClientDC->new($this);

	#$this->PrepareDC( $dc );
	my $pos = $event->GetLogicalPosition($dc);
	my ( $x, $y ) = ( $pos->x, $pos->y );

	push @{ $this->{CURRENT_LINE} }, [ $x, $y ];
	my $elems = @{ $this->{CURRENT_LINE} };

	$dc->SetPen( Wx::Pen->new( wxRED, 5, 0 ) );
	$dc->DrawLine(
		@{ $this->{CURRENT_LINE}[ $elems - 2 ] },
		@{ $this->{CURRENT_LINE}[ $elems - 1 ] }
	);

}

sub OnButton {
	my ( $this, $event ) = @_;

	my $dc = Wx::ClientDC->new($this);
	$this->PrepareDC($dc);
	my $pos = $event->GetLogicalPosition($dc);
	my ( $x, $y ) = ( $pos->x, $pos->y );

	if ( $event->LeftUp ) {
		push @{ $this->{CURRENT_LINE} }, [ $x, $y ];
		push @{ $this->{LINES} }, $this->{CURRENT_LINE};
		$this->ReleaseMouse;
	} else {
		$this->{CURRENT_LINE} = [ [ $x, $y ] ];
		$this->CaptureMouse;
	}

	$dc->SetPen( Wx::Pen->new( wxRED, 5, 0 ) );
	$dc->DrawLine( $x, $y, $x, $y );
}

#####################
package main;

my $app = Demo::App->new;
$app->MainLoop;


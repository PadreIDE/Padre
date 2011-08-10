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

# See http://docs.wxwidgets.org/2.8.10/wx_wxdc.html

# http://wiki.wxpython.org/DoubleBufferedDrawing

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

use File::Spec;
use File::Basename;

use base qw(Wx::ScrolledWindow);

my ( $x_size, $y_size ) = ( 750, 650 );

sub new {
	my $class = shift;
	my $this  = $class->SUPER::new(@_);

	$this->SetScrollbars( 1, 1, $x_size, $y_size );
	$this->SetBackgroundColour(wxWHITE);

	#  $this->SetCursor( Wx::Cursor->new( wxCURSOR_PENCIL ) );

	EVT_MOTION( $this, \&OnMouseMove );
	EVT_LEFT_DOWN( $this, \&OnButton );
	EVT_LEFT_UP( $this, \&OnButton );

	my $path = File::Spec->catfile( File::Basename::dirname($0), 'img', 'padre_logo_64x64.png' );
	my $image = Wx::Image->new;
	Wx::InitAllImageHandlers();
	print "new $path\n";
	$image->LoadFile( $path, Wx::wxBITMAP_TYPE_ANY() );

	#printf("Image (%s, %s)\n", $image->GetWidth, $image->GetHeight);
	$this->{_bitmap}   = Wx::Bitmap->new($image);
	$this->{_bitmap_x} = 20;
	$this->{_bitmap_y} = 30;
	$this->{_backup}   = Wx::MemoryDC->new;
	$this->{_backup}->SelectObject( Wx::Bitmap->new( $image->GetWidth, $image->GetHeight ) );

	return $this;
}

sub OnDraw {
	my $this = shift;
	my $dc   = shift;

	print "OnDraw\n";
	$dc->SetPen( Wx::Pen->new( wxBLUE, 5, 0 ) );
	$dc->CrossHair( 100, 100 );
	$dc->DrawRotatedText( "Drag the butterfly", 200, 200, 35 );

	$this->_draw($dc);
}

sub _draw {
	my $this = shift;
	my $dc   = shift;

	#  $this->{_backup}->SelectObject($this->{_bitmap});
	# restore from backup
	printf(
		"Blit (%s, %s, %s, %s)\n", $this->{_bitmap_x}, $this->{_bitmap_y}, $this->{_bitmap}->GetWidth,
		$this->{_bitmap}->GetHeight
	);
	$this->{_backup}->Blit(
		0, 0, $this->{_bitmap}->GetWidth, $this->{_bitmap}->GetHeight, $dc, $this->{_bitmap_x},
		$this->{_bitmap_y}
	);
	$dc->DrawBitmap( $this->{_bitmap}, $this->{_bitmap_x}, $this->{_bitmap_y}, 1 );
}


sub OnMouseMove {
	my ( $this, $event ) = @_;

	return unless $event->Dragging;
	return unless $this->{_grab};

	my $dc = Wx::ClientDC->new($this);

	#$this->PrepareDC( $dc );
	my $pos = $event->GetLogicalPosition($dc);
	my ( $x, $y ) = ( $pos->x, $pos->y );
	print "pos ($x, $y)\n";

	# restore image of the location
	$dc->Blit(
		$this->{_bitmap_x}, $this->{_bitmap_y}, $this->{_bitmap}->GetWidth, $this->{_bitmap}->GetHeight,
		$this->{_backup},   0,                  0
	);

	$this->{_bitmap_x} += $x - $this->{_mouse_x};
	$this->{_bitmap_y} += $y - $this->{_mouse_y};
	$this->{_mouse_x} = $x;
	$this->{_mouse_y} = $y;
	$this->_draw($dc);
}

sub OnButton {
	my ( $this, $event ) = @_;

	my $dc = Wx::ClientDC->new($this);
	$this->PrepareDC($dc);
	my $pos = $event->GetLogicalPosition($dc);
	my ( $x, $y ) = ( $pos->x, $pos->y );
	print "Pos ($x, $y)\n";
	$this->{_mouse_x} = $x;
	$this->{_mouse_y} = $y;



	if ( $event->LeftUp ) {
		$this->ReleaseMouse;
		$this->{_grab} = 0;
	} else {
		if (    $x >= $this->{_bitmap_x}
			and $x < $this->{_bitmap_x} + $this->{_bitmap}->GetWidth
			and $y >= $this->{_bitmap_y}
			and $y < $this->{_bitmap_y} + $this->{_bitmap}->GetHeight )
		{
			$this->{_grab} = 1;

		}
		$this->CaptureMouse;
	}
}

#####################
package main;

my $app = Demo::App->new;
$app->MainLoop;


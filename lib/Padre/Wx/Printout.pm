package Padre::Wx::Printout;

use 5.008;
use strict;
use warnings;
use Padre::Wx 'Print';

our $VERSION = '0.94';
our @ISA     = 'Wx::Printout';

sub new {
	my $class  = shift;
	my $editor = shift;
	my $self   = $class->SUPER::new(@_);

	$self->{EDITOR}  = $editor;
	$self->{PRINTED} = 0;

	return $self;
}

sub OnPrintPage {
	my ( $self, $page ) = @_;
	my $dc = $self->GetDC;

	return 0 unless defined $dc;

	$self->PrintScaling($dc);

	my $e = $self->{EDITOR};

	if ( $page == 1 ) {
		$self->{PRINTED} = 0;
	}
	$self->{PRINTED} =
		$e->FormatRange( 1, $self->{PRINTED}, $e->GetLength, $dc, $dc, $self->{printRect}, $self->{pageRect} );

	return 1;
}

sub GetPageInfo {
	my $self = shift;
	my ( $minPage, $maxPage, $selPageFrom, $selPageTo ) = ( 0, 0, 0, 0 );

	my $dc = $self->GetDC;
	if ( not defined $dc ) {
		return ( $minPage, $maxPage, $selPageFrom, $selPageTo );
	}
	$self->PrintScaling($dc);

	# get print page informations and convert to printer pixels
	my ( $x, $y ) = $self->GetPPIScreen;
	my $ppiScr = Wx::Size->new( $x, $y );

	my $pageSize = Wx::Size->new( $self->GetPageSizeMM );
	$pageSize->SetWidth( int( $pageSize->GetWidth * $ppiScr->GetWidth / 25.4 ) );
	$pageSize->SetHeight( int( $pageSize->GetHeight * $ppiScr->GetHeight / 25.4 ) );

	$self->{pageRect} = Wx::Rect->new( 0, 0, $pageSize->GetWidth, $pageSize->GetHeight );

	# my $topLeft  = $psdd->GetMarginTopLeft;
	my $left = 25.4; # $topLeft->x;
	my $top  = 25.4; # $topLeft->y;

	# my $btmRight = $psdd->GetMarginBottomRight;
	my $right  = Wx::Size->new( $self->GetPageSizeMM )->GetWidth - 50.8; # $btmRight->x;
	my $bottom = 25.4;                                                   # $btmRight->y;

	$top    = int( $top * $ppiScr->GetHeight / 25.4 );
	$bottom = int( $bottom * $ppiScr->GetHeight / 25.4 );
	$left   = int( $left * $ppiScr->GetWidth / 25.4 );
	$right  = int( $right * $ppiScr->GetWidth / 25.4 );

	$self->{printRect} = Wx::Rect->new(
		int( $left * $dc->GetUserScale ),
		int( $top * $dc->GetUserScale ),
		$right,
		( $pageSize->GetHeight - int( ( $top + $bottom ) * $dc->GetUserScale ) )
	);

	while ( $self->HasPage($maxPage) ) {
		$self->{PRINTED} = $self->{EDITOR}->FormatRange(
			0,
			$self->{PRINTED},
			$self->{EDITOR}->GetLength,
			$dc,
			$dc,
			$self->{printRect},
			$self->{pageRect}
		);

		$maxPage += 1;
	}
	$self->{PRINTED} = 0;

	if ( $maxPage > 0 ) {
		$minPage = 1;
	}
	$selPageFrom = $minPage;
	$selPageTo   = $maxPage;
	return ( $minPage, $maxPage, $selPageFrom, $selPageTo );
}

sub HasPage {
	my $self = shift;
	my $page = shift;

	return $self->{PRINTED} < $self->{EDITOR}->GetLength;
}

sub PrintScaling {
	my $self = shift;
	my $dc   = shift;

	return 0 unless defined $dc;

	my ( $sx, $sy ) = $self->GetPPIScreen;

	my $ppiScr = Wx::Size->new( $sx, $sy );
	if ( $ppiScr->GetWidth == 0 ) { # guessing 96 dpi
		$ppiScr->SetWidth(96);
		$ppiScr->SetHeight(96);
	}

	my ( $px, $py ) = $self->GetPPIPrinter;
	my $ppiPrt = Wx::Size->new( $px, $py );

	if ( $ppiPrt->GetWidth == 0 ) { # scaling factor 1
		$ppiPrt->SetWidth( $ppiScr->GetWidth );
		$ppiPrt->SetHeight( $ppiScr->GetHeight );
	}

	my $dcSize = $dc->GetSize;
	my ( $pax, $pay ) = $self->GetPageSizePixels;
	my $pageSize = Wx::Size->new( $pax, $pay );

	# set user scale
	my $scale_x = ( $ppiPrt->GetWidth * $dcSize->GetWidth ) /   ( $ppiScr->GetWidth * $pageSize->GetWidth );
	my $scale_y = ( $ppiPrt->GetHeight * $dcSize->GetHeight ) / ( $ppiScr->GetHeight * $pageSize->GetHeight );

	$dc->SetUserScale( $scale_x, $scale_y );

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

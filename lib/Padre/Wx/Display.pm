package Padre::Wx::Display;

=pod

=head1 NAME

Padre::Wx::Display - Utility functions for physical display geometry

=head1 DESCRIPTION

This module provides a collection of utility functions relating to
the physical display geometry of the host Padre is running on.

These functions help choose the most visually elegant default sizes
and positions for Padre windows, and allow Padre to adapt when the
screen geometry of the host changes (which can be fairly common in
the case of powerful multi-screen developer computers).

=head1 FUNCTIONS

=cut

use 5.008;
use strict;
use warnings;
use List::Util ();
use Padre::Wx  ();

our $VERSION = '0.60';

use constant GOLDEN => 1.618;





######################################################################
# Main Functions

=pod

=head2 primary

Locates and returns the primary display as a L<Wx::Display> object.

=cut

sub primary {
	my $primary = '';
	foreach ( 0 .. Wx::Display::GetCount() - 1 ) {
		$primary = Wx::Display->new($_);
		last if $primary->IsPrimary;
	}
	return $primary;
}

=pod

=head2 primary_default

Generate a L<Wx::Rect> (primarily for the L<Padre::Wx::Main>
window) which is a landscape-orientation golden-ratio rectangle
on the primary display with a 10% margin.

=cut

sub primary_default {
	my $primary = primary();
	return _rect_golden(
		_rect_scale_margin(
			$primary->GetClientArea,
			0.9,
		),
	);
}





######################################################################
# Support Functions

# Convert a Wx::Rect object to a string
sub _rect_as_string {
	my $rect = shift;
	return join(
		',',
		$rect->x,
		$rect->y,
		$rect->width,
		$rect->height,
	);
}

# Convert a string back into a Wx::Rect
sub _rect_from_string {
	Wx::Rect->new( split /,/, $_[0] );
}

# Scale a rect by some ratio at the centre
sub _rect_scale {
	my $rect   = shift;
	my $ratio  = shift;
	my $margin = ( 1 - $ratio ) / 2;
	$rect->width( int( $rect->width * $ratio ) );
	$rect->height( int( $rect->height * $ratio ) );
	$rect->x( $rect->x + int( $rect->width * $margin ) );
	$rect->y( $rect->y + int( $rect->height * $margin ) );
	return $rect;
}

# Scale a rect by some ration at the centre,
# while retaining a consistent margin.
sub _rect_scale_margin {
	my $rect    = shift;
	my $ratio   = shift;
	my $marginr = ( 1 - $ratio ) / 2;
	my $marginx = int( $rect->width * $marginr );
	my $marginy = int( $rect->height * $marginr );
	my $margin  = ( $marginx > $marginy ) ? $marginy : $marginx;
	$rect->width( $rect->width - $margin * 2 );
	$rect->height( $rect->height - $margin * 2 );
	$rect->x( $rect->x + $margin );
	$rect->y( $rect->y + $margin );
	return $rect;
}

# Shrink long size to meet the (landscape) golden (aspect) ratio.
sub _rect_golden {
	my $rect = shift;
	if ( $rect->width > ( $rect->height * GOLDEN ) ) {

		# Shrink left from the right
		$rect->width( int( $rect->height / GOLDEN ) );
	} else {

		# Shrink up from the bottom
		$rect->height( int( $rect->width / GOLDEN ) );
	}
	return $rect;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

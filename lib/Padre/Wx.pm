package Padre::Wx;

# Provides a set of Wx-specific miscellaneous functions

use 5.008;
use strict;
use warnings;
use FindBin;
use File::Spec ();

# Load every exportable constant into here, so that they come into
# existance in the Wx:: packages, allowing everywhere else in the code to
# use them without braces.
use Wx          ':everything';
use Wx          'wxTheClipboard';
use Wx::Event   ':everything';
use Wx::STC     ();
use Wx::AUI     ();
use Wx::Locale  ();
use Padre::Util ();

our $VERSION = '0.27';





#####################################################################
# Defines for sidebar marker; others may be needed for breakpoint
# icons etc.

sub MarkError { 1 }
sub MarkWarn  { 2 }





#####################################################################
# Defines for object IDs

sub ID_TIMER_SYNTAX    { 30001 }
sub ID_TIMER_FILECHECK { 30002 }
sub ID_TIMER_POSTINIT  { 30003 }
sub ID_TIMER_OUTLINE   { 30004 }




#####################################################################
# Convenience Functions

sub color {
	my $rgb = shift;
	my @c   = ( 0xFF, 0xFF, 0xFF ); # Some default
	if ( not defined $rgb ) {
		# Carp::cluck("undefined color");
	} elsif ( $rgb =~ /^(..)(..)(..)$/ ) {
		@c = map { hex($_) } ($1, $2, $3);
	} else {
		# Carp::cluck("invalid color '$rgb'");
	}
	return Wx::Colour->new(@c);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

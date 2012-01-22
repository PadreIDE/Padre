package Padre::Wx::ComboBox::FindTerm;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::ComboBox::History ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::ComboBox::History';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Bind some default behaviour for all of these objects
	Wx::Event::EVT_TEXT(
		$self,
		$self,
		sub {
			shift->on_text(@_);
		},
	);

	# Make sure we are being created in a usable context
	unless ( $self->GetParent->can('as_search') ) {
		die "FindTerm created in parent without as_search";
	}

	return $self;
}





######################################################################
# Event Handlers

sub on_text {
	my $self  = shift;
	my $event = shift;
	my $lock  = Wx::WindowUpdateLocker->new($self);

	# Show the bad colour if there is an illegal search
	if ( $self->GetValue eq '' or $self->GetParent->as_search ) {
		$self->SetBackgroundColour($self->base_colour);
	} else {
		$self->SetBackgroundColour($self->bad_colour);
	}

	$event->Skip(1);
}





######################################################################
# Support Methods

sub base_colour {
	Wx::SystemSettings::GetColour( Wx::SYS_COLOUR_WINDOW );
}

sub bad_colour {
	my $self = shift;
	my $base = $self->base_colour;
	return Wx::Colour->new(
		$base->Red,
		int( $base->Green * 0.5 ),
		int( $base->Blue  * 0.5 ),
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

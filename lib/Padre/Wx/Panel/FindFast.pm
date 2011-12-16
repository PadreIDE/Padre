package Padre::Wx::Panel::FindFast;

use 5.008;
use strict;
use warnings;
use Padre::Search            ();
use Padre::Wx::FBP::FindFast ();

our $VERSION = '0.93';
our @ISA     = 'Padre::Wx::FBP::FindFast';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Immediately hide the panel to prevent display glitching
	$self->Hide;

	# Create a private pane in AUI
	$self->main->aui->AddPane(
		$self,
		Padre::Wx->aui_pane_info(
			Name           => 'footer',
			PaneBorder     => 0,
			Resizable      => 1,
			CaptionVisible => 0,
			Layer          => 1,
			PaneBorder     => 0,
		)->Bottom->Hide,
	);

	return $self;
}





######################################################################
# Event Handlers

sub on_cancel {
	my $self = shift;
	$self->hide;
	$self->main->editor_focus;
}

sub on_char {
	my $self  = shift;
	my $event = shift;
	$event->Skip(1);
}

sub on_key_up {
	my $self = shift;
	my $event = shift;
	if ( $event->GetKeyCode == Wx::K_RETURN and not $event->HasModifiers) {
		$self->on_text;
	}

	$event->Skip(1);
}

sub on_text {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	my $lock   = $self->lock_update;

	# Reset the search
	$editor->SetSelection( 0, 0 );
	$self->{find_term}->SetBackgroundColour( $self->base_colour );

	# Handle the empty case
	if ( $self->{find_term}->GetValue eq '' ) {
		$self->{find_next}->Enable(0);
		$self->{find_previous}->Enable(0);
		return;
	}

	# Restart the search for each change
	if ( $self->main->search_next( $self->as_search ) ) {
		$self->{find_next}->Enable(1);
		$self->{find_previous}->Enable(1);
	} else {
		$self->{find_term}->SetBackgroundColour( $self->bad_colour );
		$self->{find_next}->Enable(0);
		$self->{find_previous}->Enable(0);
	}
	$self->{find_term}->SetFocus;

	return;
}

# Advance the search to the next match
sub on_next {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	$self->main->search_next( $self->as_search );
}

# Advance the search to the previous match
sub on_previous {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	$self->main->search_previous( $self->as_search );
}





######################################################################
# Main Methods

sub show {
	my $self = shift;
	my $aui  = $self->main->aui;

	# Reset the content of the panel
	$self->{find_term}->SetValue('');
	$self->{find_term}->SetFocus;

	# Show the AUI pane
	$aui->GetPane('footer')->Show;
	$aui->Update;
}

sub hide {
	my $self = shift;
	my $aui  = $self->main->aui;

	# Hide the AUI pane
	$aui->GetPane('footer')->Hide;
	$aui->Update;
}





######################################################################
# Support Methods

sub as_search {
	my $self = shift;
	require Padre::Search;
	Padre::Search->new(
		find_term => $self->{find_term}->GetValue,
		find_case => 1,
	);
}

sub lock_update {
	my $self   = shift;
	my $lock   = Wx::WindowUpdateLocker->new( $self->{find_term} );
	my $editor = $self->current->editor;
	if ($editor) {
		$lock = [ $lock, $editor->lock_update ];
	}
	return $lock;
}

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

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

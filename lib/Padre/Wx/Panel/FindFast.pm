package Padre::Wx::Panel::FindFast;

use 5.008;
use strict;
use warnings;
use Padre::Search            ();
use Padre::Wx::FBP::FindFast ();
use Padre::Logger;

our $VERSION = '0.94';
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

sub on_char {
	my $self  = shift;
	my $event = shift;

	unless ( $event->HasModifiers) {
		my $key = $event->GetKeyCode;

		# Advance to the next match on enter
		if ( $key == Wx::K_RETURN ) {
			TRACE('on_char (return)') if DEBUG;
			if ( $self->{find_next}->IsEnabled ) {
				$self->search_next;
			}
			return $event->Skip(0);
		}

		# Return to the editor on escape
		if ( $key == Wx::K_ESCAPE ) {
			TRACE('on_char (escape)') if DEBUG;
			$self->cancel;
			return $event->Skip(0);
		}
	}

	$event->Skip(1);
}

sub on_text {
	TRACE('on_text') if DEBUG;
	my $self   = shift;
	my $editor = $self->current->editor or return;
	my $lock   = $self->lock_update;

	# Do we have a search
	if ( $self->refresh ) {
		# Reset the background colour
		$self->{find_term}->SetBackgroundColour( $self->base_colour );
	} else {
		# Clear any existing select to prevent
		# showing a stale match result.
		my $position = $editor->GetCurrentPos;
		my $anchor   = $editor->GetAnchor;
		unless ( $position == $anchor ) {
			$editor->SetAnchor($position);
		}

		return;
	}

	# Restart the search for each change
	unless ( $self->{find_term}->GetValue eq $editor->GetSelectedText ) {
		$editor->SetSelection( 0, 0 );
	}

	# Run the search
	unless ( $self->main->search_next( $self->as_search ) ) {
		$self->{find_term}->SetBackgroundColour( $self->bad_colour );
	}

	return;
}

sub on_kill_focus {
	my $self = shift;
	$self->hide;
}

sub cancel {
	TRACE('cancel') if DEBUG;
	my $self = shift;

	# Go back to where we were before if there is no match on close
	$self->restore;
	delete $self->{before};

	# Shift focus to the editor
	$self->main->editor_focus;
	$self->hide;
}

sub restore {
	TRACE('restore') if DEBUG;
	my $self   = shift;
	my $before = $self->{before} or return;
	my $editor = $self->current->editor or return;
	$editor->GetCurrentPos == $editor->GetAnchor or return;
	$editor->GetLineCount  == $before->{lines} or return;

	# Set the selection
	my $lock = $editor->lock_update;
	$editor->SetCurrentPos( $before->{pos} );
	$editor->SetAnchor( $before->{anchor} );

	# Scroll to get the selection to the original position
	unless ( $editor->GetFirstDocumentLine == $before->{first} ) {
		$editor->ScrollToLine( $before->{first} );
	}

	return 1;
}

# Start a fresh search with some text
sub search_start {
	TRACE('search_start') if DEBUG;
	my $self = shift;
	my $text = shift;
	my $lock = $self->lock_update;
	$self->{find_term}->SetValue($text);
	$self->{find_term}->SelectAll;
	return;
}

# Advance the search to the next match
sub search_next {
	TRACE('search_next') if DEBUG;
	my $self   = shift;
	my $search = $self->as_search or return;
	my $editor = $self->current->editor or return;
	$self->main->search_next($search);
}

# Advance the search to the previous match
sub search_previous {
	TRACE('search_previous') if DEBUG;
	my $self   = shift;
	my $search = $self->as_search or return;
	my $editor = $self->current->editor or return;
	$self->main->search_previous($search);
}





######################################################################
# Main Methods

sub show {
	my $self   = shift;
	my $editor = $self->current->editor or return;

	# Capture the selection location before we opened the panel
	$self->{before} = {
		lines  => $editor->GetLineCount,
		pos    => $editor->GetCurrentPos,
		anchor => $editor->GetAnchor,
		first  => $editor->GetFirstDocumentLine,
	};

	# Reset the panel
	$self->{find_term}->ChangeValue('');
	$self->{find_term}->SetBackgroundColour( $self->base_colour );
	$self->{find_term}->SetFocus;
	$self->refresh;

	# Show the AUI pane
	my $aui = $self->main->aui;
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

sub refresh {
	my $self = shift;
	my $show = $self->as_search ? 1 : 0;
	$self->{find_next}->Enable($show);
	$self->{find_previous}->Enable($show);
	return $show;
}





######################################################################
# Support Methods

sub as_search {
	my $self = shift;
	Padre::Search->new(
		find_term => $self->{find_term}->GetValue,
		find_case => 0,
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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

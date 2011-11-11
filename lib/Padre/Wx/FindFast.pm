package Padre::Wx::FindFast;

# Incremental search

use 5.008;
use strict;
use warnings;
use Padre::Current  ();
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.92';

use constant GOOD => Wx::SystemSettings::GetColour( Wx::SYS_COLOUR_WINDOW );
use constant BAD  => Wx::Colour->new(
	GOOD->Red,
	int( GOOD->Green * 0.5 ),
	int( GOOD->Blue  * 0.5 ),
);





######################################################################
# Constructor

sub new {
	my $class = shift;

	my $self = bless {
		restart  => 1,
		backward => 0,
	}, $class;

	return $self;
}

sub find_term {
	my $self = shift;
	my $term = $self->{entry}->GetValue;
	return '' unless defined $term;
	return $term;
}





######################################################################
# Main Methods

#
# search($direction);
#
# initiate/continue searching in $direction.
#
sub search {
	my $self      = shift;
	my $direction = shift;
	my $current   = Padre::Current->new;
	my $editor    = $current->editor or return;

	$self->{backward} = $direction eq 'previous';
	unless ( $self->{panel} ) {
		$self->_create_panel;
	}

	# pane != panel
	my $pane = $current->main->aui->GetPane('find');
	if ( $pane->IsShown ) {
		$self->_find;
	} else {
		$self->_show_panel;
	}
}

# -- Private methods

sub _find {
	my $self    = shift;
	my $current = Padre::Current->new;
	my $editor  = $current->editor or return;
	my $lock    = $self->lock_update;

	# Reset the dialog status
	$self->_status(1);

	# Build the search expression
	my $find_term = $self->{entry}->GetValue;
	if ( length $find_term ) {
		require Padre::Search;
		my $search = Padre::Search->new(
			find_case    => $self->{case}->GetValue,
			find_regex   => 0,
			find_reverse => $self->{backward},
			find_term    => $find_term,
		);

		# Handle restarting the search
		if ( $self->{restart} ) {
			$editor->SetSelection( 0, 0 );
			$self->{restart} = 0;
		}

		# Run the search
		unless ( $current->main->search_next($search) ) {
			$self->_status(0);
		}
		$self->{entry}->SetFocus;
	}

	return;
}

# -- GUI related subs

#
# _create_panel();
#
# create find panel in aui manager.
#
sub _create_panel {
	my $self = shift;
	my $main = Padre::Current->main;

	# The panel and the boxsizer to place controls
	$self->{outer} = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->{panel} = Wx::Panel->new( $main, -1, Wx::DefaultPosition, Wx::DefaultSize );
	$self->{hbox}  = Wx::BoxSizer->new(Wx::HORIZONTAL);

	# Close button
	$self->{close} = Wx::BitmapButton->new(
		$self->{panel}, -1,
		Padre::Wx::Icon::find('actions/x-document-close'),
		Wx::Point->new( -1, -1 ),
		Wx::Size->new( -1, -1 ),
		Wx::BORDER_NONE,
	);
	Wx::Event::EVT_BUTTON( $main, $self->{close}, sub { $self->_hide_panel } );

	# Search area
	$self->{label} = Wx::StaticText->new( $self->{panel}, -1, Wx::gettext('Find:') );
	$self->{entry} = Wx::TextCtrl->new( $self->{panel}, -1, '' );
	$self->{entry}->SetMinSize( Wx::Size->new( 25 * $self->{entry}->GetCharWidth, -1 ) );
	Wx::Event::EVT_CHAR( $self->{entry}, sub { $self->_on_key_pressed( $_[1] ) } );
	Wx::Event::EVT_TEXT( $main, $self->{entry}, sub { $self->_on_entry_changed( $_[1] ) } );

	# Previous button
	$self->{previous} = Wx::BitmapButton->new(
		$self->{panel}, -1,
		Padre::Wx::Icon::find('actions/go-previous'),
		Wx::Point->new( -1, -1 ),
		Wx::Size->new( -1, -1 ),
		Wx::BORDER_NONE
	);

	Wx::Event::EVT_BUTTON( $main, $self->{previous}, sub { $self->search('previous') } );
	$self->{previous_text} = Wx::Button->new(
		$self->{panel}, -1,
		Wx::gettext('Previ&ous'),
		Wx::Point->new( -1, -1 ),
		Wx::Size->new( -1, -1 ),
		Wx::BORDER_NONE,
	);
	Wx::Event::EVT_BUTTON( $main, $self->{previous_text}, sub { $self->search('previous') } );

	# Previous button
	$self->{next} = Wx::BitmapButton->new(
		$self->{panel}, -1,
		Padre::Wx::Icon::find('actions/go-next'),
		Wx::Point->new( -1, -1 ),
		Wx::Size->new( -1, -1 ),
		Wx::BORDER_NONE,
	);
	Wx::Event::EVT_BUTTON( $main, $self->{next}, sub { $self->search('next') } );
	$self->{next_text} = Wx::Button->new(
		$self->{panel}, -1,
		Wx::gettext('&Next'),
		Wx::Point->new( -1, -1 ),
		Wx::Size->new( -1, -1 ),
		Wx::BORDER_NONE,
	);
	Wx::Event::EVT_BUTTON( $main, $self->{next_text}, sub { $self->search('next') } );

	# Case sensitivity
	$self->{case} = Wx::CheckBox->new( $self->{panel}, -1, Wx::gettext('Case &sensitive') );
	Wx::Event::EVT_CHECKBOX( $main, $self->{case}, sub { $self->_on_case_checked } );

	# Place all controls
	$self->{hbox}->Add( $self->{close},         0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( $self->{label},         0, Wx::ALIGN_CENTER_VERTICAL | Wx::LEFT, 10 );
	$self->{hbox}->Add( $self->{entry},         0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( $self->{previous},      0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( $self->{previous_text}, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( $self->{next},          0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( $self->{next_text},     0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( $self->{case},          0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL,  5 );
	$self->{hbox}->Add( 0,                      1, Wx::EXPAND,                           5 );

	$self->{panel}->SetSizer( $self->{hbox} );
	$self->{panel}->Layout;
	$self->{hbox}->Fit( $self->{panel} );

	$self->{outer}->Add( $self->{panel}, 1, Wx::ALIGN_LEFT | Wx::ALL | Wx::EXPAND, 5 );

	my $width  = $main->current->editor->GetSize->GetWidth;
	my $height = $self->{panel}->GetSize->GetHeight;
	my $size   = Wx::Size->new( $width, $height );
	$self->{panel}->SetSize($size);

	# manage the pane in aui
	$main->aui->AddPane(
		$self->{panel},
		Padre::Wx->aui_pane_info(
			Name           => 'find',
			CaptionVisible => 0,
			Layer          => 1,
			PaneBorder     => 0,
			)->Bottom->Fixed->Hide,
	);

	return 1;
}

sub _hide_panel {
	my $self = shift;

	# pane != panel
	my $auimngr = Padre->ide->wx->main->aui;
	$auimngr->GetPane('find')->Hide;
	$auimngr->Update;

	$self->{visible} = 0;

	Padre::Current->editor->SetFocus;

	return 1;
}

sub _show_panel {
	my $self = shift;

	# Create the panel if needed
	unless ( $self->{panel} ) {
		$self->_create_panel;
	}

	# Show the panel; pane != panel
	my $auimngr = Padre->ide->wx->main->aui;
	$auimngr->GetPane('find')->Show(1);
	$auimngr->Update;

	# Reset the form
	$self->_status(1);
	$self->{case}->SetValue(0);
	$self->{entry}->SetValue('');
	$self->{entry}->SetFocus;
	$self->{visible} = 1;

	return 1;
}

sub visible {
	$_[0]->{visible} || 0;
}

# -- Event handlers

#
# _on_case_checked()
#
# called when the "case insensitive" checkbox has changed value. in that
# case, we'll restart searching from the start of the document.
#
sub _on_case_checked {
	my $self = shift;
	$self->{restart} = 1;
	$self->{entry}->SetFocus;
	$self->_find;
}

#
# _on_entry_changed()
#
# called when the entry content has changed (keyboard or other mean). in that
# case, we'll start searching from the start of the document.
#
sub _on_entry_changed {
	my $self = shift;
	$self->{restart} = 1;
	$self->_find;
}

#
# _on_key_pressed()
#
# called when a key is pressed in the entry. used to trap
#		escape so we abort
#		return = find again
# search, otherwise dispatch event up-stack.
#
sub _on_key_pressed {
	my $self  = shift;
	my $event = shift;
	my $mod   = $event->GetModifiers || 0;
	my $code  = $event->GetKeyCode;

	# Remove the bit ( Wx::MOD_META) set by Num Lock being pressed on Linux
	$mod = $mod & ( Wx::MOD_ALT + Wx::MOD_CMD + Wx::MOD_SHIFT );

	if ( $code == Wx::K_ESCAPE ) {
		$self->_hide_panel;
		return;
	}
	if ( $code == Wx::K_RETURN ) {
		$self->_find;
		return;
	}

	$event->Skip(1);
}

# Set the status visuals as good/bad
sub _status {
	$_[0]->{entry}->SetBackgroundColour( $_[1] ? GOOD : BAD );
}

sub lock_update {
	my $self   = shift;
	my $lock   = Wx::WindowUpdateLocker->new( $self->{entry} );
	my $editor = Padre::Current->editor;
	if ($editor) {
		$lock = [ $lock, $editor->lock_update ];
	}
	return $lock;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

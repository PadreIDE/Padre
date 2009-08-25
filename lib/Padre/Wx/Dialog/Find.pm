package Padre::Wx::Dialog::Find;

=pod

=head1 NAME

Padre::Wx::Dialog::Find - Find Widget

=head1 DESCRIPTION

C<Padre::Wx::Dialog::Find> implements Padre's Find dialogs.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util qw{_STRING};
use Padre::Current               ();
use Padre::Search                ();
use Padre::DB                    ();
use Padre::Wx                    ();
use Padre::Wx::Role::MainChild   ();
use Padre::Wx::History::ComboBox ();

our $VERSION = '0.43';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

=pod

=head2 new

  my $find = Padre::Wx::Dialog::Find->new($main)

Create and return a C<Padre::Wx::Dialog::Find> search widget.

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Find'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION | Wx::wxCLOSE_BOX | Wx::wxSYSTEM_MENU
	);

	# Form Components

	# The text to search for
	$self->{find_text} = Padre::Wx::History::ComboBox->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		'search',
	);

	# "Case Sensitive" option
	$self->{find_case} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('Case &Insensitive'),
	);
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{find_case},
		sub {
			$_[0]->{find_text}->SetFocus;
		}
	);

	# "Find as Regex" option
	$self->{find_regex} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('&Regular Expression'),
	);
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{find_regex},
		sub {
			$_[0]->{find_text}->SetFocus;
		}
	);

	# "Find First and Close" option
	$self->{find_first} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('Close Window on &Hit'),
	);
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{find_first},
		sub {
			$_[0]->{find_text}->SetFocus;
		}
	);

	# "Find in Reverse" option
	$self->{find_reverse} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('Search &Backwards'),
	);
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{find_reverse},
		sub {
			$_[0]->{find_text}->SetFocus;
		}
	);

	# The "Find" button
	$self->{button_find} = Wx::Button->new(
		$self,
		Wx::wxID_FIND,
		Wx::gettext("&Find Next"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_find},
		sub {
			$_[0]->find_button;
		},
	);
	$self->{button_find}->SetDefault;

	# The "Count All" button
	$self->{button_count} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("&Count All"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_count},
		sub {
			$_[0]->count_button;
		},
	);

	# The "Cancel" button
	$self->{button_cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext("&Cancel"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->cancel_button;
		}
	);

	# Form Layout

	# Find sizer begins here
	my $find = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self,
			-1,
			Wx::gettext('Find'),
		),
		Wx::wxVERTICAL,
	);
	$find->Add(
		Wx::StaticText->new(
			$self,
			Wx::wxID_STATIC,
			Wx::gettext("Find Text:"),
		),
		0,
		Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
		5,
	);
	$find->Add(
		$self->{find_text},
		3,
		Wx::wxGROW | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
		5,
	);

	# The layout grid for the options
	my $grid = Wx::FlexGridSizer->new( 2, 2, 7, 7 );
	$grid->Add( $self->{find_regex},   0, Wx::wxALIGN_LEFT, 5 );
	$grid->Add( $self->{find_reverse}, 0, Wx::wxALIGN_LEFT, 5 );
	$grid->Add( $self->{find_case},    0, Wx::wxALIGN_LEFT, 5 );
	$grid->Add( $self->{find_first},   0, Wx::wxALIGN_LEFT, 5 );

	# Options sizer begins here
	my $options = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self,
			-1,
			Wx::gettext('Options')
		),
		Wx::wxVERTICAL,
	);
	$options->Add(
		$grid,
		2,
		Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL,
		0,
	);

	# Sizer for the buttons
	my $bottom = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$bottom->Add( $self->{button_find},   0, Wx::wxGROW | Wx::wxLEFT,  5 );
	$bottom->Add( $self->{button_count},  0, Wx::wxGROW, 5 );
	$bottom->Add( $self->{button_cancel}, 0, Wx::wxGROW | Wx::wxRIGHT, 5 );

	# Fill the sizer for the overall dialog
	my $sizer = Wx::FlexGridSizer->new( 1, 1, 0, 0 );
	$sizer->Add( $find,    2, Wx::wxGROW | Wx::wxALL, 5 );
	$sizer->Add( $options, 2, Wx::wxGROW | Wx::wxALL, 5 );
	$sizer->Add( $bottom,  0, Wx::wxALIGN_RIGHT | Wx::wxALL, 5 );

	# Let the widgets control the dialog size
	$self->SetSizer($sizer);
	$sizer->SetSizeHints($self);

	# Update the dialog from configuration
	my $config = $self->current->config;
	$self->{ find_case    }->SetValue( $config->find_case    );
	$self->{ find_regex   }->SetValue( $config->find_regex   );
	$self->{ find_first   }->SetValue( $config->find_first   );
	$self->{ find_reverse }->SetValue( $config->find_reverse );

	return $self;
}

=pod

=head2 find

  $self->find

Grab currently selected text, if any, and place it in find combo box.
Bring up the dialog or perform search for strings' next occurence
if dialog is already displayed.

TODO: if selection is more than one line then consider it as the limit
of the search and not as the string to be used.

=cut

sub find {
	my $self = shift;
	my $text = $self->current->text;

	# No search if no file is open (TODO ??)
	return unless $self->current->editor;

	# TODO: if selection is more than one lines then consider it as the
	# limit of the search and not as the string to be used.
	$text = '' if $text =~ /\n/;

	# Clear out and reset the dialog, then prepare the new find
	$self->{find_text}->refresh;
	$self->{find_text}->SetValue($text);
	$self->{find_text}->SetFocus;

	if ( $self->IsShown ) {
		$self->find_button;
	} else {
		$self->Show(1);
	}

	return;
}





######################################################################
# Button Events

=pod

=head2 find_button

  $self->find_button

Executed when Find button is clicked.

Performs search on the term specified in the dialog.

=cut

sub find_button {
	my $self   = shift;
	my $main   = $self->main;
	my $config = $self->save;

	# Generate the search object
	my $search = $self->as_search;
	unless ( $search ) {
		$main->error("Not a valid search");
		return;
	}

	# Apply the search to the current editor
	$main->search_next($search);

	# If we're only searching once, we won't need the dialog any more
	if ( $self->{find_first}->GetValue ) {
		$self->Hide;
	}

	return;
}

=pod

=head2 cancel_button

  $self->cancel_button

Hide dialog when pressed cancel button.

=cut

sub cancel_button {
	my $self = shift;
	$self->Hide;

	# Keep any setting changes.
	$self->save;

	# As we leave the Find dialog, return the user to the current editor
	# window so they don't need to click it.
	my $editor = $self->current->editor;
	if ( $editor ) {
		$editor->SetFocus;
	}

	return;
}

=pod

=head2 count_button

  $self->count_button

Count and announce the number of matches in the document.

=cut

sub count_button {
	my $self   = shift;
	my $main   = $self->main;
	my $config = $self->save;

	# Generate the search object
	my $search = $self->as_search;
	unless ( $search ) {
		$main->error( Wx::gettext("Not a valid search") );
		return;
	}

	# Find the number of matches
	my $editor  = $self->current->editor or return;
	my $matches = $search->editor_count_all($editor);
	$main->message(
		sprintf(
			Wx::gettext("Found %d matching occurrences"),
			$matches,
		)
	);
}





#####################################################################
# Support Methods

=pod

=head2 as_search

Integration with L<Padre::Search>. Generates a search instance for the currently
configured information in the Find dialog.

Returns a L<Padre::Search> object, or C<undef> if current state of the dialog
does not result in a valid search.

=cut

sub as_search {
	my $self = shift;
	Padre::Search->new(
		find_term    => $self->{find_text}->GetValue,
		find_case    => $self->{find_case}->GetValue,
		find_regex   => $self->{find_regex}->GetValue,
		find_reverse => $self->{find_reverse}->GetValue,
	);
}

# Save the dialog settings to configuration.
# Returns the config object as a convenience.
sub save {
	my $self    = shift;
	my $config  = $self->current->config;
	my $changed = 0;

	foreach my $name (
		qw{
		find_case
		find_regex
		find_first
		find_reverse
		}
		)
	{
		my $value = $self->{$name}->GetValue;
		next if $config->$name() == $value;
		$config->set( $name => $value );
		$changed = 1;
	}

	$config->write if $changed;

	return $config;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

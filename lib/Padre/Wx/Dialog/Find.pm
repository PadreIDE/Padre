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
use Padre::DB                    ();
use Padre::Wx                    ();
use Padre::Wx::Role::MainChild   ();
use Padre::Wx::History::ComboBox ();

our $VERSION = '0.41';
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
	unless ($main) {
		die("Did not pass parent to find dialog constructor");
	}

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Find'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION
		| Wx::wxCLOSE_BOX
		| Wx::wxSYSTEM_MENU
		| Wx::wxRESIZE_BORDER
	);

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
		Wx::gettext('&Use Regex'),
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
	$self->{find} = Wx::Button->new(
		$self,
		Wx::wxID_FIND,
		Wx::gettext("&Find"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{find},
		sub {
			$_[0]->find_clicked;
		}
	);
	$self->{find}->SetDefault;

	# The "Cancel" button
	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext("&Cancel"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{cancel},
		sub {
			$_[0]->cancel;
		}
	);

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
	$find->Add(
		$self->{find_regex},
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5,
	);

	# The layout grid for the options
	my $grid = Wx::FlexGridSizer->new( 2, 2, 0, 0 );
	$grid->AddGrowableCol(1);
	$grid->Add(
		$self->{find_case},
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5,
	);
	$grid->Add(
		$self->{find_reverse},
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5,
	);
	$grid->Add(
		$self->{find_first},
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5,
	);

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
	$bottom->Add(
		$self->{find},
		0,
		Wx::wxGROW | Wx::wxRIGHT,
		5,
	);
	$bottom->Add(
		$self->{cancel},
		0,
		Wx::wxGROW | Wx::wxLEFT,
		5,
	);

	# Fill the sizer for the overall dialog
	my $sizer = Wx::FlexGridSizer->new( 1, 1, 0, 0 );
	$sizer->AddGrowableCol(0);
	$sizer->Add(
		$find,
		2,
		Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL,
		5,
	);
	$sizer->Add(
		$options,
		2,
		Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL,
		5,
	);
	$sizer->Add(
		$bottom,
		0,
		Wx::wxALIGN_RIGHT | Wx::wxALL,
		5,
	);

	# Let the widgets control the dialog size
	$self->SetSizer($sizer);
	$sizer->SetSizeHints($self);

	# Update the dialog from configuration
	my $config = $self->current->config;
	$self->{find_case}->SetValue( $config->find_case );
	$self->{find_regex}->SetValue( $config->find_regex );
	$self->{find_first}->SetValue( $config->find_first );
	$self->{find_reverse}->SetValue( $config->find_reverse );

	return $self;
}

=pod

=head2 cancel

  $self->cancel

Hide dialog when pressed cancel button.

=cut

sub cancel {
	my $self = shift;
	$self->Hide;

	# As we leave the Find dialog, return the user to the current editor
	# window so they don't need to click it.
	my $editor = $self->current->editor;
	if ($editor) {
		$editor->SetFocus;
	}

	return;
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

	return if not $self->current->editor; # no search if no file is open (TODO ??)

	# TODO: if selection is more than one lines then consider it as the limit
	# of the search and not as the string to be used
	$text = '' if $text =~ /\n/;

	# Clear out and reset the dialog, then prepare the new find
	$self->{find_text}->refresh;
	$self->{find_text}->SetValue($text);
	$self->{find_text}->SetFocus;

	if ( $self->IsShown ) {
		$self->find_next;
	} else {
		$self->Show(1);
	}

	return;
}

=pod

=head2 find_clicked

  $self->find_clicked

Executed when Find button is clicked.

Performs search on the term specified in the dialog.

=cut

sub find_clicked {
	my $self   = shift;
	my $config = $self->_sync_config;

	# If we're only searching once, we won't need the dialog any more
	if ( $config->find_first ) {
		$self->Hide;
	}

	# Return false if we don't have anything to search for
	my $search = $self->{find_text}->GetValue;
	return unless defined _STRING($search);

	# Save the search term
	Padre::DB::History->create(
		type => 'search',
		name => $search,
	) if $search;

	# Execute the first search
	$self->search;

	return;
}

=pod

=head2 find_next

  $self->find_next

Search for given string's next occurence.  If no string is available
(either as a selected text in editor, if Quick Find is on, or from
search history) run C<find> method.

=cut

sub find_next {
	my $self    = shift;
	my $current = $self->current;
	my $term    = Padre::DB::History->previous('search');

	# This is for Quick Find
	# Check if is checked
	if ( $current->main->menu->search->{quick_find}->IsChecked ) {
		my $text = $current->text;
		if ( length $text and $text ne $term ) {
			Padre::DB::History->create(
				type => 'search',
				name => $text,
			);
		}
	}

	if ($term) {
		$self->search;
	} else {
		$self->find;
	}

	return;
}

=pod

=head2 find_previous

  $self->find_previous

Perform backward search for string fetched from search history
or run C<find> method if search history is empty.

=cut

sub find_previous {
	my $self = shift;
	my $term = Padre::DB::History->previous('search');
	if ($term) {
		$self->search( rev => 1 );
	} else {
		$self->find;
	}
	return;
}

=pod

=head2 search

  $self->search

Perform actual search. Highlight (set as selected) found string.

=cut

sub search {
	my $self  = shift;
	my %args  = @_;
	my $regex = $self->_get_search or return;

	# Forwards or backwards
	my $backwards = $self->current->config->find_reverse;
	if ( $args{rev} ) {
		$backwards = not $backwards;
	}

	# Find the range to search within
	my $editor = $self->current->editor;
	return if not $editor; # avoid crash if no file is open
	my $text = $editor->GetTextRange( 0, $editor->GetLength );
	my ( $from, $to ) = $editor->GetSelection;

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = Padre::Util::get_matches( $text, $regex, $from, $to, $backwards );

	if ( !defined $start ) {
		$self->_not_found;
		return;
	}
	$editor->SetSelection( $start, $end );

	return;
}

#####################################################################
# Support Methods

# Save the dialog settings to configuration. Returns the config object
# as a convenience.
sub _sync_config {
	my $self = shift;

	# Save the search settings to config
	my $config = $self->current->config;
	$config->set( find_case    => !$self->{find_case}->GetValue );
	$config->set( find_regex   => $self->{find_regex}->GetValue );
	$config->set( find_first   => $self->{find_first}->GetValue );
	$config->set( find_reverse => $self->{find_reverse}->GetValue );
	$config->write;

	return $config;
}

# Internal method. $self->_get_search( $regex )
# Prepare and return search term defined as a regular expression.
sub _get_search {
	my $self   = shift;
	my $config = $self->current->config;
	my $term   = Padre::DB::History->previous('search');

	# Escape the raw search term
	if ( $config->find_regex ) {

		# Escape non-trailing $ so they won't interpolate
		$term =~ s/\$(?!\z)/\\\$/g;
	} else {

		# Escape everything
		$term = quotemeta $term;
	}

	# Compile the regex
	my $regex = eval { $config->find_case ? qr/$term/m : qr/$term/mi };
	if ($@) {
		Wx::MessageBox(
			sprintf( Wx::gettext("Cannot build regex for '%s'"), $term ),
			Wx::gettext('Search error'),
			Wx::wxOK,
			$self->main,
		);
		return;
	}

	return $regex;
}

sub _not_found {
	my ($self) = @_;

	# Want to see if not found this is
	# where to show a MessageBox.
	my $term = Padre::DB::History->previous('search');
	Wx::MessageBox(
		sprintf( Wx::gettext("Failed to find '%s' in current document."), $term ),
		Wx::gettext('Not Found'),
		Wx::wxOK,
		$self,
	);

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

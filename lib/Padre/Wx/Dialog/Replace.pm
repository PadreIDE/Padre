package Padre::Wx::Dialog::Replace;

=pod

=head1 NAME

Padre::Wx::Dialog::Replace - Find and Replace Widget

=head1 DESCRIPTION

C<Padre::Wx:Main> implements Padre's Find and Replace dialog box.

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

  my $find = Padre::Wx::Dialog::Replace->new($main);

Create and return a C<Padre::Wx::Dialog::Replace> search and replace widget.

=cut

sub new {
	my $class = shift;
	my $main  = shift;
	unless ($main) {
		die("Did not pass parent to replace dialog constructor");
	}

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Find and Replace'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION | Wx::wxCLOSE_BOX | Wx::wxSYSTEM_MENU | Wx::wxRESIZE_BORDER
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

	# The text to replace with
	$self->{replace_text} = Padre::Wx::History::ComboBox->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		'replace',
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
		Wx::gettext('Close Window on &hit'),
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

	# The "Replace All" option
	$self->{replace_all} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext('Replace &All'),
	);
	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{replace_all},
		sub {
			$_[0]->{find_text}->SetFocus;
		}
	);

	# The "Find" button
	$self->{find} = Wx::Button->new(
		$self,
		Wx::wxID_FIND,
		Wx::gettext("&Find Next"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{find},
		sub {
			$_[0]->find_clicked;
		}
	);
	Wx::Event::EVT_CHAR(
		$self->{find},
		sub {
			$self->_on_hotkey( $_[1]->GetKeyCode );
		}
	);

	# The "Replace" button
	$self->{replace} = Wx::Button->new(
		$self,
		Wx::wxID_REPLACE,
		Wx::gettext("&Replace"),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{replace},
		sub {
			$_[0]->replace_clicked;
		}
	);
	Wx::Event::EVT_CHAR(
		$self->{replace},
		sub {
			$self->_on_hotkey( $_[1]->GetKeyCode );
		}
	);
	$self->{replace}->SetDefault;

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

	# Replace sizer begins here
	my $replace = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self,
			-1,
			Wx::gettext('Replace'),
		),
		Wx::wxVERTICAL,
	);
	$replace->Add(
		Wx::StaticText->new(
			$self,
			Wx::wxID_STATIC,
			Wx::gettext("Replace Text:"),
		),
		0,
		Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
		5,
	);
	$replace->Add(
		$self->{replace_text},
		3,
		Wx::wxGROW | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
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
	$grid->Add(
		$self->{replace_all},
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
		$self->{replace},
		0,
		Wx::wxGROW | Wx::wxLEFT | Wx::wxRIGHT,
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
		$replace,
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

If selection is more than one line then consider it as the limit
of the search and not as the string to be used.

=cut

sub find {
	my $self = shift;
	my $text = $self->current->text;

	my $editor = $self->current->editor;
	return unless $editor; # no replace if no file is open

	# If selection is more than one line then consider it as the limit
	# of the search and not as the string to be used (which becomes '')
	if ( $text =~ /\n/ ) {
		$self->{text_offset}     = $editor->GetSelectionStart;
		$self->{text_offset_end} = $editor->GetSelectionEnd;
		$text                    = '';
	} else {
		$self->{text_offset}     = 0;
		$self->{text_offset_end} = $editor->GetLength;
	}

	# Clear out and reset the dialog, then prepare the new find
	$self->{find_text}->refresh;
	$self->{find_text}->SetValue($text);
	$self->{find_text}->SetFocus;
	$self->{replace_text}->refresh;

	if ( $self->IsShown ) {
		$self->find_next;
	} else {
		if ( length $text ) {

			# Go straight to the replace field
			$self->{replace_text}->SetFocus;
		} else {
			$self->{find_text}->SetFocus;
		}
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

	# Get the replace term
	my $replace = $self->{replace_text}->GetValue;

	# Save the terms
	Padre::DB::History->create(
		type => 'search',
		name => $search,
	) if $search;
	Padre::DB::History->create(
		type => 'replace',
		name => $replace,
	) if $replace;

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
	my $self = shift;
	my $term = Padre::DB::History->previous('search');
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
	my $backwards = $self->config->find_reverse;
	if ( $args{rev} ) {
		$backwards = not $backwards;
	}

	# Find the range to search within
	my $editor = $self->current->editor;
	$self->{text} = $editor->GetTextRange( $self->{text_offset}, $self->{text_offset_end} );
	my ( $from, $to ) = $editor->GetSelection;

	# Execute the search and move to the resulting location
	my ( $start, $end, @matches ) = Padre::Util::get_matches(
		$self->{text}, $regex, $from - $self->{text_offset}, $to - $self->{text_offset},
		$backwards
	);
	return unless defined $start;
	$editor->SetSelection( $start + $self->{text_offset}, $end + $self->{text_offset} );

	return;
}

=pod

=head2 replace_clicked

  $self->replace_clicked;

Executed when the Replace button is clicked.

Replaces one appearance of the Find Text with the Replace Text.

If search window is still open, run C<search> on the whole text,
again.

=cut

sub replace_clicked {
	my $self   = shift;
	my $config = $self->_sync_config;

	# If we're only searching once, we won't need the dialog any more
	if ( $config->find_first ) {
		$self->Hide;
	}

	# Return false if we don't have anything to search for
	my $search = $self->{find_text}->GetValue;
	return unless defined _STRING($search);

	# Get the replace term
	my $replace = $self->{replace_text}->GetValue;

	# Save the terms
	Padre::DB::History->create(
		type => 'search',
		name => $search,
	) if $search;
	Padre::DB::History->create(
		type => 'replace',
		name => $replace,
	) if $replace;

	# Execute the replace
	if ( $self->{replace_all}->GetValue ) {
		$self->replace_all;
	} else {
		$self->replace;
	}

	return;
}

=pod

=head2 replace_all

  $self->replace_all;

Executed when Replace All button is clicked.

Replace all appearances of given string in the current document.

=cut

sub replace_all {
	my $self = shift;

	# Prepare the search and replace values
	my $regex = $self->_get_search or return;
	my $replace = $self->_get_replace;
	$replace =~ s/\\t/\t/g if length $replace;

	# Execute the search for all matches
	my $editor = $self->current->editor;
	my $text = $editor->GetTextRange( $self->{text_offset}, $self->{text_offset_end} );
	my ( undef, undef, @matches ) = Padre::Util::get_matches( $text, $regex, 0, 0 );

	# Replace all matches as a single undo
	if (@matches) {
		$editor->BeginUndoAction;
		foreach my $match ( reverse @matches ) {
			$editor->SetTargetStart( $match->[0] + $self->{text_offset} );
			$editor->SetTargetEnd( $match->[1] + $self->{text_offset} );
			$editor->ReplaceTarget($replace);
		}
		$editor->EndUndoAction;

		$self->main->message(
			sprintf(
				Wx::gettext('%s occurences were replaced'),
				scalar @matches
			)
		);
	} else {
		$self->main->message( Wx::gettext("Nothing to replace") );
	}

	return;
}

=pod

  $self->replace;

Perform actual single replace. Highlight (set as selected) found string.

=cut

sub replace {
	my $self    = shift;
	my $current = $self->current;
	my $text    = $current->text;

	# Prepare the search and replace values
	my $regex = $self->_get_search or return;
	my $replace = $self->_get_replace;
	$replace =~ s/\\t/\t/g if length $replace;

	# Get current search condition and check if they match
	my ( $start, $end, @matches ) = Padre::Util::get_matches( $text, $regex, 0, 0 );

	# If they match replace it
	if ( defined $start and $start == 0 and $end == length($text) ) {
		$current->editor->ReplaceSelection($replace);

		# If replaced text is smaller or larger than original,
		# change our offset end accordingly
		if ( length($replace) != ( $end - $start ) ) {
			$self->{text_offset_end} += ( length($replace) - ( $end - $start ) );
		}

		# Update text to search with replaced values
		###################	$self->{text} = $current->editor->GetTextRange( $self->{text_offset}, $self->{text_offset_end} );
	}

	# If search window is still open, run a search on the whole text again
	unless ( $current->config->find_first ) {
		$self->search;
	}

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
	my $config = $self->config;
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

# Internal method. $self->_get_replace
# Returns previous replacement string from history
# or empty if _replace_choice_ widget is empty.
# Added to be able to use empty string as a replacement text
# but without storing in (the empty string) in history.
sub _get_replace {
	my $self = shift;
	if ( $self->{replace_text} ) {
		return $self->{replace_text}->GetValue;
	} else {
		return Padre::DB::History->previous('replace');
	}
}

# Adds Ultraedit-like hotkeys for quick find/replace triggering
sub _on_hotkey {
	my $self = shift;
	my $code = shift;

	$self->find_clicked    if $code == 102; # pressed 'f' hotkey
	$self->replace_clicked if $code == 114; # pressed 'r' hotkey

	return;
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

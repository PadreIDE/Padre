package Padre::Wx::Dialog::Find;

=pod

=head1 NAME

Padre::Wx::Dialog::Find - Find and Replace widget

=head1 DESCRIPTION

C<Padre::Wx:Main> implements Padre's Find and Replace dialogs.
Inherits from C<Padre::Wx::Dialog>.

=cut

use 5.008;
use strict;
use warnings;
use Params::Util qw{_STRING};
use Padre::DB         ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.36';
our @ISA     = 'Padre::Wx::Dialog';

my @cbs = qw(
	find_case
	find_regex
	find_reverse
	find_first
);

=pod

=head1 PUBLIC API

=head2 Constructor

=over 4

=item new( $type )

Create and return a C<Padre::Wx::Dialog::Find> object.  Takes dialog
type (C<find> or C<replace>) as a parameter.  If none given assumes
the type is C<find>.  Stores dialog type in C<dialog_type>.

    my $find_dialog = Padre::Wx::Dialog::Find->new('find');

=back

=cut

sub new {
	my $class = shift;
	my $type  = shift;
	my $self  = bless {}, $class;

	$self->{dialog_type} = $type ? $type : 'find';
	$self->create_dialog;

	return $self;
}

=pod

=head2 Public Methods

=over 4

=item * $self->relocale;

Delete and re-create dialog on locale (language) change.

=cut

sub relocale {
	my $self = shift;

	$self->delete_dialog;
	$self->create_dialog;

	return;
}

=pod

=item * $self->delete_dialog;

Delete dialog.

=cut

sub delete_dialog {
	my $self = shift;

	$self->{dialog}->Destroy;
	delete $self->{dialog};

	return;
}

=pod

=item * $self->create_dialog;

Create Find or Replace dialog depending on C<dialog_type> value.

TODO: Maybe create methods for Find and Replace dialogs should
be separated?

=cut

sub create_dialog {
	my $self   = shift;
	my $config = Padre->ide->config;
	my $title
		= $self->{dialog_type} eq 'replace'
		? Wx::gettext('Replace')
		: Wx::gettext('Find');

	$self->{dialog} = Wx::Dialog->new(
		Padre->ide->wx->main,
		-1,
		$title,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION
			| Wx::wxRESIZE_BORDER
			| Wx::wxCLOSE_BOX
			| Wx::wxSYSTEM_MENU,
	);

	my $main_sizer = Wx::FlexGridSizer->new( 1, 1, 0, 0 );
	$main_sizer->AddGrowableCol(0);
	$self->{dialog}->SetSizer($main_sizer);

	# Prepare widgets used in Find/Replace dialogs
	## widgets used in find_sizer
	$self->add_widget( '_find_choice_', Wx::ComboBox->new( $self->{dialog} ) );
	$self->add_widget(
		'find_regex',
		Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('&Use Regex') )
	);
	$self->get_widget('find_regex')->SetValue( $config->find_regex ? 1 : 0 );
	## widgets used in replace_sizer
	if ( $self->{dialog_type} eq 'replace' ) {
		$self->add_widget( '_replace_choice_', Wx::ComboBox->new( $self->{dialog} ) );
	}
	## widgets used in options_sizer
	$self->add_widget(
		'find_case',
		Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('Case &Insensitive') )
	);
	$self->get_widget('find_case')->SetValue( $config->find_case ? 0 : 1 );
	$self->add_widget(
		'find_reverse',
		Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('Search &Backwards') )
	);
	$self->get_widget('find_reverse')->SetValue( $config->find_reverse ? 1 : 0 );
	$self->add_widget(
		'find_first',
		Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('Close Window on &hit') )
	);
	$self->get_widget('find_first')->SetValue( $config->find_first ? 1 : 0 );
	## widgets used in bottom_sizer
	if ( $self->{dialog_type} eq 'replace' ) {
		$self->add_widget(
			'_replace_',
			Wx::Button->new( $self->{dialog}, Wx::wxID_REPLACE, Wx::gettext("&Replace") )
		);
		$self->add_widget(
			'_replace_all_',
			Wx::Button->new( $self->{dialog}, Wx::wxID_REPLACE_ALL, Wx::gettext("Replace &all") )
		);
	} else {
		$self->add_widget(
			'_find_',
			Wx::Button->new( $self->{dialog}, Wx::wxID_FIND, Wx::gettext("&Find") )
		);
	}
	$self->add_widget(
		'_cancel_',
		Wx::Button->new( $self->{dialog}, Wx::wxID_CANCEL, Wx::gettext("&Cancel") )
	);

	# Find sizer begins here
	my $find_sizer = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new( $self->{dialog}, -1, Wx::gettext('Find') ),
		Wx::wxVERTICAL
	);
	$main_sizer->Add( $find_sizer, 2, Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL, 5 );

	$find_sizer->Add(
		Wx::StaticText->new( $self->{dialog}, Wx::wxID_STATIC, Wx::gettext("Text to find:") ),
		0,
		Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
		5
	);
	$find_sizer->Add(
		$self->get_widget('_find_choice_'),
		3,
		Wx::wxGROW | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
		5
	);
	$find_sizer->Add(
		$self->get_widget('find_regex'),
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5
	);

	# Replace sizer begins here
	if ( $self->{dialog_type} eq 'replace' ) {
		my $replace_sizer = Wx::StaticBoxSizer->new(
			Wx::StaticBox->new( $self->{dialog}, -1, Wx::gettext('Replace With') ),
			Wx::wxVERTICAL
		);
		$main_sizer->Add(
			$replace_sizer,
			2,
			Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL,
			5
		);

		$replace_sizer->Add(
			Wx::StaticText->new(
				$self->{dialog},
				Wx::wxID_STATIC,
				Wx::gettext("Replacement text:")
			),
			0,
			Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
			5
		);
		$replace_sizer->Add(
			$self->get_widget('_replace_choice_'),
			3,
			Wx::wxGROW | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL,
			5
		);
	}

	# Options sizer begins here
	my $options_sizer = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self->{dialog},
			-1,
			Wx::gettext('Options')
		),
		Wx::wxVERTICAL
	);
	$main_sizer->Add( $options_sizer, 2, Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL, 5 );

	my $options_grid_sizer = Wx::FlexGridSizer->new( 2, 2, 0, 0 );
	$options_grid_sizer->AddGrowableCol(1);
	$options_sizer->Add(
		$options_grid_sizer,
		2,
		Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxGROW | Wx::wxALL,
		0
	);

	$options_grid_sizer->Add(
		$self->get_widget('find_case'),
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5
	);
	$options_grid_sizer->Add(
		$self->get_widget('find_reverse'),
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5
	);
	$options_grid_sizer->Add(
		$self->get_widget('find_first'),
		0,
		Wx::wxALIGN_LEFT | Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP,
		5
	);

	# Bottom sizer begins here
	my $bottom_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$main_sizer->Add( $bottom_sizer, 0, Wx::wxALIGN_RIGHT | Wx::wxALL, 5 );

	if ( $self->{dialog_type} eq 'replace' ) {
		$bottom_sizer->Add(
			$self->get_widget('_replace_'),
			0,
			Wx::wxGROW | Wx::wxRIGHT,
			5
		);
		$bottom_sizer->Add(
			$self->get_widget('_replace_all_'),
			0,
			Wx::wxGROW | Wx::wxLEFT | Wx::wxRIGHT,
			5
		);
	} else {
		$bottom_sizer->Add(
			$self->get_widget('_find_'),
			0,
			Wx::wxGROW | Wx::wxRIGHT,
			5
		);
	}
	$bottom_sizer->Add(
		$self->get_widget('_cancel_'),
		0,
		Wx::wxGROW | Wx::wxLEFT,
		5
	);

	$main_sizer->SetSizeHints( $self->{dialog} );

	foreach my $cb (@cbs) {
		Wx::Event::EVT_CHECKBOX(
			$self->{dialog},
			$self->get_widget($cb),
			sub {
				$self->get_widget('_find_choice_')->SetFocus;
			},
		);
	}

	$self->{dialog_type} eq 'replace'
		? $self->get_widget('_replace_')->SetDefault
		: $self->get_widget('_find_')->SetDefault;

	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_find_'),
		sub {
			$self->find_clicked;
		}
	);
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_replace_'),
		sub {
			$self->replace_clicked;
		}
	);
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_replace_all_'),
		sub {
			$self->replace_all_clicked;
		}
	);
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_cancel_'),
		sub {
			$self->cancel_clicked;
		}
	);

	return;
}

=pod

=item * $self->update_dialog;

Fetch recent search and replace strings from history and place them
in find and replace combo boxes respectively for re-use. 

=cut

sub update_dialog {
	my $self = shift;

	my $find = $self->get_widget('_find_choice_');
	$find->Clear;
	foreach my $s ( Padre::DB::History->recent('search') ) {
		$find->Append($s);
	}

	if ( $self->{dialog_type} eq 'replace' ) {
		my $replace = $self->get_widget('_replace_choice_');
		$replace->Clear;
		foreach my $r ( Padre::DB::History->recent('replace') ) {
			$replace->Append($r);
		}
		$self->get_widget_value('_find_choice_') ne ''
			? $replace->SetFocus
			: $find->SetFocus;
	} else {
		$find->SetFocus;
	}

	return;
}

=pod

=item * $self->find;

Grab currently selected text, if any, and place it in find combo box.
Bring up the dialog or perform search for strings' next occurence
if dialog is already displayed.

TODO: if selection is more than one line then consider it as the limit
of the search and replace and not as the string to be used.

=cut

sub find {
	my ( $self, $main ) = @_;

	my $text = $main->current->text;
	$text = '' if not defined $text;

	# TODO: if selection is more than one lines then consider it as the limit
	# of the search and replace and not as the string to be used
	$text = '' if $text =~ /\n/;

	$self->get_widget('_find_choice_')->SetValue($text);
	$self->update_dialog;

	if ( $self->{dialog}->IsShown ) {
		Padre::Wx::Dialog::Find->find_next($main);
	} else {
		$self->{dialog}->Show(1);
	}

	return;
}

=pod

=item * $self->find_next;

Search for given string's next occurence.  If no string is available
(either as a selected text in editor, if Quick Find is on, or from
search history) run C<find> method.

=cut

sub find_next {
	my $self = shift;
	my $main = shift;
	my $term = Padre::DB::History->previous('search');

	# for Quick Find
	# check if is checked
	if ( $main->menu->search->{quick_find}->IsChecked ) {
		my $text = $main->current->text;
		if ( $text and $text ne $term ) {
			Padre::DB::History->create(
				type => 'search',
				name => $text,
			);
		}
	}

	if ($term) {
		$self->search;
	} else {
		$self->find($main);
	}

	return;
}

=pod

=item * $self->find_previous;

Perform backward search for string fetched from search history
or run C<find> method if search history is empty.

=cut

sub find_previous {
	my $self = shift;
	my $main = shift;
	my $term = Padre::DB::History->previous('search');
	if ($term) {
		$self->search( rev => 1 );
	} else {
		$self->find($main);
	}
	return;
}

=pod

=item * $self->cancel_clicked;

Hide dialog when pressed cancel button.

=cut

sub cancel_clicked {
	$_[0]->{dialog}->Hide;

	# If no focus is set, the focus is lost when reopening the dialog
	$_[0]->get_widget('_find_choice_')->SetFocus;
	return;
}

=pod

=item * $self->replace_all_clicked;

Executed when Replace all button is clicked.
Replace all appearances of given string.

=cut

sub replace_all_clicked {
	my ( $self, $dialog, $event ) = @_;

	$self->get_data_from_dialog or return;
	my $regex = _get_regex();
	return if not defined $regex;

	my $current = Padre::Current->new;
	my $main    = $current->main;
	my $config  = $main->config;
	my $page    = $current->editor;
	my $last    = $page->GetLength;
	my $str     = $page->GetTextRange( 0, $last );
	my $replace = $self->_get_replace;
	$replace =~ s/\\t/\t/g if $replace;

	my ( $start, $end, @matches ) = Padre::Util::get_matches( $str, $regex, 0, 0 );
	$page->BeginUndoAction;
	foreach my $m ( reverse @matches ) {
		$page->SetTargetStart( $m->[0] );
		$page->SetTargetEnd( $m->[1] );
		$page->ReplaceTarget($replace);
	}
	$page->EndUndoAction;

	Padre->ide->wx->main->message( sprintf( Wx::gettext('%s occurences were replaced'), scalar @matches ) );

	return;
}

=pod

=item * $self->replace_clicked;

Executed when Replace button is clicked.
Replace one appearance of given strings.  If search window is still
open, run C<search> on the whole text, again.

=cut

sub replace_clicked {
	my ( $self, $dialog, $event ) = @_;

	$self->get_data_from_dialog or return;
	my $regex = _get_regex();
	return if not defined $regex;

	# Get current search condition and check if they match
	my $current = Padre::Current->new;
	my $text    = $current->text;
	my ( $start, $end, @matches ) = Padre::Util::get_matches( $text, $regex, 0, 0 );

	# If they do, replace it
	if ( defined $start and $start == 0 and $end == length($text) ) {
		my $replace = $self->_get_replace;
		$replace =~ s/\\t/\t/g;
		$current->editor->ReplaceSelection($replace);
	}

	# If search window is still open, run a search on the whole text again
	my $config = Padre->ide->config;
	unless ( $config->find_first ) {
		$self->search;
	}

	return;
}

=pod

=item * $self->find_clicked;

Executed when Find button is clicked.
Perform search on the term specified in the dialog.

=cut

sub find_clicked {
	my $self   = shift;
	my $dialog = shift;
	my $event  = shift;

	$self->get_data_from_dialog or return;
	$self->search;

	return;
}

=pod

=item * $self->get_data_from_dialog;

Gather search and optionaly replace strings from the dialog and store
them in search history.  Set search options based on the check boxes
values.

=cut

sub get_data_from_dialog {
	my $self   = shift;
	my $dialog = $self->{dialog};
	my $data   = $self->get_widgets_values;
	my $config = Padre->ide->config;
	$config->set( find_case    => $data->{find_case}    ? 0 : 1 );
	$config->set( find_regex   => $data->{find_regex}   ? 1 : 0 );
	$config->set( find_reverse => $data->{find_reverse} ? 1 : 0 );
	$config->set( find_first   => $data->{find_first}   ? 1 : 0 );
	$config->write;

	my $search  = $data->{_find_choice_};
	my $replace = $data->{_replace_choice_};

	if ( $config->find_first ) {
		$dialog->Hide;
	}
	return unless defined _STRING($search);

	Padre::DB->begin;
	Padre::DB::History->create(
		type => 'search',
		name => $search,
	) if $search;
	Padre::DB::History->create(
		type => 'replace',
		name => $replace,
	) if $replace;
	Padre::DB->commit;

	return 1;
}

# Internal method. $self->_get_regex( $regex )
# Prepare and return search term defined as a regular expression.
sub _get_regex {
	my %args        = @_;
	my $config      = Padre->ide->config;
	my $search_term = $args{search_term}
		|| Padre::DB::History->previous('search');
	return $search_term if defined $search_term and 'Regexp' eq ref $search_term;

	if ( $config->find_regex ) {
		$search_term =~ s/\$/\\\$/;    # escape $ signs by default so they won't interpolate
	} else {
		$search_term = quotemeta $search_term;
	}

	unless ( $config->find_case ) {
		$search_term =~ s/^(\^?)/$1(?i)/;
	}

	my $regex;
	eval { $regex = qr/$search_term/m };
	if ($@) {
		Wx::MessageBox(
			sprintf( Wx::gettext("Cannot build regex for '%s'"), $search_term ),
			Wx::gettext("Search error"),
			Wx::wxOK,
			Padre->ide->wx->main,
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

	my $replace
		= $self->get_widget_value('_replace_choice_') eq ''
		? ''
		: Padre::DB::History->previous('replace');

	return $replace;
}

=pod

=item * $self->search;

Perform actual search.  Highlight (set as selected) found string.

=cut

sub search {
	my $self  = shift;
	my %args  = @_;
	my $main  = Padre->ide->wx->main;
	my $regex = _get_regex(%args);
	return if not defined $regex;

	my $page = $main->current->editor;
	my ( $from, $to ) = $page->GetSelection;
	my $last = $page->GetLength;
	my $str = $page->GetTextRange( 0, $last );

	my $config       = Padre->ide->config;
	my $find_reverse = $config->find_reverse;
	if ( $args{rev} ) {
		$find_reverse = not $find_reverse;
	}
	my ( $start, $end, @matches ) = Padre::Util::get_matches( $str, $regex, $from, $to, $find_reverse );
	return if not defined $start;

	$page->SetSelection( $start, $end );

	return;
}

1;

=pod

=back

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

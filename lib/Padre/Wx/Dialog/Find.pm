package Padre::Wx::Dialog::Find;

# Find and Replace widget

use 5.008;
use strict;
use warnings;
use Params::Util      qw{_STRING};
use Padre::DB         ();
use Padre::Wx         ();

use base qw(Padre::Wx::Dialog);

our $VERSION = '0.30';

my @cbs = qw(
	find_case
	find_regex
	find_reverse
	find_first
);

sub new {
	my $class = shift;
	my $self  = bless {}, $class;

	$self->create_dialog;

	return $self;
}

sub relocale {
	my $self = shift;

	$self->delete_dialog;
	$self->create_dialog;

	return;
}

sub delete_dialog {
	my $self = shift;

	$self->{dialog}->Destroy;
	delete $self->{dialog};

	return;
}

sub create_dialog {
	my $self = shift;

	my $config = Padre->ide->config;

	$self->{dialog} = Wx::Dialog->new(
		Padre->ide->wx->main,
		-1,
		Wx::gettext('Find'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION
		| Wx::wxRESIZE_BORDER
		| Wx::wxCLOSE_BOX
		| Wx::wxSYSTEM_MENU,
	);

	my $main_sizer = Wx::FlexGridSizer->new(2, 2, 0, 0);
	$main_sizer->AddGrowableCol(0);
	$self->{dialog}->SetSizer($main_sizer);

	my $left_top_sizer = Wx::FlexGridSizer->new(2, 2, 0, 0);
	$left_top_sizer->AddGrowableCol(1);
	$main_sizer->Add( $left_top_sizer, 2, Wx::wxALIGN_CENTER_HORIZONTAL|Wx::wxGROW|Wx::wxALL, 5 );

	$left_top_sizer->Add(
		Wx::StaticText->new( $self->{dialog}, Wx::wxID_STATIC, Wx::gettext("Find:") ),
		0,
		Wx::wxALIGN_LEFT|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL,
		5
	);

	$self->add_widget( '_find_choice_',	Wx::ComboBox->new( $self->{dialog} ) );
	$left_top_sizer->Add(
		$self->get_widget('_find_choice_'),
		3,
		Wx::wxGROW|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL,
		5
	);

	$left_top_sizer->Add(
		Wx::StaticText->new( $self->{dialog}, Wx::wxID_STATIC, Wx::gettext("Replace with:") ),
		0,
		Wx::wxALIGN_LEFT|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL,
		5
	);

	$self->add_widget( '_replace_choice_',	Wx::ComboBox->new( $self->{dialog} ) );
	$left_top_sizer->Add(
		$self->get_widget('_replace_choice_'),
		3,
		Wx::wxGROW|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL,
		5
	);

	my $right_top_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$main_sizer->Add(
		$right_top_sizer,
		0,
		Wx::wxGROW|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxLEFT|Wx::wxRIGHT,
		5
	);

	$self->add_widget( '_find_', Wx::Button->new( $self->{dialog}, Wx::wxID_FIND, Wx::gettext("&Find") ) );
	$right_top_sizer->Add(
		$self->get_widget('_find_'),
		1,
		Wx::wxGROW|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxTOP,
		5
	);

	$self->add_widget( '_replace_', Wx::Button->new( $self->{dialog}, Wx::wxID_REPLACE, Wx::gettext("&Replace") ) );
	$right_top_sizer->Add(
		$self->get_widget('_replace_'),
		1,
		Wx::wxGROW|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxTOP,
		5
	);

	my $left_bottom_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$main_sizer->Add(
		$left_bottom_sizer,
		2,
		Wx::wxGROW|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL,
		5
	);

	$self->add_widget( 'find_case', Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('Case &Insensitive') ) );
	$self->get_widget('find_case')->SetValue( $config->find_case ? 0 : 1 );
	$left_bottom_sizer->Add(
		$self->get_widget('find_case'),
		0,
		Wx::wxALIGN_LEFT|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxTOP,
		5
	);

	$self->add_widget( 'find_regex', Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('&Use Regex') ) );
	$self->get_widget('find_regex')->SetValue( $config->find_regex ? 1 : 0 );
	$left_bottom_sizer->Add(
		$self->get_widget('find_regex'),
		0,
		Wx::wxALIGN_LEFT|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxTOP,
		5
	);

	$self->add_widget( 'find_reverse', Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('Search &Backwards') ) );
	$self->get_widget('find_reverse')->SetValue( $config->find_reverse ? 1 : 0 );
	$left_bottom_sizer->Add(
		$self->get_widget('find_reverse'),
		0,
		Wx::wxALIGN_LEFT|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxTOP,
		5
	);

	$self->add_widget( 'find_first', Wx::CheckBox->new( $self->{dialog}, -1, Wx::gettext('Close Window on &hit') ) );
	$self->get_widget('find_first')->SetValue( $config->find_first ? 1 : 0 );
	$left_bottom_sizer->Add(
		$self->get_widget('find_first'),
		0,
		Wx::wxALIGN_LEFT|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxTOP,
		5
	);

	my $right_bottom_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$main_sizer->Add( $right_bottom_sizer, 0, Wx::wxALIGN_CENTER_HORIZONTAL|Wx::wxGROW|Wx::wxALL, 5);

	$self->add_widget( '_replace_all_', Wx::Button->new( $self->{dialog}, Wx::wxID_REPLACE_ALL, Wx::gettext("Replace &all") ) );
	$right_bottom_sizer->Add(
		$self->get_widget('_replace_all_'),
		0,
		Wx::wxGROW|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxBOTTOM,
		5
	);

	$right_bottom_sizer->Add(5, 5, 5, Wx::wxALIGN_CENTER_HORIZONTAL|Wx::wxALL, 5);

	$self->add_widget( '_cancel_', Wx::Button->new( $self->{dialog}, Wx::wxID_CANCEL, Wx::gettext("&Cancel") ) );
	$right_bottom_sizer->Add(
		$self->get_widget('_cancel_'),
		0,
		Wx::wxGROW|Wx::wxLEFT|Wx::wxRIGHT|Wx::wxBOTTOM,
		5
	);

	$main_sizer->SetSizeHints( $self->{dialog} );

	foreach my $cb ( @cbs ) {
		Wx::Event::EVT_CHECKBOX(
			$self->{dialog},
			$self->get_widget($cb),
			sub {
				$self->get_widget('_find_choice_')->SetFocus;
			},
		);
	}

	$self->get_widget('_find_')->SetDefault;
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_find_'),
		sub { $self->find_clicked }
	);
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_replace_'),
		sub { $self->replace_clicked }
	);
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_replace_all_'),
		sub { $self->replace_all_clicked }
	);
	Wx::Event::EVT_BUTTON(
		$self->{dialog},
		$self->get_widget('_cancel_'),
		sub { $self->cancel_clicked }
	);

	return;
}

sub update_dialog {
	my $self = shift;

	my $find_combobox = $self->get_widget('_find_choice_');
	$find_combobox->Clear;
	foreach my $s ( Padre::DB::History->recent('search') ) {
		$find_combobox->Append($s);
	}

	my $replace_combobox = $self->get_widget('_replace_choice_');
	$replace_combobox->Clear;
	foreach my $r ( Padre::DB::History->recent('replace') ) {
		$replace_combobox->Append($r);
	}

	$find_combobox->SetFocus;

	return;
}

sub find {
	my ($self, $main) = @_;

	my $text = $main->current->text;
	$text = '' if not defined $text;

	# TODO: if selection is more than one lines then consider it as the limit
	# of the search and replace and not as the string to be used
	$text = '' if $text =~ /\n/;

	$self->update_dialog;
	$self->get_widget('_find_choice_')->SetValue($text);

	if ( $self->{dialog}->IsShown ) {
		Padre::Wx::Dialog::Find->find_next($main);
	} else {
		$self->{dialog}->Show(1);
	}

	return;
}

sub find_next {
	my $self  = shift;
	my $main  = shift;
	my $term  = Padre::DB::History->previous('search');

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

	if ( $term ) {
		$self->search;
	} else {
		$self->find( $main );
	}

	return;
}

sub find_previous {
	my $self = shift;
	my $main  = shift;
	my $term  = Padre::DB::History->previous('search');
	if ( $term ) {
		$self->search(rev => 1);
	} else {
		$self->find( $main );
	}
	return;
}

sub cancel_clicked {
	$_[0]->{dialog}->Hide;
	# If no focus is set, the focus is lost when reopening the dialog
	$_[0]->get_widget('_find_choice_')->SetFocus;
	return;
}

sub replace_all_clicked {
	my ($self, $dialog, $event) = @_;

	$self->get_data_from_dialog or return;
	my $regex = _get_regex();
	return if not defined $regex;

	my $current = Padre::Current->new;
	my $main    = $current->main;
	my $config  = $main->config;
	my $page    = $current->editor;
	my $last    = $page->GetLength;
	my $str     = $page->GetTextRange(0, $last);
	my $replace = Padre::DB::History->previous('replace') || '';
	$replace =~ s/\\t/\t/g if $replace;

	my ($start, $end, @matches) = Padre::Util::get_matches($str, $regex, 0, 0);
	$page->BeginUndoAction;
	foreach my $m ( reverse @matches ) {
		$page->SetTargetStart($m->[0]);
		$page->SetTargetEnd($m->[1]);
		$page->ReplaceTarget($replace);
	}
	$page->EndUndoAction;

	Padre->ide->wx->main->message(
		sprintf( Wx::gettext('%s occurences were replaced'), scalar @matches )
	);

	return;
}

sub replace_clicked {
	my ($self, $dialog, $event) = @_;

	$self->get_data_from_dialog or return;
	my $regex = _get_regex();
	return if not defined $regex;

	# Get current search condition and check if they match
	my $current = Padre::Current->new;
	my $text    = $current->text;
	my ($start, $end, @matches) = Padre::Util::get_matches($text, $regex, 0, 0);

	# If they do, replace it
	if ( defined $start and $start == 0 and $end == length($text) ) {
		# TODO - This can return undef
		my $replace = Padre::DB::History->previous('replace');
		$replace =~ s/\\t/\t/g;
		$current->editor->ReplaceSelection($replace);
	}

	# If search window is still open, run a search_again on the whole text
	my $config = Padre->ide->config;
	unless ( $config->find_first ) {
		$self->search;
	}

	return;
}

sub find_clicked {
	my $self   = shift;
	my $dialog = shift;
	my $event  = shift;

	$self->get_data_from_dialog or return;
	$self->search;

	return;
}

sub get_data_from_dialog {
	my $self   = shift;
	my $dialog = $self->{dialog};
	my $data   = $self->get_widgets_values;
	my $config = Padre->ide->config;
	$config->set( find_case    => $data->{find_case} ? 0 : 1    );
	$config->set( find_regex   => $data->{find_regex} ? 1 : 0   );
	$config->set( find_reverse => $data->{find_reverse} ? 1 : 0 );
	$config->set( find_first   => $data->{find_first} ? 1 : 0   );

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

sub _get_regex {
	my %args        = @_;
	my $config      = Padre->ide->config;
	my $search_term = $args{search_term}
		|| Padre::DB::History->previous('search');
	return $search_term if defined $search_term and 'Regexp' eq ref $search_term;

	if ( $config->find_regex ) {
		$search_term =~ s/\$/\\\$/; # escape $ signs by default so they won't interpolate
	} else {
		$search_term = quotemeta $search_term;
	}

	unless ( $config->find_case )  {
		$search_term =~ s/^(\^?)/$1(?i)/;
	}

	my $regex;
	eval { $regex = qr/$search_term/m };
	if ( $@ ) {
		Wx::MessageBox(
			sprintf(Wx::gettext("Cannot build regex for '%s'"), $search_term),
			Wx::gettext("Search error"),
			Wx::wxOK,
			Padre->ide->wx->main,
		);
		return;
	}
	return $regex;
}

sub search {
	my $self = shift;
	my %args  = @_;
	my $main  = Padre->ide->wx->main;
	my $regex = _get_regex(%args);
	return if not defined $regex;

	my $page = $main->current->editor;
	my ($from, $to) = $page->GetSelection;
	my $last = $page->GetLength;
	my $str  = $page->GetTextRange(0, $last);

	my $config    = Padre->ide->config;
	my $find_reverse = $config->find_reverse;
	if ( $args{rev} ) {
	   $find_reverse = not $find_reverse;
	}
	my ($start, $end, @matches) = Padre::Util::get_matches($str, $regex, $from, $to, $find_reverse);
	return if not defined $start;

	$page->SetSelection( $start, $end );

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

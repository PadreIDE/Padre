package Padre::Wx::Dialog::Find;

# Find and Replace widget

use 5.008;
use strict;
use warnings;
use Params::Util      qw{_STRING};
use Padre::DB         ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.26';

my @cbs = qw(
	find_case
	find_regex
	find_reverse
	find_first
);

sub new {
	my $class = shift;
	my $self  = bless {}, $class;
	return $self;
}

sub get_layout {
	my $config      = shift;

	# Get the search terms
	my $recent_search  = Padre::DB::History->recent('search',  20);
	my $recent_replace = Padre::DB::History->recent('replace', 20);

	my @layout = (
		[
			[
				'Wx::StaticText',
				undef,
				Wx::gettext('Find:')
			],
			[
				'Wx::ComboBox',
				'_find_choice_',
				'',
				$recent_search
			],
			[
				'Wx::Button',
				'_find_',
				Wx::wxID_FIND
			],
		],
		[
			[
				'Wx::StaticText',
				undef,
				Wx::gettext('Replace With:')
			],
			[
				'Wx::ComboBox',
				'_replace_choice_',
				'',
				$recent_replace
			],
			[
				'Wx::Button',
				'_replace_',
				Wx::gettext('&Replace')
			],
		],
		[
			[],
			[],
			[
				'Wx::Button',
				'_replace_all_',
				Wx::gettext('Replace &All')
			],
		],
		[
			[
				'Wx::CheckBox',
				'find_case',
				Wx::gettext('Case &Insensitive'),
				($config->find_case ? 0 : 1) 
			],
		],
		[
			[
				'Wx::CheckBox',
				'find_regex',
				Wx::gettext('&Use Regex'),
				($config->find_regex ? 1 : 0)
			],
		],
		[
			[
				'Wx::CheckBox',
				'find_reverse',
				Wx::gettext('Search &Backwards'),
				($config->find_reverse ? 1 : 0)
			],
		],
		[
			[
				'Wx::CheckBox',
				'find_first',
				Wx::gettext('Close Window on &hit'),
				($config->find_first ? 1 : 0)
			],
		],
		[
			[],
			[],
			[
				'Wx::Button',
				'_cancel_',
				Wx::wxID_CANCEL
			],
		],
	);

	return \@layout;
}

sub dialog {
	my ( $class, $parent ) = @_;

	my $config = Padre->ide->config;
	my $layout = get_layout($config);
	my $dialog = Padre::Wx::Dialog->new(
		parent => $parent,
		title  => Wx::gettext("Search"),
		layout => $layout,
		width  => [ 150, 200 ],
	);

	foreach my $cb ( @cbs ) {
		Wx::Event::EVT_CHECKBOX(
			$dialog,
			$dialog->{_widgets_}->{$cb},
			sub {
				$_[0]->{_widgets_}->{_find_choice_}->SetFocus;
			},
		);
	}

	$dialog->{_widgets_}->{_find_}->SetDefault;
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{_widgets_}->{_find_},
		\&find_clicked
	);
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{_widgets_}->{_replace_},
		\&replace_clicked
	);
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{_widgets_}->{_replace_all_},
		\&replace_all_clicked
	);
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{_widgets_}->{_cancel_},
		\&cancel_clicked
	);

	$dialog->{_widgets_}->{_find_choice_}->SetFocus;

	return $dialog;
}

sub find {
	my ($self, $main) = @_;

	my $text = $main->current->text;
	$text = '' if not defined $text;

	# TODO: if selection is more than one lines then consider it as the limit
	# of the search and replace and not as the string to be used
	$text = '' if $text =~ /\n/;

	unless ( $self->{dialog} ) {
		$self->{dialog}  = $self->dialog( $main );
	}
	$self->{dialog}->{_widgets_}->{_find_choice_}->SetValue($text);
	# Focus is given by the Cancel Button
	#else {
	#	#TODO: give focus.
	#}

	$self->{dialog}->Show(1);

	return;
}

sub find_next {
	my $class = shift;
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
		$class->search;
	} else {
		$class->find( $main );
	}

	return;
}

sub find_previous {
	my $class = shift;
	my $main  = shift;
	my $term  = Padre::DB::History->previous('search');
	if ( $term ) {
		$class->search(rev => 1);
	} else {
		$class->find( $main );
	}
	return;
}

sub cancel_clicked {
	$_[0]->Hide;
	# If no focus is set, the focus is lost when reopening the dialog
	$_[0]->{_widgets_}->{_find_choice_}->SetFocus;
	return;
}

sub replace_all_clicked {
	my ($dialog, $event) = @_;

	_get_data_from( $dialog ) or return;
	my $regex = _get_regex();
	return if not defined $regex;

	my $current = Padre::Current->new;
	my $main    = $current->main;
	my $config  = $main->config;
	my $page    = $current->editor;
	my $last    = $page->GetLength;
	my $str     = $page->GetTextRange(0, $last);
	my $replace = Padre::DB::History->previous('replace');
	$replace =~ s/\\t/\t/g;

	my ($start, $end, @matches) = Padre::Util::get_matches($str, $regex, 0, 0);
	$page->BeginUndoAction;
	foreach my $m ( reverse @matches ) {
		$page->SetTargetStart($m->[0]);
		$page->SetTargetEnd($m->[1]);
		$page->ReplaceTarget($replace);
	}
	$page->EndUndoAction;

	return;
}

sub replace_clicked {
	my ($dialog, $event) = @_;

	_get_data_from( $dialog ) or return;
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
		Padre::Wx::Dialog::Find->search;
	}

	return;
}

sub find_clicked {
	my $dialog = shift;
	my $event  = shift;

	_get_data_from( $dialog ) or return;
	Padre::Wx::Dialog::Find->search;

	return;
}

sub _get_data_from {
	my $dialog = shift;
	my $data   = $dialog->get_data;
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
	my $class = shift;
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

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

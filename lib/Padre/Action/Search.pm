package Padre::Action::Search;

# Fully encapsulated Search menu

use 5.008;
use strict;
use warnings;
use Padre::Action;
use Padre::Search ();
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.49';



#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty object as normal, it won't be used usually
	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Search
	Padre::Action->new(
		name        => 'search.find',
		id          => Wx::wxID_FIND,
		need_editor => 1,
		label       => Wx::gettext('&Find'),
		comment     => Wx::gettext('Find text or regular expressions using a traditional dialog'),
		shortcut    => 'Ctrl-F',
		menu_event  => sub {
			$_[0]->find->find;
		},
	);

	Padre::Action->new(
		name        => 'search.find_next',
		label       => Wx::gettext('Find Next'),
		need_editor => 1,
		comment     => Wx::gettext('Repeat the last find to find the next match'),
		shortcut    => 'F3',
		menu_event  => sub {
			my $editor = $_[0]->current->editor;

			# Handle the obvious case with nothing selected
			my ( $position1, $position2 ) = $editor->GetSelection;
			if ( $position1 == $position2 ) {
				return $_[0]->search_next;
			}

			# Multiple lines are also done the obvious way
			my $line1 = $editor->LineFromPosition($position1);
			my $line2 = $editor->LineFromPosition($position2);
			unless ( $line1 == $line2 ) {
				return $_[0]->search_next;
			}

			# Special case. Make and save a non-regex
			# case-insensitive search and advance to the next hit.
			my $search = Padre::Search->new(
				find_case    => 0,
				find_regex   => 0,
				find_reverse => 0,
				find_term    => $editor->GetTextRange(
					$position1, $position2,
				),
			);
			$_[0]->search_next($search);

			# If we can't find another match, show a message
			if ( ( $editor->GetSelection )[0] == $position1 ) {
				$_[0]->error( Wx::gettext("Failed to find any matches") );
			}
		},
	);

	Padre::Action->new(
		name        => 'search.find_previous',
		need_editor => 1,
		label       => Wx::gettext('&Find Previous'),
		comment     => Wx::gettext('Repeat the last find, but backwards to find the previous match'),
		shortcut    => 'Shift-F3',
		menu_event  => sub {
			$_[0]->search_previous;
		},
	);

	# Quick Find: starts search with selected text
	Padre::Action->new(
		name        => 'search.quick_find',
		need_editor => 1,
		label       => Wx::gettext('Quick Find'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->config->set(
				'find_quick',
				$_[1]->IsChecked ? 1 : 0,
			);
			return;
		},
		checked_default => $main->config->find_quick,
	);

	# We should be able to remove F4 and shift-F4 and hook this functionality
	# to F3 and shift-F3 Incremental find (#60)
	Padre::Action->new(
		name        => 'search.quick_find_next',
		need_editor => 1,
		label       => Wx::gettext('Find Next'),
		comment     => Wx::gettext('Find next matching text using a toolbar-like dialog at the bottom of the editor'),
		shortcut    => 'F4',
		menu_event  => sub {
			$_[0]->fast_find->search('next');
		},
	);

	Padre::Action->new(
		name        => 'search.quick_find_previous',
		need_editor => 1,
		label       => Wx::gettext('Find Previous'),
		comment  => Wx::gettext('Find previous matching text using a toolbar-like dialog at the bottom of the editor'),
		shortcut => 'Shift-F4',
		menu_event => sub {
			$_[0]->fast_find->search('previous');
		},
	);

	# Search and Replace
	Padre::Action->new(
		name        => 'search.replace',
		need_editor => 1,
		label       => Wx::gettext('Replace'),
		comment     => Wx::gettext('Find a text and replace it'),
		shortcut    => 'Ctrl-R',
		menu_event  => sub {
			$_[0]->replace->find;
		},
	);

	# Recursive Search
	Padre::Action->new(
		name       => 'search.find_in_files',
		label      => Wx::gettext('Find in Fi&les...'),
		comment    => Wx::gettext('Search for a text in all files below a given directory'),
		menu_event => sub {
			require Padre::Wx::Ack;
			Padre::Wx::Ack::on_ack(@_);
		},
	);

	Padre::Action->new(
		name       => 'search.open_resource',
		label      => Wx::gettext('Open Resource'),
		shortcut   => 'Ctrl-Shift-R',
		menu_event => sub {

			#Create and show the dialog
			my $open_resource_dialog = $_[0]->open_resource;
			$open_resource_dialog->showIt;
		},
	);

	Padre::Action->new(
		name       => 'search.quick_menu_access',
		label      => Wx::gettext('Quick Menu Access'),
		comment    => Wx::gettext('Quick access to all menu functions'),
		shortcut   => 'Ctrl-3',
		menu_event => sub {

			#Create and show the dialog
			require Padre::Wx::Dialog::QuickMenuAccess;
			Padre::Wx::Dialog::QuickMenuAccess->new($main)->ShowModal;
		},
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

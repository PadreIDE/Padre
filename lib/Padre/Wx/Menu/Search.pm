package Padre::Wx::Menu::Search;

# Fully encapsulated Search menu

use 5.008;
use strict;
use warnings;
use Padre::Search ();
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.44';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Search
	$self->{find} = $self->add_menu_item(
		$self,
		name       => 'search.find',
		id         => Wx::wxID_FIND,
		label      => Wx::gettext('&Find'),
		shortcut   => 'Ctrl-F',
		menu_event => sub {
			$_[0]->find->find;
		},
	);

	$self->{find_next} = $self->add_menu_item(
		$self,
		name       => 'search.find_next',
		label      => Wx::gettext('Find Next'),
		shortcut   => 'F3',
		menu_event => sub {
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

	$self->{find_previous} = $self->add_menu_item(
		$self,
		name       => 'search.find_previous',
		label      => Wx::gettext('&Find Previous'),
		shortcut   => 'Shift-F3',
		menu_event => sub {
			$_[0]->search_previous;
		},
	);

	$self->AppendSeparator;

	# Quick Find: starts search with selected text
	$self->{quick_find} = $self->add_checked_menu_item(
		$self,
		name       => 'search.quick_find',
		label      => Wx::gettext('Quick Find'),
		menu_event => sub {
			$_[0]->config->set(
				'find_quick',
				$_[1]->IsChecked ? 1 : 0,
			);
			return;
		},
	);
	$self->{quick_find}->Check( $main->config->find_quick );

	# We should be able to remove F4 and shift-F4 and hook this functionality
	# to F3 and shift-F3 Incremental find (#60)
	$self->{quick_find_next} = $self->add_menu_item(
		$self,
		name       => 'search.quick_find_next',
		label      => Wx::gettext('Find Next'),
		shortcut   => 'F4',
		menu_event => sub {
			$_[0]->fast_find->search('next');
		},
	);

	$self->{quick_find_previous} = $self->add_menu_item(
		$self,
		name       => 'search.quick_find_previous',
		label      => Wx::gettext('Find Previous'),
		shortcut   => 'Shift-F4',
		menu_event => sub {
			$_[0]->fast_find->search('previous');
		},
	);

	$self->AppendSeparator;

	# Search and Replace
	$self->{replace} = $self->add_menu_item(
		$self,
		name       => 'search.replace',
		label      => Wx::gettext('Replace'),
		shortcut   => 'Ctrl-R',
		menu_event => sub {
			$_[0]->replace->find;
		},
	);

	$self->AppendSeparator;

	# Recursive Search
	$self->add_menu_item(
		$self,
		name       => 'search.find_in_files',
		label      => Wx::gettext('Find in Fi&les...'),
		menu_event => sub {
			require Padre::Wx::Ack;
			Padre::Wx::Ack::on_ack(@_);
		},
	);

	$self->AppendSeparator;

	$self->add_menu_item(
		$self,
		name       => 'search.open_resource',
		label      => Wx::gettext('Open Resource'),
		shortcut   => 'Ctrl-Shift-R',
		menu_event => sub {

			#Create and show the dialog
			my $open_resource_dialog = $_[0]->open_resource;
			$open_resource_dialog->showIt;
		},
	);

	$self->add_menu_item(
		$self,
		name       => 'search.quick_menu_access',
		label      => Wx::gettext('Quick Menu Access'),
		shortcut   => 'Ctrl-3',
		menu_event => sub {

			#Create and show the dialog
			require Padre::Wx::Dialog::QuickMenuAccess;
			Padre::Wx::Dialog::QuickMenuAccess->new($main)->ShowModal;
		},
	);

	return $self;
}

sub refresh {
	my $self = shift;
	my $doc = _CURRENT(@_)->document ? 1 : 0;
	$self->{find}->Enable($doc);
	$self->{find_next}->Enable($doc);
	$self->{find_previous}->Enable($doc);
	$self->{replace}->Enable($doc);
	$self->{quick_find}->Enable($doc);
	$self->{quick_find_next}->Enable($doc);
	$self->{quick_find_previous}->Enable($doc);
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

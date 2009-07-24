package Padre::Wx::Menu::Search;

# Fully encapsulated Search menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.41';
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
			$_[0]->find->find_next;
		},
	);

	$self->{find_previous} = $self->add_menu_item(
		$self,
		name       => 'search.find_previous',
		label      => Wx::gettext('&Find Previous'),
		shortcut   => 'Shift-F3',
		menu_event => sub {
			$_[0]->find->find_previous;
		},
	);

	$self->AppendSeparator;

	# Quick Find: starts search with selected text
	$self->{quick_find} = $self->add_checked_menu_item(
		$self,
		name       => 'search.quick_find',
		label      => Wx::gettext('Quick Find'),
		menu_event => sub {
			Padre->ide->config->set(
				'find_quick',
				$_[1]->IsChecked ? 1 : 0,
			);
			return;
		},
	);
	$self->{quick_find}->Check( Padre->ide->config->find_quick );

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

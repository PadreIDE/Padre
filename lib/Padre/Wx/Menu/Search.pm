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
	$self->{find} = $self->Append(
		Wx::wxID_FIND,
		Wx::gettext("&Find\tCtrl-F")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{find},
		sub {
			$_[0]->find->find;
		},
	);

	$self->{find_next} = $self->Append(
		-1,
		Wx::gettext("Find Next\tF3")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{find_next},
		sub {
			$_[0]->find->find_next;
		},
	);

	$self->{find_previous} = $self->Append(
		-1,
		Wx::gettext("Find Previous\tShift-F3")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{find_previous},
		sub {
			$_[0]->find->find_previous;
		},
	);

	$self->AppendSeparator;

	# Quick Find: Press F3 to start search with selected text
	$self->{quick_find} = $self->AppendCheckItem(
		-1,
		Wx::gettext("Quick Find")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{quick_find},
		sub {
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
	$self->{quick_find_next} = $self->Append(
		-1,
		Wx::gettext("Find Next\tF4")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{quick_find_next},
		sub {
			$_[0]->fast_find->search('next');
		},
	);

	$self->{quick_find_previous} = $self->Append(
		-1,
		Wx::gettext("Find Previous\tShift-F4")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{quick_find_previous},
		sub {
			$_[0]->fast_find->search('previous');
		}
	);

	$self->AppendSeparator;

	# Search and Replace
	$self->{replace} = $self->Append(
		-1,
		Wx::gettext("Replace\tCtrl-R")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{replace},
		sub {
			$_[0]->replace->find;
		},
	);

	$self->AppendSeparator;

	# Recursive Search
	Wx::Event::EVT_MENU(
		$main,
		$self->Append(
			-1,
			Wx::gettext("Find in Fi&les...")
		),
		sub {
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

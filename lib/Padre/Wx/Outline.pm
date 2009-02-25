package Padre::Wx::Outline;

use 5.008;
use strict;
use warnings;
use Params::Util   qw{_INSTANCE};
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.27';
our @ISA     = 'Wx::TreeCtrl';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS  
	);
	$self->SetIndent(10);
	$self->{force_next} = 0;

	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self,
		sub {
			$self->on_tree_item_activated($_[1]);
		},
	);

	$self->Hide;

	return $self;
}

sub right {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub gettext_label {
	Wx::gettext('Outline');
}

sub clear {
	$_[0]->DeleteAllItems;
	return;
}

sub force_next {
	my $self = shift;

	if ( defined $_[0] ) {
		$self->{force_next} = $_[0];
		return $self->{force_next};
	}
	else {
		return $self->{force_next};
	}
}



#####################################################################
# Timer Control

sub start {
	my $self = shift;

	# TODO: GUI on-start initialisation here

	# Set up or reinitialise the timer
	if ( _INSTANCE($self->{timer}, 'Wx::Timer') ) {
		$self->{timer}->Stop if $self->{timer}->IsRunning;
	} else {
		$self->{timer} = Wx::Timer->new(
			$self,
			Padre::Wx::ID_TIMER_OUTLINE
		);
		Wx::Event::EVT_TIMER( $self,
			Padre::Wx::ID_TIMER_OUTLINE,
			sub {
				$self->on_timer($_[1], $_[2]);
			},
		);
	}
	$self->{timer}->Start( 1000 );
	$self->on_timer( undef, 1 );

	return;
}

sub stop {
	my $self = shift;

	# Stop the timer
	if ( _INSTANCE($self->{timer}, 'Wx::Timer') ) {
		$self->{timer}->Stop if $self->{timer}->IsRunning;
	}

	$self->clear;

	# TODO: GUI on-stop cleanup here

	return;
}

sub running {
	!! ($_[0]->{timer} and $_[0]->{timer}->IsRunning);
}





#####################################################################
# Event Handlers

sub on_tree_item_activated {
	my ($self, $event) = @_;
	my $page = $self->main->current->editor;

	my $item = $self->GetPlData( $event->GetItem );
	return if not defined $item;

	my $line_number = $item->{line};
	return if not defined($line_number)
		  or $line_number !~ /^\d+$/o
		  or $page->GetLineCount < $line_number;

	$line_number--;
	$page->EnsureVisible($line_number);
	$page->goto_pos_centerize( $page->GetLineIndentPosition($line_number) );
	$page->SetFocus;

	return;
}

sub on_timer {
	my ( $self, $event, $force ) = @_;

	my $document = $self->main->current->document or return;

	unless ( $document->can('get_outline') ) {
		$self->clear;
		return;
	}

	if ( $self->force_next ) {
		$force = 1;
		$self->force_next(0);
	}

	$document->get_outline(force => $force);

	if ( defined($event) ) {
		$event->Skip(0);
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

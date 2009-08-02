package Padre::Wx::Outline;

use 5.008;
use strict;
use warnings;
use Params::Util qw{_INSTANCE};
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.42';
our @ISA     = 'Wx::TreeCtrl';

use Class::XSAccessor accessors => {
	force_next => 'force_next',
};

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS | Wx::wxTR_LINES_AT_ROOT
	);
	$self->SetIndent(10);
	$self->{force_next} = 0;

	Wx::Event::EVT_COMMAND_SET_FOCUS(
		$self, $self,
		sub {
			$self->on_tree_item_set_focus( $_[1] );
		},
	);

	# Double-click a function name
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		sub {
			$self->on_tree_item_activated( $_[1] );
		}
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

#####################################################################
# Timer Control

sub start {
	my $self = shift; @_ = (); # Feeble attempt to kill Scalars Leaked ($self is leaking)

	# TODO: GUI on-start initialisation here

	# Set up or reinitialise the timer
	if ( _INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->{timer}->Stop if $self->{timer}->IsRunning;
	} else {
		$self->{timer} = Wx::Timer->new(
			$self,
			Padre::Wx::ID_TIMER_OUTLINE
		);
		Wx::Event::EVT_TIMER(
			$self,
			Padre::Wx::ID_TIMER_OUTLINE,
			sub {
				$self->on_timer( $_[1], $_[2] );
			},
		);
	}
	$self->{timer}->Start(1000);
	$self->on_timer( undef, 1 );

	return ();
}

sub stop {
	my $self = shift;

	Padre::Util::debug("stopping Outline");

	# Stop the timer
	if ( _INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->{timer}->Stop if $self->{timer}->IsRunning;
	}

	$self->clear;

	# TODO: GUI on-stop cleanup here

	return ();
}

sub running {
	!!( $_[0]->{timer} and $_[0]->{timer}->IsRunning );
}

#####################################################################
# Event Handlers

sub on_tree_item_set_focus {
	my ( $self, $event ) = @_;
	my $main = Padre::Current->main($self);
	my $page = $main->current->editor;
	my $selection = $self->GetSelection();
	if ($selection and $selection->IsOk ) { 
		my $item = $self->GetPlData( $selection );
		if ( defined $item ) {
			$self->select_line_in_editor( $item->{line} );
		}
	}
	return;
}

sub on_tree_item_activated {
	on_tree_item_set_focus(@_);
	return;
}

sub select_line_in_editor {
	my ( $self, $line_number ) = @_;
	my $main = Padre::Current->main($self);
	my $page = $main->current->editor;
	if (   defined $line_number
		&& ( $line_number =~ /^\d+$/o )
		&& ( defined $page )
		&& ( $line_number <= $page->GetLineCount ) )
	{
		$line_number--;
		$page->EnsureVisible($line_number);
		$page->goto_pos_centerize( $page->GetLineIndentPosition($line_number) );
		$page->SetFocus;
	}
	return;
}

sub on_timer {
	my ( $self, $event, $force ) = @_;

	### NOTE:
	# floating windows, when undocked (err... "floating"), will
	# return Wx::AuiFloatingFrame as their parent. So floating
	# windows should always get their "main" from Padre::Current->main
	# and -not- from $self->main.
	my $main = Padre::Current->main($self);

	my $document = $main->current->document or return;

	unless ( $document->can('get_outline') ) {
		$self->clear;
		return;
	}

	if ( $self->force_next ) {
		$force = 1;
		$self->force_next(0);
	}

	$document->get_outline( force => $force );

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

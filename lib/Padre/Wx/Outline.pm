package Padre::Wx::Outline;

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.25';
our @ISA     = 'Wx::TreeCtrl';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_DEFAULT_STYLE
	);

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

sub on_tree_item_activated {
	my $self  = shift;
	my $event = shift;
	my $page  = $self->main->current->editor;

	#my $line_number = $event->GetItem->GetText;
	#return if  not defined($line_number)
	#		or $line_number !~ /^\d+$/o
	#		or $page->GetLineCount < $line_number;

	#$line_number--;
	#$page->EnsureVisible($line_number);
	#$page->GotoPos( $page->GetLineIndentPosition($line_number) );
	#$page->SetFocus;

	return;
}

sub on_idle {
	# TODO: This will probably violate encapsulation
	my ( $main, $event ) = @_;
	my $self = $main->outline;

	#$self->{synCheckTimer}->Stop if $self->{synCheckTimer}->IsRunning;
	#$self->{synCheckTimer}->Start(300, 1);

	$event->Skip(0);
	return;
}

sub on_timer {
	# TODO: This will probably violate encapsulation
	my ( $main, $event, $force ) = @_;
	my $self     = $main->outline;
	my $document = $main->current->document or return;
	my $page     = $document->editor;

	unless ( $document->can('get_outline') ) {
		$self->DeleteAllItems;
		return;
	}

	#$document->get_outline_in_background(force => $force);
	
	if ( defined($event) ) {
		$event->Skip(0);
	}

	return;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

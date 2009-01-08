package Padre::Wx::DocOutliner;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.24';

use Class::XSAccessor
	getters => {
		main => 'main',
	};

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = bless {
		@_,
		main => $main,
	}, $class;

	$self->create_outlinebar($main);

	return $self;
}

sub DESTROY {
	delete $_[0]->{main};
}

sub create_outlinebar {
	my $self = shift;
	my $main = $self->main;

	# TODO: Violates encapsulation
	$main->{gui}->{outline_panel} = Wx::TreeCtrl->new(
		$main->{gui}->{sidepane},
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_DEFAULT_STYLE
	);

	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$main,
		$main->{gui}->{outline_panel},
                \&on_outlineelem_selected,
        );

	return;
}

sub outlinebar {
	return $_[0]->main->{gui}->{outline_panel};
}

sub enable {
	my $self = shift;
	my $on   = shift;
	my $main = $self->main;

	if ( $on ) {
		$main->show_outlinebar(1);
	}
	else {
		$main->show_outlinebar(0);
	}

	return;
}

sub outline_idle_timer {
	my ( $main, $event ) = @_;
	my $self = $main->doc_outliner;

	#$self->{synCheckTimer}->Stop if $self->{synCheckTimer}->IsRunning;
	#$self->{synCheckTimer}->Start(300, 1);

	$event->Skip(0);
	return;
}

sub on_outlineelem_selected {
	my ($main, $event) = @_;

	my $page = $main->current->editor;

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

sub on_outline_timer {
	my ( $win, $event, $force ) = @_;
	my $self = $win->doc_outliner;
	my $outlinebar = $self->outlinebar;

	my $page = $win->current->editor;
	if ( ! defined $page ) {
		return;
	}
	my $document = $page->{Document};

	unless ( defined( $document ) and $document->can('get_outline') ) {
		$outlinebar->DeleteAllItems;
		return;
	}

	#$document->get_outline_in_background(force => $force);
	
	if ( defined($event) ) {
		$event->Skip(0);
	}
	return();
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

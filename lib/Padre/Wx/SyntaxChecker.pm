package Padre::Wx::SyntaxChecker;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.22';

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

	$self->create_syntaxbar($main);

	return $self;
}

sub DESTROY {
	delete $_[0]->{main};
}

sub create_syntaxbar {
	my $self = shift;
	my $main = $self->main;

	$main->{gui}->{syntaxcheck_panel} = Wx::ListView->new(
		$main->{gui}->{bottompane},
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);
	my $syntaxbar = $main->{gui}->{syntaxcheck_panel};

	$syntaxbar->InsertColumn( 0, Wx::gettext('Line') );
	$syntaxbar->InsertColumn( 1, Wx::gettext('Type') );
	$syntaxbar->InsertColumn( 2, Wx::gettext('Description') );

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$main,
		$syntaxbar,
		\&on_syntax_check_msg_selected,
	);

	return;
}

sub syntaxbar {
	return $_[0]->main->{gui}->{syntaxcheck_panel};
}

sub enable {
	my $self = shift;
	my $on   = shift;
	my $main = $self->main;

	if ( $on ) {
		if (   defined( $self->{synCheckTimer} )
			&& ref $self->{synCheckTimer} eq 'Wx::Timer'
		) {
			Wx::Event::EVT_IDLE( $main, \&syntax_check_idle_timer );
			on_syntax_check_timer( $main, undef, 1 );
		}
		else {
			$self->{synCheckTimer} = Wx::Timer->new($main, Padre::Wx::id_SYNCHK_TIMER);
			Wx::Event::EVT_TIMER( $main, Padre::Wx::id_SYNCHK_TIMER, \&on_syntax_check_timer );
			Wx::Event::EVT_IDLE( $main, \&syntax_check_idle_timer );
		}
		$main->show_syntaxbar(1);
	}
	else {
		if (   defined($self->{synCheckTimer})
			&& ref $self->{synCheckTimer} eq 'Wx::Timer'
		) {
			$self->{synCheckTimer}->Stop;
			Wx::Event::EVT_IDLE( $main, sub { return } );
		}
		my $page = $main->selected_editor;
		if ( defined($page) ) {
			$page->MarkerDeleteAll(Padre::Wx::MarkError);
			$page->MarkerDeleteAll(Padre::Wx::MarkWarn);
		}
		$self->syntaxbar->DeleteAllItems;
		$main->show_syntaxbar(0);
	}

	# Setup a margin to hold fold markers
	foreach my $editor ($main->pages) {
		if ($on) {
			$editor->SetMarginType(1, Wx::wxSTC_MARGIN_SYMBOL); # margin number 1 for symbols
			$editor->SetMarginWidth(1, 16);                     # set margin 1 16 px wide
		} else {
			$editor->SetMarginWidth(1, 0);
		}
	}

	return;
}

sub syntax_check_idle_timer {
	my ( $main, $event ) = @_;
	my $self = $main->syntax_checker;

	$self->{synCheckTimer}->Stop if $self->{synCheckTimer}->IsRunning;
	$self->{synCheckTimer}->Start(300, 1);

	$event->Skip(0);
	return;
}

sub on_syntax_check_msg_selected {
	my ($main, $event) = @_;

	my $page = $main->selected_editor;

	my $line_number = $event->GetItem->GetText;
	return if  not defined($line_number)
			or $line_number !~ /^\d+$/o
			or $page->GetLineCount < $line_number;

	$line_number--;
	$page->EnsureVisible($line_number);
	$page->GotoPos( $page->GetLineIndentPosition($line_number) );
	$page->SetFocus;

	return;
}

sub on_syntax_check_timer {
	my ( $win, $event, $force ) = @_;
	my $self = $win->syntax_checker;
	my $syntaxbar = $self->syntaxbar;

	my $page = $win->selected_editor;
	if ( ! defined $page ) {
		return;
	}
	my $document = $page->{Document};

	unless ( defined( $document ) and $document->can('check_syntax') ) {
		if ( defined $page and $page->isa('Padre::Wx::Editor') ) {
			$page->MarkerDeleteAll(Padre::Wx::MarkError);
			$page->MarkerDeleteAll(Padre::Wx::MarkWarn);
		}
		$syntaxbar->DeleteAllItems;
		return;
	}

	$document->check_syntax_in_background(force => $force);
	
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

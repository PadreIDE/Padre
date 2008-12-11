package Padre::Wx::SyntaxChecker;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.20';

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

	$main->{gui}->{bottompane}->InsertPage( 1, $syntaxbar, Wx::gettext("Syntax Check"), 0 );

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$main,
		$syntaxbar,
		\&on_syntax_check_msg_selected,
	);

	if ( $main->menu->view->{show_syntaxcheck}->IsChecked ) {
		$syntaxbar->Show();
	}
	else {
		$syntaxbar->Hide();
	}

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
	$self->{synCheckTimer}->Start(500, 1);

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

	unless ( defined( $page->{Document} ) and $page->{Document}->can('check_syntax') ) {
		if ( ref $page eq 'Padre::Wx::Editor' ) {
			$page->MarkerDeleteAll(Padre::Wx::MarkError);
			$page->MarkerDeleteAll(Padre::Wx::MarkWarn);
		}
		$syntaxbar->DeleteAllItems;
		return;
	}

	my $messages = $page->{Document}->check_syntax($force);
	return unless defined $messages;

	if ( scalar(@{$messages}) > 0 ) {
		$page->MarkerDeleteAll(Padre::Wx::MarkError);
		$page->MarkerDeleteAll(Padre::Wx::MarkWarn);

		my $red = Wx::Colour->new("red");
		my $orange = Wx::Colour->new("orange");
		$page->MarkerDefine(Padre::Wx::MarkError, Wx::wxSTC_MARK_SMALLRECT, $red, $red);
		$page->MarkerDefine(Padre::Wx::MarkWarn,  Wx::wxSTC_MARK_SMALLRECT, $orange, $orange);

		my $i = 0;
		$syntaxbar->DeleteAllItems;
		delete $page->{synchk_calltips};
		my $last_hint = '';
		foreach my $hint ( sort { $a->{line} <=> $b->{line} } @{$messages} ) {
			my $l = $hint->{line} - 1;
			if ( $hint->{severity} eq 'W' ) {
				$page->MarkerAdd( $l, 2);
			}
			else {
				$page->MarkerAdd( $l, 1);
			}
			my $idx = $syntaxbar->InsertStringItem( $i++, $l + 1 );
			$syntaxbar->SetItem( $idx, 1, ( $hint->{severity} eq 'W' ? Wx::gettext('Warning') : Wx::gettext('Error') ) );
			$syntaxbar->SetItem( $idx, 2, $hint->{msg} );

			if ( exists $page->{synchk_calltips}->{$l} ) {
				$page->{synchk_calltips}->{$l} .= "\n--\n" . $hint->{msg};
			}
			else {
				$page->{synchk_calltips}->{$l} = $hint->{msg};
			}
			$last_hint = $hint;
		}

		my $width0_default = $page->TextWidth( Wx::wxSTC_STYLE_DEFAULT, Wx::gettext("Line") . ' ' );
		my $width0 = $page->TextWidth( Wx::wxSTC_STYLE_DEFAULT, $last_hint->{line} x 2 );
		my $refStr = '';
		if ( length( Wx::gettext('Warning') ) > length( Wx::gettext('Error') ) ) {
			$refStr = Wx::gettext('Warning');
		}
		else {
			$refStr = Wx::gettext('Error');
		}
		my $width1 = $page->TextWidth( Wx::wxSTC_STYLE_DEFAULT, $refStr . ' ' );
		my $width2 = $syntaxbar->GetSize->GetWidth - $width0 - $width1 - $syntaxbar->GetCharWidth * 2;
		$syntaxbar->SetColumnWidth( 0, ( $width0_default > $width0 ? $width0_default : $width0 ) );
		$syntaxbar->SetColumnWidth( 1, $width1 );
		$syntaxbar->SetColumnWidth( 2, $width2 );
	}
	else {
		$page->MarkerDeleteAll(Padre::Wx::MarkError);
		$page->MarkerDeleteAll(Padre::Wx::MarkWarn);
		$syntaxbar->DeleteAllItems;
	}

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

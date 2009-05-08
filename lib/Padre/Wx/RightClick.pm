package Padre::Wx::RightClick;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.35';
use constant HEIGHT => 30;

# This is the traditional, STATIC context menu that was moved here
# from the Padre::Wx::Editor class. We will have to add a variable
# portion to it depending on the context. Maybe even user-customization!
# --Steffen

sub on_right_down {
	my $self  = shift;
	my $event = shift;
	my $main  = $self->main;
	my $pos   = $self->GetCurrentPos;

	#my $line  = $self->LineFromPosition($pos);
	#print "right down: $pos\n"; # this is the position of the cursor and not that of the mouse!
	#my $p = $event->GetLogicalPosition;
	#print "x: ", $p->x, "\n";

	my $menu = Wx::Menu->new;
	my $undo = $menu->Append( Wx::wxID_UNDO, '' );
	if ( not $self->CanUndo ) {
		$undo->Enable(0);
	}
	my $z = Wx::Event::EVT_MENU(
		$main,    # Ctrl-Z
		$undo,
		sub {
			my $editor = Padre::Current->editor;
			if ( $editor->CanUndo ) {
				$editor->Undo;
			}
			return;
		},
	);
	my $redo = $menu->Append( Wx::wxID_REDO, '' );
	if ( not $self->CanRedo ) {
		$redo->Enable(0);
	}

	Wx::Event::EVT_MENU(
		$main,    # Ctrl-Y
		$redo,
		sub {
			my $editor = Padre::Current->editor;
			if ( $editor->CanRedo ) {
				$editor->Redo;
			}
			return;
		},
	);
	$menu->AppendSeparator;

	my $selection_exists = 0;
	my $id               = $main->notebook->GetSelection;
	if ( $id != -1 ) {
		my $text = $main->notebook->GetPage($id)->GetSelectedText;
		if ( defined($text) && length($text) > 0 ) {
			$selection_exists = 1;
		}
	}

	my $sel_all = $menu->Append( Wx::wxID_SELECTALL, Wx::gettext("Select all\tCtrl-A") );
	if ( not $main->notebook->GetPage($id)->GetTextLength > 0 ) {
		$sel_all->Enable(0);
	}
	Wx::Event::EVT_MENU(
		$main,    # Ctrl-A
		$sel_all,
		sub { \&text_select_all(@_) },
	);
	$menu->AppendSeparator;

	my $copy = $menu->Append( Wx::wxID_COPY, Wx::gettext("&Copy\tCtrl-C") );
	if ( not $selection_exists ) {
		$copy->Enable(0);
	}
	Wx::Event::EVT_MENU(
		$main,    # Ctrl-C
		$copy,
		sub {
			Padre::Current->editor->Copy;
		}
	);

	my $cut = $menu->Append( Wx::wxID_CUT, Wx::gettext("Cu&t\tCtrl-X") );
	if ( not $selection_exists ) {
		$cut->Enable(0);
	}
	Wx::Event::EVT_MENU(
		$main,    # Ctrl-X
		$cut,
		sub {
			Padre::Current->editor->Cut;
		}
	);

	my $paste = $menu->Append( Wx::wxID_PASTE, Wx::gettext("&Paste\tCtrl-V") );
	my $text = $self->get_text_from_clipboard();

	if ( length($text) && $main->notebook->GetPage($id)->CanPaste ) {
		Wx::Event::EVT_MENU(
			$main,    # Ctrl-V
			$paste,
			sub {
				Padre::Current->editor->Paste;
			},
		);
	} else {
		$paste->Enable(0);
	}

	$menu->AppendSeparator;

	my $commentToggle = $menu->Append( -1, Wx::gettext("&Toggle Comment\tCtrl-Shift-C") );
	Wx::Event::EVT_MENU(
		$main, $commentToggle,
		\&Padre::Wx::Main::on_comment_toggle_block,
	);
	my $comment = $menu->Append( -1, Wx::gettext("&Comment Selected Lines\tCtrl-M") );
	Wx::Event::EVT_MENU(
		$main, $comment,
		\&Padre::Wx::Main::on_comment_out_block,
	);
	my $uncomment = $menu->Append( -1, Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M") );
	Wx::Event::EVT_MENU(
		$main, $uncomment,
		\&Padre::Wx::Main::on_uncomment_block,
	);

	$menu->AppendSeparator;

	if ( $event->isa('Wx::MouseEvent')
		and Padre->ide->config->editor_folding )
	{
		my $mousePos         = $event->GetPosition;
		my $line             = $self->LineFromPosition( $self->PositionFromPoint($mousePos) );
		my $firstPointInLine = $self->PointFromPosition( $self->PositionFromLine($line) );

		if (   $mousePos->x < $firstPointInLine->x
			&& $mousePos->x > ( $firstPointInLine->x - 18 ) )
		{
			my $fold = $menu->Append( -1, Wx::gettext("Fold all") );
			Wx::Event::EVT_MENU(
				$main, $fold,
				sub {
					$_[0]->current->editor->fold_all;
				},
			);
			my $unfold = $menu->Append( -1, Wx::gettext("Unfold all") );
			Wx::Event::EVT_MENU(
				$main, $unfold,
				sub {
					$_[0]->current->editor->unfold_all;
				},
			);
			$menu->AppendSeparator;
		}
	}

	Wx::Event::EVT_MENU(
		$main,
		$menu->Append( -1, Wx::gettext("&Split window") ),
		\&Padre::Wx::Main::on_split_window,
	);

	my $doc = $self->{Document};
	if ( $doc->can('event_on_right_down') ) {
		$doc->event_on_right_down( $self, $menu, $event );
	}

	if ( $event->isa('Wx::MouseEvent') ) {
		$self->PopupMenu( $menu, $event->GetX, $event->GetY );
	} else {    #Wx::CommandEvent
		$self->PopupMenu( $menu, 50, 50 );    # TODO better location
	}
}

# This is the experimental GENERATED context menu. We can expand on that
# later, but right now, it produces quite the ugly (and useless) button-based
# context menu --Steffen

#sub on_right_down {
#	my ( $self, $event ) = @_;
#	my @options = qw(abc def);
#	my $dialog  = Wx::Dialog->new(
#		$self,
#		-1,
#		"",
#		[ -1,  -1 ],
#		[ 100, 50 + HEIGHT * $#options ],
#		Wx::wxBORDER_SIMPLE,
#	);
#	foreach my $i ( 0 .. @options - 1 ) {
#		Wx::Event::EVT_BUTTON(
#			$dialog,
#			Wx::Button->new( $dialog, -1, $options[$i], [ 10, 10 + HEIGHT * $i ] ),
#			sub {
#				on_right( @_, $i );
#			}
#		);
#	}
#	my $ret = $dialog->Show;
#	return;
#}
#
#sub on_right {
#	my ( $self, $event, $val ) = @_;
#        warn "here";
#	$self->Hide;
#	$self->Destroy;
#	return;
#}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

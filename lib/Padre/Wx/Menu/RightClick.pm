package Padre::Wx::Menu::RightClick;

# Menu that shows up when user right-clicks with the mouse

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.53';
our @ISA     = 'Padre::Wx::Menu';

sub new {
	my $class = shift;
	my $main  = shift;
	my $editor = shift;
	my $event = shift;

	# Create the empty menu as normal
	my $self = Wx::Menu->new; #$class->SUPER::new(@_);

	# Add additional properties
	#$self->{main} = $main;


	my $undo = $self->Append( Wx::wxID_UNDO, '' );
	if ( not $editor->CanUndo ) {
		$undo->Enable(0);
	}
	my $z = Wx::Event::EVT_MENU(
		$main, # Ctrl-Z
		$undo,
		sub {
			my $editor = Padre::Current->editor;
			if ( $editor->CanUndo ) {
				$editor->Undo;
			}
			return;
		},
	);
	my $redo = $self->Append( Wx::wxID_REDO, '' );
	if ( not $editor->CanRedo ) {
		$redo->Enable(0);
	}

	Wx::Event::EVT_MENU(
		$main, # Ctrl-Y
		$redo,
		sub {
			my $editor = Padre::Current->editor;
			if ( $editor->CanRedo ) {
				$editor->Redo;
			}
			return;
		},
	);
	$self->AppendSeparator;

	my $selection_exists = 0;
	my $id               = $main->notebook->GetSelection;
	if ( $id != -1 ) {
		my $text = $main->notebook->GetPage($id)->GetSelectedText;
		if ( defined($text) && length($text) > 0 ) {
			$selection_exists = 1;
		}
	}

	my $sel_all = $self->Append( Wx::wxID_SELECTALL, Wx::gettext("Select all\tCtrl-A") );
	if ( not $main->notebook->GetPage($id)->GetTextLength > 0 ) {
		$sel_all->Enable(0);
	}
	Wx::Event::EVT_MENU(
		$main, # Ctrl-A
		$sel_all,
		sub { \&text_select_all(@_) },
	);
	$self->AppendSeparator;

	my $copy = $self->Append( Wx::wxID_COPY, Wx::gettext("&Copy\tCtrl-C") );
	if ( not $selection_exists ) {
		$copy->Enable(0);
	}
	Wx::Event::EVT_MENU(
		$main, # Ctrl-C
		$copy,
		sub {
			Padre::Current->editor->Copy;
		}
	);

	my $cut = $self->Append( Wx::wxID_CUT, Wx::gettext("Cu&t\tCtrl-X") );
	if ( not $selection_exists ) {
		$cut->Enable(0);
	}
	Wx::Event::EVT_MENU(
		$main, # Ctrl-X
		$cut,
		sub {
			Padre::Current->editor->Cut;
		}
	);

	my $paste = $self->Append( Wx::wxID_PASTE, Wx::gettext("&Paste\tCtrl-V") );
	my $text = $editor->get_text_from_clipboard();

	if ( defined($text) and length($text) && $main->notebook->GetPage($id)->CanPaste ) {
		Wx::Event::EVT_MENU(
			$main, # Ctrl-V
			$paste,
			sub {
				Padre::Current->editor->Paste;
			},
		);
	} else {
		$paste->Enable(0);
	}

	$self->AppendSeparator;

	my $commentToggle = $self->Append( -1, Wx::gettext("&Toggle Comment\tCtrl-Shift-C") );
	Wx::Event::EVT_MENU(
		$main,
		$commentToggle,
		sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'TOGGLE' );
		},
	);
	my $comment = $self->Append( -1, Wx::gettext("&Comment Selected Lines\tCtrl-M") );
	Wx::Event::EVT_MENU(
		$main, $comment,
		sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'COMMENT' );
		},
	);
	my $uncomment = $self->Append( -1, Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M") );
	Wx::Event::EVT_MENU(
		$main,
		$uncomment,
		sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'UNCOMMENT' );
		},
	);

	if (    $event->isa('Wx::MouseEvent')
		and $editor->main->ide->config->editor_folding )
	{
		$self->AppendSeparator;

		my $mousePos         = $event->GetPosition;
		my $line             = $editor->LineFromPosition( $editor->PositionFromPoint($mousePos) );
		my $firstPointInLine = $editor->PointFromPosition( $editor->PositionFromLine($line) );

		if (   $mousePos->x < $firstPointInLine->x
			&& $mousePos->x > ( $firstPointInLine->x - 18 ) )
		{
			my $fold = $self->Append( -1, Wx::gettext("Fold all") );
			Wx::Event::EVT_MENU(
				$main, $fold,
				sub {
					$_[0]->current->editor->fold_all;
				},
			);
			my $unfold = $self->Append( -1, Wx::gettext("Unfold all") );
			Wx::Event::EVT_MENU(
				$main, $unfold,
				sub {
					$_[0]->current->editor->unfold_all;
				},
			);
			$self->AppendSeparator;
		}
	}

	my $doc = $editor->{Document};
	if ( $doc->can('event_on_right_down') ) {
		$doc->event_on_right_down( $editor, $self, $event );
	}

	# Let the plugins have a go
	$editor->main->ide->plugin_manager->on_context_menu( $doc, $editor, $self, $event );
	
	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

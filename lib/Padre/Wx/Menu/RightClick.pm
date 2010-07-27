package Padre::Wx::Menu::RightClick;

# Menu that shows up when user right-clicks with the mouse

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.68';
our @ISA     = 'Padre::Wx::Menu';

sub new {
	my $class  = shift;
	my $main   = shift;
	my $editor = shift;
	my $event  = shift;

	return if not $editor;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	my $selection_exists = length( $editor->GetSelectedText ) > 0 ? 1 : 0;

	# Undo/Redo
	$self->{undo} = $self->add_menu_action(
		$self,
		'edit.undo',
	);
	if ( not $editor->CanUndo ) {
		$self->{undo}->Enable(0);
	}

	$self->{redo} = $self->add_menu_action(
		$self,
		'edit.redo',
	);
	if ( not $editor->CanRedo ) {
		$self->{redo}->Enable(0);
	}

	$self->AppendSeparator;

	if ($selection_exists) {
		$self->{open_selection} = $self->add_menu_action(
			$self,
			'file.open_selection',
		);
	}

	$self->{open_in_file_browser} = $self->add_menu_action(
		$self,
		'file.open_in_file_browser',
	);

	$self->{find_in_files} = $self->add_menu_action(
		$self,
		'search.find_in_files',
	);

	$self->AppendSeparator;

	$self->{copy} = $self->add_menu_action(
		$self,
		'edit.copy',
	);
	$self->{cut} = $self->add_menu_action(
		$self,
		'edit.cut',
	);

	if ( not $selection_exists ) {
		$self->{copy}->Enable(0);
		$self->{cut}->Enable(0);
	}


	$self->{paste} = $self->add_menu_action(
		$self,
		'edit.paste',
	);
	my $text = $editor->get_text_from_clipboard();
	if ( not defined($text) or not length($text) or not $editor->CanPaste ) {
		$self->{paste}->Enable(0);
	}

	$self->{select_all} = $self->add_menu_action(
		$self,
		'edit.select_all',
	);

	$self->AppendSeparator;

	$self->{comment_toggle} = $self->add_menu_action(
		$self,
		'edit.comment_toggle',
	);

	$self->{comment} = $self->add_menu_action(
		$self,
		'edit.comment',
	);

	$self->{uncomment} = $self->add_menu_action(
		$self,
		'edit.uncomment',
	);


	if (    $event->isa('Wx::MouseEvent')
		and $editor->main->ide->config->editor_folding )
	{
		my $mousePos         = $event->GetPosition;
		my $line             = $editor->LineFromPosition( $editor->PositionFromPoint($mousePos) );
		my $firstPointInLine = $editor->PointFromPosition( $editor->PositionFromLine($line) );

		if (   $mousePos->x < $firstPointInLine->x
			&& $mousePos->x > ( $firstPointInLine->x - 18 ) )
		{
			$self->AppendSeparator;

			$self->{fold_all} = $self->add_menu_action(
				$self,
				'view.fold_all',
			);
			$self->{unfold_all} = $self->add_menu_action(
				$self,
				'view.unfold_all',
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

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

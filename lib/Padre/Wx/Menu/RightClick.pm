package Padre::Wx::Menu::RightClick;

# Menu that shows up when user right-clicks with the mouse

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Feature  ();

our $VERSION = '0.90';
our @ISA     = 'Padre::Wx::Menu';

sub new {
	my $class  = shift;
	my $main   = shift;
	my $editor = shift or return;
	my $event  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	my $selection = length( $editor->GetSelectedText ) > 0 ? 1 : 0;

	# Undo/Redo
	$self->{undo} = $self->add_menu_action(
		'edit.undo',
	);
	unless ( $editor->CanUndo ) {
		$self->{undo}->Enable(0);
	}

	$self->{redo} = $self->add_menu_action(
		'edit.redo',
	);
	unless ( $editor->CanRedo ) {
		$self->{redo}->Enable(0);
	}

	$self->AppendSeparator;

	if ($selection) {
		$self->{open_selection} = $self->add_menu_action(
			'file.open_selection',
		);
	}

	$self->{open_in_file_browser} = $self->add_menu_action(
		'file.open_in_file_browser',
	);

	$self->{find_in_files} = $self->add_menu_action(
		'search.find_in_files',
	);

	$self->AppendSeparator;

	$self->{cut} = $self->add_menu_action(
		'edit.cut',
	);

	$self->{copy} = $self->add_menu_action(
		'edit.copy',
	);

	unless ($selection) {
		$self->{copy}->Enable(0);
		$self->{cut}->Enable(0);
	}

	$self->{paste} = $self->add_menu_action(
		'edit.paste',
	);
	my $text = $editor->get_text_from_clipboard;
	unless ( defined $text and length $text and $editor->CanPaste ) {
		$self->{paste}->Enable(0);
	}

	$self->{select_all} = $self->add_menu_action(
		'edit.select_all',
	);

	$self->AppendSeparator;

	$self->{comment_toggle} = $self->add_menu_action(
		'edit.comment_toggle',
	);

	$self->{comment} = $self->add_menu_action(
		'edit.comment',
	);

	$self->{uncomment} = $self->add_menu_action(
		'edit.uncomment',
	);

	my $config = $main->config;
	if (    Padre::Feature::FOLDING
		and $event->isa('Wx::MouseEvent')
		and $config->editor_folding )
	{
		my $position = $event->GetPosition;
		my $line     = $editor->LineFromPosition( $editor->PositionFromPoint($position) );
		my $point    = $editor->PointFromPosition( $editor->PositionFromLine($line) );

		if ( $position->x < $point->x and $position->x > ( $point->x - 18 ) ) {
			$self->AppendSeparator;

			$self->{fold_all} = $self->add_menu_action(
				'view.fold_all',
			);

			$self->{unfold_all} = $self->add_menu_action(
				'view.unfold_all',
			);

		}
	}

	my $document = $editor->{Document};
	if ($document) {
		$self->AppendSeparator;

		if ( $document->can('event_on_right_down') ) {
			$document->event_on_right_down( $editor, $self, $event );
		}

		# Let the plugins have a go
		$editor->main->ide->plugin_manager->on_context_menu(
			$document, $editor, $self, $event,
		);
	}

	return $self;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

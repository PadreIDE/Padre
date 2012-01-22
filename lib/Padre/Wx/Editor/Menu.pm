package Padre::Wx::Editor::Menu;

# Menu that shows up when user right-clicks with the mouse

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Feature  ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::Menu';

sub new {
	my $class     = shift;
	my $editor    = shift or return;
	my $event     = shift;
	my $selection = $editor->GetSelectionLength ? 1 : 0;

	# Create the empty menu
	my $self = $class->SUPER::new(@_);
	$self->{main} = $editor->main;

	# The core cut/paste entries the same as every other editor

	$self->{cut}  = $self->add_menu_action('edit.cut');
	$self->{copy} = $self->add_menu_action('edit.copy');

	unless ($selection) {
		$self->{copy}->Enable(0);
		$self->{cut}->Enable(0);
	}

	$self->{paste} = $self->add_menu_action(
		'edit.paste',
	);
	unless ( $editor->CanPaste ) {
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

	# Search, replace and navigation

	if ($selection) {
		$self->AppendSeparator;

		$self->{open_selection} = $self->add_menu_action(
			'file.open_selection',
		);

		$self->{find_in_files} = $self->add_menu_action(
			'search.find_in_files',
		);
	}

	my $config = $self->{main}->config;
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
		if ( $document->can('event_on_context_menu') ) {
			$document->event_on_context_menu( $editor, $self, $event );
		}

		# Let the plugins have a go
		$editor->main->ide->plugin_manager->on_context_menu(
			$document, $editor, $self, $event,
		);
	}

	return $self;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

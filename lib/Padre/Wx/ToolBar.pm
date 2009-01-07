package Padre::Wx::ToolBar;

use 5.008;
use strict;
use warnings;
use Padre::Current    qw{_CURRENT};
use Padre::Wx         ();
use Padre::Wx::Editor ();

our $VERSION = '0.24';
our @ISA     = 'Wx::ToolBar';

sub new {
	my $class = shift;
	my $main  = shift;

	# Prepare the style
	my $style = Wx::wxNO_BORDER
		| Wx::wxTB_HORIZONTAL
		| Wx::wxTB_FLAT;
	unless ( $main->config->{lock_panels} ) {
		$style = $style | Wx::wxTB_DOCKABLE;
	}

	# Create the parent Wx object
	my $self = $class->SUPER::new( $main, -1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		$style,
		5050,
	);

	# Automatically populate
	$self->AddTool(
		Wx::wxID_NEW, '',
		Padre::Wx::tango( 'actions', 'document-new.png' ),
		Wx::gettext('New File'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_NEW,
		sub { $_[0]->on_new },
	);

	$self->AddTool(
		Wx::wxID_OPEN, '',
		Padre::Wx::tango( 'actions', 'document-open.png' ),
		Wx::gettext('Open File'),
	);

	$self->AddTool(
		Wx::wxID_SAVE, '',
		Padre::Wx::tango( 'actions', 'document-save.png' ),
		Wx::gettext('Save File'),
	);

	$self->AddTool(
		Wx::wxID_CLOSE, '',
		Padre::Wx::tango( 'emblems', 'emblem-unreadable.png' ),
		Wx::gettext('Close File'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_CLOSE,
		sub { $_[0]->on_close($_[1]) },
	);

	$self->AddSeparator;





	# Undo/Redo Support
	$self->AddTool(
		Wx::wxID_UNDO, '',
		Padre::Wx::tango( 'actions', 'edit-undo.png' ),
		Wx::gettext('Undo'),
	);

	$self->AddTool(
		Wx::wxID_REDO, '',
		Padre::Wx::tango( 'actions', 'edit-redo.png' ),
		Wx::gettext('Redo'),
	);

	$self->AddSeparator;





	# Cut/Copy/Paste
	$self->AddTool(
		Wx::wxID_CUT, '',
		Padre::Wx::tango( 'actions', 'edit-cut.png' ),
		Wx::gettext('Cut'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_CUT,
		sub {
			Padre::Current->editor->Cut
		},
	);

	$self->AddTool(
		Wx::wxID_COPY,  '',
		Padre::Wx::tango( 'actions', 'edit-copy.png' ),
		Wx::gettext('Copy'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_COPY,
		sub {
			Padre::Current->editor->Copy
		},
	);

	$self->AddTool(
		Wx::wxID_PASTE, '',
		Padre::Wx::tango( 'actions', 'edit-paste.png' ),
		Wx::gettext('Paste'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_PASTE,
		sub { 
			my $editor = Padre::Current->editor or return;
			$editor->Paste;
		},
	);

	$self->AddTool(
		Wx::wxID_SELECTALL, '',
		Padre::Wx::tango( 'actions', 'edit-select-all.png' ),
		Wx::gettext('Select all'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_SELECTALL,
		sub { \&Padre::Wx::Editor::text_select_all(@_) },
	);

	$self->AddSeparator;





	# Task status
       
	# There can be three statuses:
	# idle, running (light load), and load (high load).
	# They'll be switched on demand by update_task_status()
	# Here, we just set up a default state of idle
	$self->{task_status_idle_id}    = Wx::NewId;
	$self->{task_status_running_id} = Wx::NewId;
	$self->{task_status_load_id}    = Wx::NewId;

	$self->AddTool(
		$self->{task_status_idle_id}, '',
		Padre::Wx::icon( 'tasks-idle.png' ),
		Wx::gettext('Background Tasks are idle'),
	);

	# Remember the id of the current status for update checks
	$self->{task_status_id} = $self->{task_status_idle_id};

	# Remember the position of the status icon for replacement
	$self->{task_status_tool_pos} = $self->GetToolPos($self->{task_status_idle_id});

	return $self;
}

# checks whether a Task status icon update is in order
# and if so, changes the icon to one of the other states
sub update_task_status {
	my $self    = shift;
	my $manager = Padre->ide->task_manager;

	# Still in editor-startup phase, default to idle
	return $self->set_task_status_idle unless defined $manager;

	my $running = $manager->running_tasks;
	return $self->set_task_status_idle unless $running;

	my $max_workers = $manager->max_no_workers;
	my $jobs = $manager->task_queue->pending + $running;
	# High load is defined as the state when the number of
	# running and pending jobs is larger that twice the
	# MAXIMUM number of workers
	if ($jobs > 2 * $max_workers) {
		return $self->set_task_status_load;
	}
	return $self->set_task_status_running;
}

sub set_task_status_idle {
	my $self = shift;
	my $id   = $self->{task_status_idle_id};
	return if $self->{task_status_id} == $id;

	my $bitmap = Padre::Wx::icon( 'tasks-idle.png' );
	my $text   = Wx::gettext('Background Tasks are idle');
	return $self->_set_task_status($id, $bitmap, $text);
}

sub set_task_status_running {
	my $self = shift;
	my $id   = $self->{task_status_running_id};
	return if $self->{task_status_id} == $id;

	my $bitmap = Padre::Wx::icon( 'tasks-running.png' );
	my $text   = Wx::gettext('Background Tasks are running');
	return $self->_set_task_status($id, $bitmap, $text);
}

sub set_task_status_load {
	my $self = shift;
	my $id   = $self->{task_status_load_id};
	return if $self->{task_status_id} == $id;

	my $bitmap = Padre::Wx::icon( 'tasks-load.png' );
	my $text   = Wx::gettext('Background Tasks are running with high load');
	return $self->_set_task_status($id, $bitmap, $text);
}

# Replaces the actual Task status Tool in the ToolBar.
# Starting with wx 2.9, this can be removed in favour
# of simply updating the bitmap.
sub _set_task_status {
	my $self   = shift;
	my $id     = shift;
	my $bitmap = shift;
	my $text   = shift;

	$self->{task_status_id} = $id;
	$self->DeleteToolByPos($self->{task_status_tool_pos});
	$self->InsertTool(
		$self->{task_status_tool_pos},
		$id, '',
		$bitmap,
		Wx::wxNullBitmap,
		Wx::wxITEM_NORMAL(),
		$text,
	);
	$self->Realize;

	return 1;
}

sub refresh {
	my $self      = shift;
	my $current   = _CURRENT(@_);
	my $editor    = $current->editor;
	my $document  = $current->document;
	my $text      = $current->text;
	my $selection = (defined $text and $text ne '') ? 1 : 0;

	$self->EnableTool( Wx::wxID_SAVE,      ( $document and $document->is_modified ? 1 : 0 ));
	$self->EnableTool( Wx::wxID_CLOSE,     ( $editor ? 1 : 0 ));
	$self->EnableTool( Wx::wxID_UNDO,      ( $editor and $editor->CanUndo  ));
	$self->EnableTool( Wx::wxID_REDO,      ( $editor and $editor->CanRedo  ));
	$self->EnableTool( Wx::wxID_CUT,       ( $selection ));
	$self->EnableTool( Wx::wxID_COPY,      ( $selection ));
	$self->EnableTool( Wx::wxID_PASTE,     ( $editor and $editor->CanPaste ));
	$self->EnableTool( Wx::wxID_SELECTALL, ( $editor ? 1 : 0 ));

	$self->update_task_status();

	return;
}





#####################################################################
# Toolbar 2.0 Experimentation

# NOTE: This is just here so Adam doesn't lose it accidentally.
#       Please don't play around with it (yet).
our %TOOLS = (
	'Padre.new' => {
		
	},
);

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

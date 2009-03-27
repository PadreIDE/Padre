package Padre::Wx::ToolBar;

use 5.008;
use strict;
use warnings;
use Padre::Current    qw{_CURRENT};
use Padre::Wx         ();
use Padre::Wx::Editor ();
use Padre::Wx::Icon   ();

our $VERSION = '0.30';
use base 'Wx::ToolBar';

sub new {
	my $class = shift;
	my $main  = shift;

	# Prepare the style
	my $style = Wx::wxTB_HORIZONTAL
		| Wx::wxTB_FLAT
		| Wx::wxTB_NO_TOOLTIPS
		| Wx::wxTB_NODIVIDER
		| Wx::wxBORDER_NONE;
	unless ( $main->config->main_lockinterface ) {
		$style = $style | Wx::wxTB_DOCKABLE;
	}

	# Create the parent Wx object
	my $self = $class->SUPER::new( $main, -1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		$style,
		5050,
	);

	# Default icon size is 16x15 for Wx, to use the 16x16 GPL
	# icon sets we need to be SLIGHTLY bigger.
	$self->SetToolBitmapSize(
		Wx::Size->new( 16, 16 )
	);

	# Populate the toolbar
	$self->add_tool(
		id    => Wx::wxID_NEW,
		icon  => 'actions/document-new',
		short => Wx::gettext('New File'),
		event => sub {
			$_[0]->on_new;
		},
	);
	$self->add_tool(
		id    => Wx::wxID_OPEN,
		icon  => 'actions/document-open',
		short => Wx::gettext('Open File'),
	);
	$self->add_tool(
		id    => Wx::wxID_SAVE,
		icon  => 'actions/document-save',
		short => Wx::gettext('Save File'),
	);
	$self->add_tool(
		id    => Wx::wxID_CLOSE,
		icon  => 'actions/x-document-close',
		short => Wx::gettext('Close File'),
		event => sub {
			$_[0]->on_close($_[1]);
		},
	);

	$self->AddSeparator;





	# Undo/Redo Support
	$self->AddTool(
		Wx::wxID_UNDO, '',
		Padre::Wx::Icon::find('actions/edit-undo'),
		Wx::gettext('Undo'),
	);

	$self->AddTool(
		Wx::wxID_REDO, '',
		Padre::Wx::Icon::find('actions/edit-redo'),
		Wx::gettext('Redo'),
	);

	$self->AddSeparator;





	# Cut/Copy/Paste
	$self->AddTool(
		Wx::wxID_CUT, '',
		Padre::Wx::Icon::find('actions/edit-cut'),
		Wx::gettext('Cut'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_CUT,
		sub {
			Padre::Current->editor->Cut;
		},
	);

	$self->AddTool(
		Wx::wxID_COPY,  '',
		Padre::Wx::Icon::find('actions/edit-copy'),
		Wx::gettext('Copy'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_COPY,
		sub {
			Padre::Current->editor->Copy;
		},
	);

	$self->AddTool(
		Wx::wxID_PASTE, '',
		Padre::Wx::Icon::find('actions/edit-paste'),
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
		Padre::Wx::Icon::find('actions/edit-select-all'),
		Wx::gettext('Select all'),
	);
	Wx::Event::EVT_TOOL(
		$main,
		Wx::wxID_SELECTALL,
		sub {
			\&Padre::Wx::Editor::text_select_all(@_);
		},
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
		Padre::Wx::Icon::find('status/padre-tasks-idle'),
		Wx::gettext('Background Tasks are idle'),
	);
	
	# connect the dumping of the running task map to the output
	# window to each one of the tool states
	foreach my $id (map {$self->{"task_status_${_}_id"}} qw(idle running load)) {
		Wx::Event::EVT_TOOL(
			$main, $id, \&Padre::TaskManager::on_dump_running_tasks,
		);
	}
	
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

	my $bitmap = Padre::Wx::Icon::find('status/padre-tasks-idle');
	my $text   = Wx::gettext('Background Tasks are idle');
	return $self->_set_task_status($id, $bitmap, $text);
}

sub set_task_status_running {
	my $self = shift;
	my $id   = $self->{task_status_running_id};
	return if $self->{task_status_id} == $id;

	my $bitmap = Padre::Wx::Icon::find('status/padre-tasks-running');
	my $text   = Wx::gettext('Background Tasks are running');
	return $self->_set_task_status($id, $bitmap, $text);
}

sub set_task_status_load {
	my $self = shift;
	my $id   = $self->{task_status_load_id};
	return if $self->{task_status_id} == $id;

	my $bitmap = Padre::Wx::Icon::find('status/padre-tasks-load');
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
		Wx::wxITEM_NORMAL,
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

	$self->update_task_status;

	return;
}





#####################################################################
# Toolbar 2.0

sub add_tool {
	my $self  = shift;
	my %param = @_;
	my $id    = $param{id} || -1;

	# Create the tool
	$self->AddTool(
		$id, '',
		Padre::Wx::Icon::find($param{icon}),
		$param{short},
	);

	# Add the optional event hook
	if ( defined $param{event} ) {
		Wx::Event::EVT_TOOL(
			$self->GetParent,
			$id,
			$param{event},
		);
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

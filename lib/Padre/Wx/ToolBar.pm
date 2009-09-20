package Padre::Wx::ToolBar;

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx         ();
use Padre::Wx::Icon   ();
use Padre::Wx::Editor ();
use Padre::Constant();

our $VERSION = '0.46';
our @ISA     = 'Wx::ToolBar';

# NOTE: Something is wrong with dockable toolbars on Windows
#       so disable them for now.
use constant DOCKABLE => !Padre::Constant::WXWIN32;

sub new {
	my $class = shift;
	my $main  = shift;

	# Prepare the style
	my $style = Wx::wxTB_HORIZONTAL | Wx::wxTB_FLAT | Wx::wxTB_NODIVIDER | Wx::wxBORDER_NONE;
	if ( DOCKABLE and not $main->config->main_lockinterface ) {
		$style = $style | Wx::wxTB_DOCKABLE;
	}

	# Create the parent Wx object
	my $self = $class->SUPER::new(
		$main, -1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		$style,
		5050,
	);

	# Default icon size is 16x15 for Wx, to use the 16x16 GPL
	# icon sets we need to be SLIGHTLY bigger.
	$self->SetToolBitmapSize( Wx::Size->new( 16, 16 ) );

	# toolbar id sequence generator
	# Toolbar likes only unique values. Do otherwise on your own risk.
	$self->{next_id} = 10000;

	# Populate the toolbar
	$self->add_tool_item(
		action => 'file.new',
		icon   => 'actions/document-new',
	);

	$self->add_tool_item(
		action => 'file.open',
		icon   => 'actions/document-open',
	);

	$self->{save} = $self->add_tool_item(
		action => 'file.save',
		icon   => 'actions/document-save',
	);

	$self->{save_as} = $self->add_tool_item(
		action => 'file.save_as',
		icon   => 'actions/document-save-as',
	);

	$self->{save_all} = $self->add_tool_item(
		action => 'file.save_all',
		icon   => 'actions/stock_data-save',
	);

	$self->{close} = $self->add_tool_item(
		action => 'file.close',
		icon   => 'actions/x-document-close',
	);

	$self->AddSeparator;
	$self->{open_example} = $self->add_tool_item(
		action => 'file.open_example',
		icon   => 'stock/generic/stock_example',
	);

	# Undo/Redo Support
	$self->AddSeparator;

	$self->{undo} = $self->add_tool_item(
		action => 'edit.undo',
		icon   => 'actions/edit-undo',
	);

	$self->{redo} = $self->add_tool_item(
		action => 'edit.redo',
		icon   => 'actions/edit-redo',
	);

	# Cut/Copy/Paste
	$self->AddSeparator;

	$self->{cut} = $self->add_tool_item(
		action => 'edit.cut',
		icon   => 'actions/edit-cut',
	);

	$self->{copy} = $self->add_tool_item(
		action => 'edit.copy',
		icon   => 'actions/edit-copy',
	);

	$self->{paste} = $self->add_tool_item(
		action => 'edit.paste',
		icon   => 'actions/edit-paste',
	);

	$self->{select_all} = $self->add_tool_item(
		action => 'edit.select_all',
		icon   => 'actions/edit-select-all',
	);

	# find and replace
	$self->AddSeparator;

	$self->{find} = $self->add_tool_item(
		action => 'search.find',
		icon   => 'actions/edit-find',
	);

	$self->{replace} = $self->add_tool_item(
		action => 'search.replace',
		icon   => 'actions/edit-find-replace',
	);

	# Document Transforms
	$self->AddSeparator;

	$self->{comment_toggle} = $self->add_tool_item(
		action => 'edit.comment_toggle',
		icon   => 'actions/toggle-comments',
	);

	$self->AddSeparator;

	$self->{doc_stat} = $self->add_tool_item(
		action => 'file.doc_stat',
		icon   => 'actions/document-properties',
	);

	$self->AddSeparator;

	$self->{open_resource} = $self->add_tool_item(
		action => 'search.open_resource',
		icon   => 'places/folder-saved-search',
	);

	$self->{quick_menu_access} = $self->add_tool_item(
		action => 'search.quick_menu_access',
		icon   => 'status/info',
	);

	$self->AddSeparator;

	$self->{quick_menu_access} = $self->add_tool_item(
		action => 'run.run_document',
		icon   => 'actions/player_play',
	);

	$self->{quick_menu_access} = $self->add_tool_item(
		action => 'run.stop',
		icon   => 'actions/stop',
	);

	return $self;
}

#
# Add a tool item to the toolbar re-using Padre menu action name
#
sub add_tool_item {
	my ( $self, %args ) = @_;

	my $actions = Padre::ide->actions;

	my $action = $actions->{ $args{action} };
	die( "No action with the name " . $args{name} )
		unless $action;

	# the ID code should be unique otherwise it can break the event system.
	# If set to -1 such as in the default call below, it will override
	# any previous item with that id.
	my $id = $self->{next_id}++;

	# Create the tool
	$self->AddTool(
		$id, '',
		Padre::Wx::Icon::find( $args{icon} ),
		$action->label_text,
	);

	# Add the optional event hook
	Wx::Event::EVT_TOOL(
		$self->GetParent,
		$id,
		$action->menu_event,
	);

	return $id;
}

sub refresh {
	my $self      = shift;
	my $current   = _CURRENT(@_);
	my $editor    = $current->editor;
	my $document  = $current->document;
	my $text      = $current->text;
	my $selection = ( defined $text and $text ne '' ) ? 1 : 0;

	$self->EnableTool( $self->{save}, ( $document and $document->is_modified ? 1 : 0 ) );
	$self->EnableTool( $self->{save_as}, ($document) );

	# trying out the Comment Code method here
	$self->EnableTool( $self->{save_all}, ($document) ); # Save All

	$self->EnableTool( $self->{close}, ( $editor ? 1 : 0 ) );
	$self->EnableTool( $self->{undo},  ( $editor and $editor->CanUndo ) );
	$self->EnableTool( $self->{redo},  ( $editor and $editor->CanRedo ) );
	$self->EnableTool( $self->{cut},   ($selection) );
	$self->EnableTool( $self->{copy},  ($selection) );
	$self->EnableTool( $self->{paste}, ( $editor and $editor->CanPaste ) );
	$self->EnableTool( $self->{select_all},     ( $editor   ? 1 : 0 ) );
	$self->EnableTool( $self->{find},           ( $editor   ? 1 : 0 ) );
	$self->EnableTool( $self->{replace},        ( $editor   ? 1 : 0 ) );
	$self->EnableTool( $self->{comment_toggle}, ( $document ? 1 : 0 ) );
	$self->EnableTool( $self->{doc_stat},       ( $editor   ? 1 : 0 ) );

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

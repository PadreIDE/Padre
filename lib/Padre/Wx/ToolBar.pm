package Padre::Wx::ToolBar;

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx         ();
use Padre::Wx::Icon   ();
use Padre::Wx::Editor ();

our $VERSION = '0.41';
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
		id    => Wx::wxID_SAVEAS,
		icon  => 'actions/document-save-as',
		short => Wx::gettext('Save as...'),
	);

	$self->add_tool(
		id    => 1000,                     # I don't like these hard set ID's for Wx.
		icon  => 'actions/stock_data-save',
		short => Wx::gettext('Save All'),
		event => sub {
			Padre::Wx::Main::on_save_all(@_);
		},
	);

	$self->add_tool(
		id    => Wx::wxID_CLOSE,
		icon  => 'actions/x-document-close',
		short => Wx::gettext('Close File'),
		event => sub {
			$_[0]->on_close( $_[1] );
		},
	);

	# Undo/Redo Support
	$self->AddSeparator;

	$self->add_tool(
		id    => Wx::wxID_UNDO,
		icon  => 'actions/edit-undo',
		short => Wx::gettext('Undo'),
	);

	$self->add_tool(
		id    => Wx::wxID_REDO,
		icon  => 'actions/edit-redo',
		short => Wx::gettext('Redo'),
	);

	# Cut/Copy/Paste
	$self->AddSeparator;

	$self->add_tool(
		id    => Wx::wxID_CUT,
		icon  => 'actions/edit-cut',
		short => Wx::gettext('Cut'),
		event => sub {
			Wx::Window::FindFocus->Cut;
		},
	);

	$self->add_tool(
		id    => Wx::wxID_COPY,
		icon  => 'actions/edit-copy',
		short => Wx::gettext('Copy'),
		event => sub {
			Wx::Window::FindFocus->Copy;
		},
	);

	$self->add_tool(
		id    => Wx::wxID_PASTE,
		icon  => 'actions/edit-paste',
		short => Wx::gettext('Paste'),
		event => sub {
			my $editor = Wx::Window::FindFocus() or return;
			$editor->Paste;
		},
	);

	$self->add_tool(
		id    => Wx::wxID_SELECTALL,
		icon  => 'actions/edit-select-all',
		short => Wx::gettext('Select All'),
		event => sub {
			Wx::Window::FindFocus->SelectAll();
		},
	);

	# find and replace
	$self->AddSeparator;

	$self->add_tool(
		id    => Wx::wxID_FIND,
		icon  => 'actions/edit-find',
		short => Wx::gettext('Find'),
	);

	$self->add_tool(
		id    => Wx::wxID_REPLACE,
		icon  => 'actions/edit-find-replace',
		short => Wx::gettext('Find and Replace'),
	);

	# Document Transforms
	$self->AddSeparator;

	$self->add_tool(
		id    => 999,
		icon  => 'actions/toggle-comments',
		short => Wx::gettext('Toggle Comments'),
		event => sub {
			Padre::Wx::Main::on_comment_toggle_block(@_);
		},
	);

	$self->AddSeparator;

	$self->add_tool(
		id    => 1001,
		icon  => 'actions/document-properties',
		short => Wx::gettext('Document Stats'),
		event => sub {
			Padre::Wx::Main::on_doc_stats(@_);
		},
	);

	return $self;
}

sub refresh {
	my $self      = shift;
	my $current   = _CURRENT(@_);
	my $editor    = $current->editor;
	my $document  = $current->document;
	my $text      = $current->text;
	my $selection = ( defined $text and $text ne '' ) ? 1 : 0;

	$self->EnableTool( Wx::wxID_SAVE, ( $document and $document->is_modified ? 1 : 0 ) );
	$self->EnableTool( Wx::wxID_SAVEAS, ($document) );

	# trying out the Comment Code method here
	$self->EnableTool( 1000, ($document) ); # Save All

	$self->EnableTool( Wx::wxID_CLOSE, ( $editor ? 1 : 0 ) );
	$self->EnableTool( Wx::wxID_UNDO,  ( $editor and $editor->CanUndo ) );
	$self->EnableTool( Wx::wxID_REDO,  ( $editor and $editor->CanRedo ) );
	$self->EnableTool( Wx::wxID_CUT,   ($selection) );
	$self->EnableTool( Wx::wxID_COPY,  ($selection) );
	$self->EnableTool( Wx::wxID_PASTE, ( $editor and $editor->CanPaste ) );
	$self->EnableTool( Wx::wxID_SELECTALL, ( $editor ? 1 : 0 ) );
	$self->EnableTool( Wx::wxID_FIND,      ( $editor ? 1 : 0 ) );
	$self->EnableTool( Wx::wxID_REPLACE,   ( $editor ? 1 : 0 ) );
	$self->EnableTool( 999,  ( $document ? 1 : 0 ) );
	$self->EnableTool( 1001, ( $editor   ? 1 : 0 ) );

	return;
}

#####################################################################
# Toolbar 2.0

sub add_tool {
	my $self  = shift;
	my %param = @_;

	# TODO: the ID code must be unique. If set to -1 such as in
	# the default call below, it will override any previous item
	# with that id.
	my $id = $param{id} || -1;

	# Create the tool
	$self->AddTool(
		$id, '',
		Padre::Wx::Icon::find( $param{icon} ),
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

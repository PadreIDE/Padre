package Padre::Wx::Directory::TreeCtrl;

use 5.008;
use strict;
use warnings;
use File::Path                 ();
use File::Spec                 ();
use Padre::Constant            ();
use Padre::Wx::TreeCtrl        ();
use Padre::Wx::Role::Main      ();
use Padre::Wx::Directory::Path ();

our $VERSION = '0.80';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Padre::Wx::TreeCtrl
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $panel = shift;
	my $self  = $class->SUPER::new(
		$panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_FULL_ROW_HIGHLIGHT | Wx::wxTR_HAS_BUTTONS
			| Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE | Wx::wxCLIP_CHILDREN
	);

	# Create the image list
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{images} = {
		upper => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_DIR_UP',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		folder => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_FOLDER',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		package => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_NORMAL_FILE',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
	};
	$self->AssignImageList($images);

	# Set up the events
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		sub {
			shift->on_tree_item_activated(@_);
		}
	);

	Wx::Event::EVT_TREE_ITEM_MENU(
		$self, $self,
		sub {
			shift->on_tree_item_menu(@_);
		},
	);

	Wx::Event::EVT_KEY_UP( $self, \&key_up );

	# Set up the root
	$self->AddRoot( Wx::gettext('Directory'), -1, -1 );

	# Ident to sub nodes
	$self->SetIndent(10);

	return $self;
}


######################################################################
# Event Handlers

# Action that must be executaded when a item is activated
# Called when the item is actived
sub on_tree_item_activated {
	my $self   = shift;
	my $item   = shift->GetItem;
	my $data   = $self->GetPlData($item);
	my $parent = $self->GetParent;

	# If a folder, toggle the expand/collanse state
	if ( $data->type == 1 ) {
		$self->Toggle($item);
		return;
	}

	# Open the selected file
	my $current = $self->current;
	my $main    = $current->main;
	my $file    = File::Spec->catfile( $parent->root, $data->path );

	$main->setup_editor($file);
	return;
}

sub key_up {
	my $self  = shift;
	my $event = shift;

	my $mod = $event->GetModifiers || 0;
	my $code = $event->GetKeyCode;

	# see Padre::Wx::Main::key_up
	$mod = $mod & ( Wx::wxMOD_ALT() + Wx::wxMOD_CMD() + Wx::wxMOD_SHIFT() );

	my $current = $self->current;
	my $main    = $current->main;
	my $project = $current->project;

	my $item_id = $self->GetSelection;
	my $data    = $self->GetPlData($item_id);

	return if not $data;

	my $file = File::Spec->catfile( $project->root, $data->path );

	if ( $code == Wx::WXK_DELETE ) {
		$self->_delete_file($file);
	}

	$event->Skip;
	return;

}

sub _create_directory {
	my $self = shift;
	my $file = shift;

	my $main = $self->main;
	my $dir_name =
		$main->prompt( 'Please type in the name of the new directory', 'Create Directory', 'CREATE_DIRECTORY' );
	return if ( !defined($dir_name) || $dir_name =~ /^\s*$/ );

	require File::Spec;
	require File::Basename;
	my $path = File::Basename::dirname($file);
	if ( mkdir File::Spec->catdir( $path, $dir_name ) ) {
		$self->GetParent->browse;
	} else {
		$main->error( sprintf( Wx::gettext(q(Could not create: '%s': %s)), $path, $! ) );
	}
	return;
}

sub _delete_file {
	my $self = shift;
	my $file = shift;

	my $main = $self->main;

	return if not $main->yes_no( sprintf( Wx::gettext('Really delete the file "%s"?'), $file ) );

	my $error_ref;
	File::Path::remove_tree( $file, { error => \$error_ref } );

	if ( scalar @$error_ref == 0 ) {
		$self->GetParent->browse;
	} else {
		$main->error( sprintf Wx::gettext(q(Could not delete: '%s': %s)), $file, ( join ' ', @$error_ref ) );
	}
}

# Shows up a context menu above an item with its controls
# the file if don't.
# Called when a item context menu is requested.
sub on_tree_item_menu {
	my $self  = shift;
	my $event = shift;
	my $item  = $event->GetItem;
	my $data  = $self->GetPlData($item);

	# Only show the context menu for files (for now)
	if ( $data->type == Padre::Wx::Directory::Path::DIRECTORY ) {
		return;
	}

	# Generate the context menu for this file
	my $menu = Wx::Menu->new;
	my $file = File::Spec->catfile(
		$self->GetParent->root,
		$data->path,
	);

	# The default action is the same as when it is double-clicked
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext('Open File') ),
		sub {
			shift->on_tree_item_activated($event);
		}
	);

	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext('Open in File Browser') ),
		sub {
			shift->main->on_open_in_file_browser($file);
		}
	);

	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext('Delete File') ),
		sub {
			my $self = shift;
			$self->_delete_file($file);
		}
	);

	$menu->AppendSeparator;

	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext('Create Directory') ),
		sub {
			my $self = shift;
			$self->_create_directory($file);
		}
	);

	$menu->AppendSeparator;

	# Updates the directory listing
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext('Refresh') ),
		sub {
			shift->GetParent->rebrowse;
		}
	);

	# Pops up the context menu
	$self->PopupMenu(
		$menu,
		$event->GetPoint->x,
		$event->GetPoint->y,
	);

	return;
}



######################################################################
# General Methods

# Scan the tree to find all directory nodes which are expanded.
# Returns a reference to a HASH of ->unix path strings.
sub expanded {
	my $self  = shift;
	my $items = $self->GetExpandedPlData;
	my %hash  = map { $_->unix => 1 } @$items;
	return \%hash;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

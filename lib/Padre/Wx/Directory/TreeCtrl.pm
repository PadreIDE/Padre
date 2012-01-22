package Padre::Wx::Directory::TreeCtrl;

use 5.008;
use strict;
use warnings;
use File::Path                 ();
use File::Spec                 ();
use File::Basename             ();
use Padre::Util                ('_T');
use Padre::Constant            ();
use Padre::Wx                  ();
use Padre::Wx::TreeCtrl        ();
use Padre::Wx::Role::Main      ();
use Padre::Wx::Directory::Path ();

our $VERSION = '0.94';
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
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TR_HIDE_ROOT | Wx::TR_SINGLE | Wx::TR_FULL_ROW_HIGHLIGHT | Wx::TR_HAS_BUTTONS | Wx::TR_LINES_AT_ROOT
			| Wx::BORDER_NONE | Wx::CLIP_CHILDREN
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

	Wx::Event::EVT_KEY_UP(
		$self,
		sub {
			shift->key_up(@_);
		},
	);

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

	# If a folder, toggle the expand/collapse state
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
	my $mod   = $event->GetModifiers || 0;
	my $code  = $event->GetKeyCode;

	# see Padre::Wx::Main::key_up
	$mod = $mod & ( Wx::MOD_ALT + Wx::MOD_CMD + Wx::MOD_SHIFT );

	my $current = $self->current;
	my $main    = $current->main;
	my $project = $current->project;
	my $item_id = $self->GetSelection;
	my $data    = $self->GetPlData($item_id) or return;
	my $file    = File::Spec->catfile( $project->root, $data->path );

	if ( $code == Wx::K_DELETE ) {
		$self->delete_file($file);
	}

	$event->Skip;
	return;
}

sub rename_file {
	my $self = shift;
	my $main = $self->main;
	my $file = shift;
	my $old  = File::Basename::basename($file);
	my $new =
		-d $file
		? $main->simple_prompt(
		Wx::gettext('Please type in the new name of the directory'),
		Wx::gettext('Rename directory'), $old
		)
		: $main->simple_prompt(
		Wx::gettext('Please type in the new name of the file'),
		Wx::gettext('Rename file'), $old
		);
	return if ( !defined($new) || $new =~ /^\s*$/ );

	my $path = File::Basename::dirname($file);
	if ( rename $file, File::Spec->catdir( $path, $new ) ) {
		$self->GetParent->rebrowse;
	} else {
		$main->error( sprintf( Wx::gettext(q(Could not rename: '%s' to '%s': %s)), $file, $path, $! ) );
	}
	return;
}

sub create_directory {
	my $self = shift;
	my $path = shift;
	my $main = $self->main;
	my $name = $main->prompt(
		'Please type in the name of the new directory',
		'Create Directory',
		'CREATE_DIRECTORY',
	);
	return if ( !defined($name) || $name =~ /^\s*$/ );

	unless ( mkdir File::Spec->catdir( $path, $name ) ) {
		$main->error(
			sprintf(
				Wx::gettext(q(Could not create: '%s': %s)),
				$path,
				$!,
			)
		);
		return;
	}

	#
	$self->GetParent->rebrowse;

	return;
}

sub delete_file {
	my $self = shift;
	my $file = shift;
	my $main = $self->main;
	my $yes  = $main->yes_no( sprintf( Wx::gettext('Really delete the file "%s"?'), $file ) );
	return unless $yes;

	# The background task Padre::Task::File already exists specifically
	# for this kind of thing. Upgrade to use this in future.
	my $error;
	File::Path::remove_tree( $file, { error => \$error } );

	if ( scalar @$error == 0 ) {

		# This might be overkill a bit, but it works
		$self->GetParent->rebrowse;
	} else {
		$main->error( sprintf Wx::gettext(q(Could not delete: '%s': %s)), $file, ( join ' ', @$error ) );
	}
}

# Shows up a context menu above an item with its controls
# the file if don't.
# Called when a item context menu is requested.
sub on_tree_item_menu {
	my $self  = shift;
	my $event = shift;
	my $item  = $event->GetItem;
	my $data  = $self->GetPlData($item) or return;

	# Generate the context menu for this file or directory
	my $menu = Wx::Menu->new;
	my $file = File::Spec->catfile(
		$self->GetParent->root,
		$data->path,
	);

	if ( $data->type == Padre::Wx::Directory::Path::DIRECTORY ) {
		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Open in File Browser') ),
			),
			sub {
				shift->main->on_open_in_file_browser($file);
			}
		);

		$menu->AppendSeparator;

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Delete Directory') ),
			),
			sub {
				shift->delete_file($file);
			}
		);

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Rename Directory') ),
			),
			sub {
				shift->rename_file($file);
			}
		);

		$menu->AppendSeparator;

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Create Directory') ),
			),
			sub {
				shift->create_directory($file);
			}
		);

	} else {

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
			$menu->Append(
				-1,
				$self->getlabel( _T('Open in File Browser') ),
			),
			sub {
				shift->main->on_open_in_file_browser($file);
			}
		);

		$menu->AppendSeparator;

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Delete File') ),
			),
			sub {
				shift->delete_file($file);
			}
		);

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Rename File') ),
			),
			sub {
				shift->rename_file($file);
			}
		);

		$menu->AppendSeparator;

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append(
				-1,
				$self->getlabel( _T('Create Directory') ),
			),
			sub {
				my $dir = File::Basename::dirname($file);
				shift->create_directory($dir);
			}
		);
	}

	# Pops up the context menu
	$self->PopupMenu(
		$menu,
		$event->GetPoint->x,
		$event->GetPoint->y,
	);

	return;
}





######################################################################
# Localisation

my %WIN32 = (
	'Open in File Browser' => _T('Explore...'),
	'Delete Directory'     => _T('Delete'),
	'Rename Directory'     => _T('Rename'),
	'Delete File'          => _T('Delete'),
	'Rename File'          => _T('Rename'),
	'Create Directory'     => _T('New Folder'),
);

# Improved gettext for the directory tree, which not only applies localisation
# for languages, but also maps to operating system terms for the appropriate
# actions.
sub getlabel {
	my $self  = shift;
	my $label = shift;
	if ( Padre::Constant::WIN32 and $WIN32{$label} ) {
		$label = $WIN32{$label};
	}
	return Wx::gettext($label);
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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Directory::TreeCtrl;

use strict;
use warnings;
use File::Copy;
use File::Spec     ();
use File::Basename ();
use Params::Util qw{_INSTANCE};
use Padre::Current ();
use Padre::Util    ();
use Padre::Wx      ();

our $VERSION = '0.42';
our @ISA     = 'Wx::TreeCtrl';

use constant IS_MAC => !!( $^O eq 'darwin' );
use constant IS_WIN32 => !!( $^O =~ /^MSWin/ or $^O eq 'cygwin' );

# Creates a new Directory Browser object
sub new {
	my $class = shift;
	my $panel = shift;
	my $self  = $class->SUPER::new(
		$panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_FULL_ROW_HIGHLIGHT | Wx::wxTR_HAS_BUTTONS
			| Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE
	);

	# Files that must be skipped
	$self->{CACHED} = {};

	# Selected item of each project
	$self->{current_item} = {};

	# Create the image list
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{file_types} = {
		upper => $images->Add(
			Wx::ArtProvider::GetBitmap( 'wxART_GO_DIR_UP', 'wxART_OTHER_C', [ 16, 16 ] ),
		),
		folder => $images->Add(
			Wx::ArtProvider::GetBitmap( 'wxART_FOLDER', 'wxART_OTHER_C', [ 16, 16 ] ),
		),
		package => $images->Add(
			Wx::ArtProvider::GetBitmap( 'wxART_NORMAL_FILE', 'wxART_OTHER_C', [ 16, 16 ] ),
		),
	};
	$self->AssignImageList($images);

	# Set up the events
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		\&_on_tree_item_activated
	);

	Wx::Event::EVT_SET_FOCUS(
		$self,
		sub {
			$_[0]->parent->refresh;
		},
	);

	Wx::Event::EVT_TREE_ITEM_MENU(
		$self, $self,
		\&_on_tree_item_menu,
	);

	Wx::Event::EVT_TREE_SEL_CHANGED(
		$self, $self,
		\&_on_tree_sel_changed,
	);

	Wx::Event::EVT_TREE_ITEM_EXPANDING(
		$self, $self,
		\&_on_tree_item_expanding,
	);

	Wx::Event::EVT_TREE_ITEM_COLLAPSING(
		$self, $self,
		\&_on_tree_item_collapsing,
	);

	Wx::Event::EVT_TREE_END_LABEL_EDIT(
		$self, $self,
		\&_on_tree_end_label_edit,
	);

	Wx::Event::EVT_TREE_BEGIN_DRAG(
		$self, $self,
		\&_on_tree_begin_drag,
	);

	Wx::Event::EVT_TREE_END_DRAG(
		$self, $self,
		\&_on_tree_end_drag,
	);

	# Set up the root
	my $root = $self->AddRoot(
		Wx::gettext('Directory'),
		-1, -1,
		Wx::TreeItemData->new(
			{   dir  => '',
				name => '',
				type => 'folder',
			}
		),
	);

	# Ident to sub nodes
	$self->SetIndent(10);

	return $self;
}

# Returns the Directory Panel object reference
sub parent {
	$_[0]->GetParent;
}

# Traverse to the search widget
sub search {
	$_[0]->GetParent->search;
}

# Returns the main object reference
sub main {
	$_[0]->GetParent->main;
}

sub current {
	Padre::Current->new( main => $_[0]->main );
}

# Updates the gui if needed
sub refresh {
	my $self   = shift;
	my $parent = $self->parent;
	my $search = $parent->search;

	# Gets the last and current actived projects
	my $project_dir  = $parent->project_dir;
	my $previous_dir = $parent->previous_dir;

	# Gets Root node
	my $root = $self->GetRootItem;

	# Lock the gui here to make the updates look slicker
	# The locker holds the gui freeze until the update is done.
	my $locker = $self->main->freezer;

	# If the project have changed or the project root folder updates or
	# the search is not in use anymore (was just used)
	if (   ( defined($project_dir) and ( not defined($previous_dir) or $previous_dir ne $project_dir ) )
		or $self->_updated_dir($project_dir)
		or $search->{just_used}->{$project_dir}
		or $parent->{mode_change} )
	{

		# Updates Root node data
		$self->_update_root_data;

		# Returns if Search is in use
		return if $search->{in_use}->{$project_dir};

		$self->_list_dir($root);
		$self->_append_upper if $parent->mode eq 'navigate';
		delete $search->{just_used}->{$project_dir};
		delete $parent->{mode_change};
	}

	# Checks expanded sub folders and its content recursively
	_update_subdirs( $self, $root );
}

# Appends an Upper item to the node beginning
# if the current dir is not the system root
sub _append_upper {
	my $self        = shift;
	my $root        = $self->GetRootItem;
	my $project_dir = $self->parent->project_dir;

	# Gets the current directory path
	my $current_base_dir = File::Basename::dirname($project_dir);

	# Returns if project's dir is the same of it's
	# basename (usually system's root dir)
	return if $project_dir eq $current_base_dir;

	# Splits the current directory base to get its
	# name and path
	my ( $volume, $path, $name ) = File::Spec->splitpath($current_base_dir);

	# Joins the volume and path
	$path = File::Spec->catdir( $volume, $path );

	# Inserts the Upper item to the root node
	$self->InsertItem(
		$root, 0, '..',
		$self->{file_types}->{upper},
		-1,
		Wx::TreeItemData->new(
			{   name => $name,
				dir  => $path,
				type => 'upper',
			}
		)
	);
}

# Read a directory, removing the current and updir only.
# Returns the contents pre-split into directories and files so that
# we only have to do a -d file stat once and return by reference.
sub readdir {
	my $self      = shift;
	my $directory = shift;

	# Read the directory, and do the cheap name presort
	opendir( my $dh, $directory ) or return;
	my @buffer = sort { lc($a) cmp lc($b) } CORE::readdir($dh);
	closedir($dh);

	# Filter out ignored files and split out the directories
	# We don't use sort for the directory split, because it can
	# end up calling extra extra -d filesystem stats.
	my @files = ();
	my @dirs  = ();
	foreach (@buffer) {
		if ( -d File::Spec->catfile( $directory, $_ ) ) {
			next if /^\.\.?\z/;
			push @dirs, $_;
		} else {
			push @files, $_;
		}
	}

	return ( \@dirs, \@files );
}

# Updates root nodes data to the current project
# Called when turned beteween projects
sub _update_root_data {
	my $self    = shift;
	my $project = $self->parent->project_dir;

	# Splits the path to get the Root folder name and its path
	my ( $volume, $path, $name ) = File::Spec->splitpath($project);
	$path = File::Spec->catdir( $volume, $path );

	# Updates Root node data
	my $root = $self->GetRootItem;
	my $data = $self->GetPlData($root);
	$data->{dir}  = $path;
	$data->{name} = $name;
}

# Updates a node's content
# Called only if project directory changes or show/hide hidden files is
# requested
sub _list_dir {
	my $self      = shift;
	my $node      = shift;
	my $node_data = $self->GetPlData($node);
	my $path      = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	my $cached    = \%{ $self->{CACHED}->{$path} };

	# Read folder's content and cache if it had changed or isn't cached
	if ( $self->_updated_dir($path) ) {

		# Open the folder and sort its content by name and type
		my ( $dirs, $files ) = $self->readdir($path);

		# For each item, creates its CACHE data
		my @Data = map { { name => $_, dir => $path, type => 'folder', } } @$dirs;
		push @Data, map { { name => $_, dir => $path, type => 'package', } } @$files;
		$cached->{Data}   = \@Data;
		$cached->{Change} = ( stat $path )[10];
	}

	# Show or hide hidden files
	my @data = @{ $cached->{Data} };
	unless ( $cached->{ShowHidden} ) {
		my $project = $self->current->project;
		if ($project) {
			my $rule = $project->ignore_rule;
			@data = grep { $rule->() } @data;
		} else {
			@data = grep { $_->{name} !~ /^\./ } @data;
		}
	}

	# Delete node children and populates it again
	$self->DeleteChildren($node);
	foreach my $each (@data) {
		my $new_elem = $self->AppendItem(
			$node,
			$each->{name},
			$self->{file_types}->{ $each->{type} },
			-1,
			Wx::TreeItemData->new(
				{   name => $each->{name},
					dir  => $each->{dir},
					type => $each->{type},
				}
			)
		);
		if ( $each->{type} eq 'folder' ) {
			$self->SetItemHasChildren( $new_elem, 1 );
		}
	}
}

# Returns 1 if the directory has changed or is not cached and 0 if it's still  #
# the same                                                                     #
sub _updated_dir {
	my $self   = shift;
	my $dir    = shift;
	my $cached = $self->{CACHED}->{$dir};

	if (   not defined $cached
		or !$cached->{Data}
		or !$cached->{Change}
		or ( stat $dir )[10] != $cached->{Change}
		or $self->search->{just_used}->{$dir} )
	{
		return 1;
	}

	return 0;
}

# Runs thought a directory content recursively looking if each EXPANDED item   #
# has changed and updates it                                                   #
sub _update_subdirs {
	my ( $self, $root ) = @_;
	my $parent  = $self->parent;
	my $project = $parent->project_dir;

	my $cookie;

	# Loops thought the node's total children
	for my $item ( 1 .. $self->GetChildrenCount($root) ) {

		( my $node, $cookie ) = $item == 1 ? $self->GetFirstChild($root) : $self->GetNextChild( $root, $cookie );
		my $node_data = $self->GetPlData($node);
		my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

		# If the item (folder) was expanded, then expands its node and updates
		# its content recursively
		if ( defined $self->{CACHED}->{$project}->{Expanded}->{$path} ) {

			# Expands the folder node
			$self->Expand($node);

			# Updates the folder node if its content has any change
			$self->_list_dir($node) if $self->_updated_dir($path);

			# Runs thought its content
			_update_subdirs( $self, $node );
		}

		# If the item was the last selected item, selects and scrolls to it
		if (    defined $self->{current_item}->{$project}
			and $self->{current_item}->{$project} eq $path
			and delete $self->{select_item} )
		{
			$self->SelectItem($node);
		}
	}
}

# Removes '..' and its previous directories
sub _removes_double_dot {
	my ( $self, $file ) = @_;
	my @dirs = File::Spec->splitdir($file);
	for ( my $i = 0; $i < @dirs; $i++ ) {
		splice @dirs, $i - 1, 2 if $i > 0 and $dirs[$i] eq "..";
	}
	return File::Spec->catfile(@dirs);
}

# Tries to rename a file and if success returns 1 or if fails shows a
# MessageBox with the reason and returns 0
sub _rename_or_move {
	my $self     = shift;
	my $old_file = $self->_removes_double_dot(shift);
	my $new_file = $self->_removes_double_dot(shift);

	# Renames/moves the old file name to the new file name
	if ( rename $old_file, $new_file ) {

		# Sets the new file to be selected
		my $project = $self->parent->project_dir;
		$self->{current_item}->{$project} = $new_file;

		# Expands the node's parent (one level expand)
		my $cached     = $self->{CACHED};
		my $parent_dir = File::Basename::dirname($new_file);
		if ( $parent_dir =~ /^$project/ ) {
			$cached->{$project}->{Expanded}->{$parent_dir} = 1;
		}

		# If the old file was expanded, keeps the new one expanded
		if ( defined $cached->{$project}->{Expanded}->{$old_file} ) {
			$cached->{$project}->{Expanded}->{$new_file} = 1;
			delete $cached->{$project}->{Expanded}->{$old_file};
		}

		# Finds which is the OS separator character
		my $separator = File::Spec->catfile( '', '' );

		# Moves all cached data of the node and above it to the new path
		map {
			$cached->{ $new_file . ( defined $1 ? $1 : '' ) } = $cached->{$_}, delete $cached->{$_}
				if $_ =~ /^$old_file($separator.+?)?$/
		} keys %$cached;

		$self->{select_item} = 1;

		# Returns success
		return 1;
	} else {

		# Popups the error message and returns fail
		my $error_msg = $!;
		Wx::MessageBox( $error_msg, Wx::gettext('Error'), Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
		return 0;
	}
}

# Tries to copy a file and if success returns 1 or if fails shows a
# MessageBox with the reason and returns 0
sub _copy {
	my $self     = shift;
	my $old_file = $self->_removes_double_dot(shift);
	my $new_file = $self->_removes_double_dot(shift);

	# Renames/moves the old file name to the new file name
	
	if ( copy( $old_file, $new_file ) ) {

		# Sets the new file to be selected
		my $project = $self->parent->project_dir;
		$self->{current_item}->{$project} = $new_file;
		$self->{select_item} = 1;

		# Expands the node's parent (one level expand)
		my $cached     = $self->{CACHED};
		my $parent_dir = File::Basename::dirname($new_file);
		if ( $parent_dir =~ /^$project/ ) {
			$cached->{$project}->{Expanded}->{$parent_dir} = 1;
		}

		# Returns success
		return 1;
	} else {

		# Popups the error message and returns fail
		my $error_msg = $!;
		Wx::MessageBox( $error_msg, Wx::gettext('Error'), Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
		return 0;
	}
}

# Action that must be executaded when a item is activated
# Called when the item is actived
sub _on_tree_item_activated {
	my ( $self, $event ) = @_;
	my $parent    = $self->parent;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	# If its a folder expands/collapses it and returns
	# or makes it the current project folder, depending
	# of the mode view
	if ( $node_data->{type} eq 'folder' or $node_data->{type} eq 'upper' ) {
		if ( $parent->mode eq 'navigate' ) {
			$parent->{projects}->{ $parent->project_dir_original }->{dir} =
				File::Spec->catdir( $node_data->{dir}, $node_data->{name} );
			$parent->refresh;
		} else {
			$self->Toggle($node);
		}
		return;
	}

	# Returns if the selected FILE have no path
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	return if not defined $path;

	# Opens the selected file
	my $main = $self->main;
	if ( my $id = $main->find_editor_of_file($path) ) {
		my $page = $main->notebook->GetPage($id);
		$page->SetFocus;
	} else {
		$main->setup_editors($path);
	}
	return;
}

# Verifies if the new file name already exists and prompt if it does
# or rename the file if don't.
# Called when a item label is edited
sub _on_tree_end_label_edit {
	my ( $self, $event ) = @_;

	# Returns if no label is typed
	return unless $event->GetLabel();

	# Node old and new names and paths
	my $node_data = $self->GetPlData( $event->GetItem );
	my $old_file  = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	my $new_file  = File::Spec->catfile( $node_data->{dir}, $event->GetLabel() );
	my $new_label = ( File::Spec->splitpath($new_file) )[2];

	# Loops while already exists a file with the new label name
	while ( -e $new_file ) {

		# Prompts the user asking for a new name for the file
		my $prompt = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext('Please choose a different name.'),
			Wx::gettext('File already exists'),
			$new_label,
		);

		# If Cancel button pressed, ignores changes and returns
		if ( $prompt->ShowModal == Wx::wxID_CANCEL ) {
			$event->Veto();
			return;
		}

		# Reads the new file name and generates its complete path
		$new_file = File::Spec->catfile( $node_data->{dir}, $prompt->GetValue );
		$new_label = ( File::Spec->splitpath($new_file) )[2];
		$prompt->Destroy;
	}

	# Ignores changes if the renaming have no success
	$event->Veto() unless $self->_rename_or_move( $old_file, $new_file );
	return;
}

# Caches the item path as current selected item
# Called when a item is selected
sub _on_tree_sel_changed {
	my ( $self, $event ) = @_;
	my $node_data = $self->GetPlData( $event->GetItem );

	# Caches the item path
	$self->{current_item}->{ $self->parent->project_dir } =
		File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
}

# Expands the node and loads its content.
# Called when a folder is expanded.
sub _on_tree_item_expanding {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	# Returns if a search is being done (expands only the browser listing)
	return if ! defined($self->search);
	return if $self->search->{in_use}->{ $self->parent->project_dir };

	# The item complete path
	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	# Cache the expanded state of the node
	$self->{CACHED}->{ $self->parent->project_dir }->{Expanded}->{$path} = 1;

	# Updates the node content if it changed or has no child
	if ( $self->_updated_dir($path) or !$self->GetChildrenCount($node) ) {
		$self->_list_dir($node);
	}
}

# Deletes nodes Expanded cache param.
# Called when a folder is collapsed.
sub _on_tree_item_collapsing {
	my ( $self, $event ) = @_;
	my $node        = $event->GetItem;
	my $node_data   = $self->GetPlData($node);
	my $project_dir = $self->parent->project_dir;

	# If it is the Root node, set Expanded to 0
	if ( $node == $self->GetRootItem ) {
		$self->{CACHED}->{$project_dir}->{Expanded}->{$project_dir} = 0;
		return;
	}

	# Deletes cache expanded state of the node
	delete $self->{CACHED}->{$project_dir}->{Expanded}
		->{ File::Spec->catfile( $node_data->{dir}, $node_data->{name} ) };
}

# If the item is not the root node let it to be dragged.
# Called when a item is dragged.
sub _on_tree_begin_drag {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	# Only drags if it's not the Root node
	# and if it's not the upper item
	if (    $node != $self->GetRootItem
		and $node_data->{type} ne 'upper' )
	{
		$self->{dragged_item} = $node;
		$event->Allow;
	}
}

# If dragged to a different folder, tries to move (renaming) it to the new
# folder.
# Called just after the item is dragged.
sub _on_tree_end_drag {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	# If drops to a file, the new destination will be it's folder
	if ( $node->IsOk and ( !$self->ItemHasChildren($node) and $node_data->{type} ne 'upper' ) ) {
		$node = $self->GetItemParent($node);
	}

	# Returns if the target node doesn't exists
	return unless $node->IsOk;

	# Gets dragged and target nodes data
	my $new_data = $self->GetPlData($node);
	my $old_data = $self->GetPlData( $self->{dragged_item} );

	# Returns if the target is the file parent
	my $from = $old_data->{dir};
	my $to = File::Spec->catfile( $new_data->{dir}, $new_data->{name} );
	return if $from eq $to;

	# The file complete name (path and its name) before and after the move
	my $old_file = File::Spec->catfile( $old_data->{dir}, $old_data->{name} );
	my $new_file = File::Spec->catfile( $to, $old_data->{name} );

	# Alerts if there is a file with the same name in the target
	if ( -e $new_file ) {
		Wx::MessageBox(
			Wx::gettext('A file with the same name already exists in this directory'),
			Wx::gettext('Error'),
			Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
		);
		return;
	}

	# Pops up a menu to confirm the
	# action do be done
	my $menu    = Wx::Menu->new;

	# Move file
	my $menu_mv = $menu->Append(
		-1,
		Wx::gettext( 'Move here' )
	);
	Wx::Event::EVT_MENU(
		$self, $menu_mv,
		sub { $self->_rename_or_move( $old_file, $new_file ) }
	);

	# Copy file
	my $menu_cp = $menu->Append(
		-1,
		Wx::gettext( 'Copy here' )
	);
	Wx::Event::EVT_MENU(
		$self, $menu_cp,
		sub{ $self->_copy( $old_file, $new_file ) }
	);

	# Cancel action
	$menu->AppendSeparator();
	my $menu_cl = $menu->Append(
		-1,
		Wx::gettext( 'Cancel' )
	);

	# Pops up the context menu
	my $x = $event->GetPoint->x;
	my $y = $event->GetPoint->y;
	$self->PopupMenu( $menu, $x, $y );
}

# Shows up a context menu above an item with its controls
# the file if don't.
# Called when a item context menu is requested.
sub _on_tree_item_menu {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	# Do not show if it is the upper item
	return if $node_data->{type} eq 'upper';

	my $menu          = Wx::Menu->new;
	my $selected_dir  = $node_data->{dir};
	my $selected_path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

	# Default action - same when the item is activated
	my $default = $menu->Append(
		-1,
		Wx::gettext( $node_data->{type} eq 'folder' ? 'Open Folder' : 'Open File' )
	);
	Wx::Event::EVT_MENU(
		$self, $default,
		sub { $self->_on_tree_item_activated($event) }
	);
	$menu->AppendSeparator();

	# Rename and/or move the item
	my $rename = $menu->Append( -1, Wx::gettext('Rename / Move') );
	Wx::Event::EVT_MENU(
		$self, $rename,
		sub {
			$self->EditLabel($node);
		},
	);

	# Move item to trash
	# Note: File::Remove->trash() only works in Win and Mac

	if ( IS_WIN32 or IS_MAC ) {
		my $trash = $menu->Append( -1, Wx::gettext('Move to trash') );
		Wx::Event::EVT_MENU(
			$self, $trash,
			sub {
				eval {
					require File::Remove;
					File::Remove->trash($selected_path);
				};
				if ($@) {
					my $error_msg = $@;
					Wx::MessageBox(
						$error_msg, Wx::gettext('Error'),
						Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
					);
				}
				return;
			},
		);
	}

	# Delete item
	my $delete = $menu->Append( -1, Wx::gettext('Delete') );
	Wx::Event::EVT_MENU(
		$self, $delete,
		sub {

			my $dialog = Wx::MessageDialog->new(
				$self,
				Wx::gettext('Are you sure you want to delete this item?') . $/ . $selected_path,
				Wx::gettext('Delete'),
				Wx::wxYES_NO | Wx::wxICON_QUESTION | Wx::wxCENTRE
			);
			return if $dialog->ShowModal == Wx::wxID_NO;

			eval {
				require File::Remove;
				File::Remove->remove($selected_path);
			};
			if ($@) {
				my $error_msg = $@;
				Wx::MessageBox(
					$error_msg, Wx::gettext('Error'),
					Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
				);
			}
			return;
		},
	);

	# ?????
	if ( defined $node_data->{type} and ( $node_data->{type} eq 'modules' or $node_data->{type} eq 'pragmata' ) ) {
		my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
		Wx::Event::EVT_MENU(
			$self, $pod,
			sub {

				# TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
				require Padre::Wx::DocBrowser;
				my $help = Padre::Wx::DocBrowser->new;
				$help->help( $node_data->{name} );
				$help->SetFocus;
				$help->Show(1);
				return;
			},
		);
	}
	$menu->AppendSeparator();

	# Shows / Hides hidden files - applied to each directory
	my $hiddenFiles     = $menu->AppendCheckItem( -1, Wx::gettext('Show hidden files') );
	my $applies_to_node = $node;
	my $applies_to_path = $selected_path;
	if ( $node_data->{type} ne 'folder' ) {
		$applies_to_path = $selected_dir;
		$applies_to_node = $self->GetParent($node);
	}

	my $cached = \%{ $self->{CACHED}->{$applies_to_path} };
	my $show   = $cached->{ShowHidden};
	$hiddenFiles->Check($show);
	Wx::Event::EVT_MENU(
		$self,
		$hiddenFiles,
		sub {
			$cached->{ShowHidden} = !$show;
			$self->_list_dir($applies_to_node);
		},
	);

	# Updates the directory listing
	my $reload = $menu->Append( -1, Wx::gettext('Reload') );
	Wx::Event::EVT_MENU(
		$self, $reload,
		sub {
			delete $self->{CACHED}->{ $self->GetPlData($node)->{dir} }->{Change};
		}
	);

	# Pops up the context menu
	my $x = $event->GetPoint->x;
	my $y = $event->GetPoint->y;
	$self->PopupMenu( $menu, $x, $y );

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use File::Basename ();
use Params::Util qw{_INSTANCE};
use Padre::Current ();
use Padre::Util    ();
use Padre::Wx      ();

our $VERSION = '0.39';
our @ISA     = 'Wx::TreeCtrl';

use constant IS_MAC => !!( $^O eq 'darwin' );
use constant IS_WIN32 => !!( $^O =~ /^MSWin/ or $^O eq 'cygwin' );

sub new {
	my $class = shift;
	my $main  = shift;

	my $self = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS | Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE
			| Wx::wxTR_FULL_ROW_HIGHLIGHT
	);

	$self->{SKIP}            = { map { $_ => 1 } ( '.', '..' ) }; # '.svn', 'CVS', '.git'
	$self->{CACHED}          = {};
	$self->{force_next}      = 0;
	$self->{current_item}    = {};
	$self->{current_project} = '';

	$self->_setup_image_list();
	$self->_setup_events;
	$self->_add_root();

	$self->SetIndent(10);

	return $self;
}

sub right {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub current {
	Padre::Current->new( main => $_[0]->main );
}

sub gettext_label {
	Wx::gettext('Directory');
}

sub clear {
	my $self = shift;
	unless ( $self->current->filename ) {
		$self->DeleteChildren( $self->GetRootItem );
		$self->{current_project} = '';
	}
	return;
}

sub force_next {
	my $self = shift;
	if ( defined $_[0] ) {
		$self->{force_next} = $_[0];
		return $self->{force_next};
	} else {
		return $self->{force_next};
	}
}

sub _setup_image_list {
	my $self = shift;

	my %file_types = (
		folder  => 'wxART_FOLDER',
		package => 'wxART_NORMAL_FILE',
	);

	my $image_list = Wx::ImageList->new( 16, 16 );

	for my $type ( keys %file_types ) {
		$self->{file_types}->{$type} = $image_list->Add(
			Wx::ArtProvider::GetBitmap(
				$file_types{$type},
				'wxART_OTHER_C',
				[ 16, 16 ]
			)
		);
	}

	$self->AssignImageList($image_list);
}

sub _setup_events {
	my $self = shift;
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		\&_on_tree_item_activated
	);

	Wx::Event::EVT_SET_FOCUS(
		$self,
		\&_on_focus
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

	Wx::Event::EVT_TREE_BEGIN_LABEL_EDIT(
		$self, $self,
		\&_on_tree_begin_label_edit,
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
}

sub _add_root {
	shift->AddRoot(
		Wx::gettext('Directory'),
		-1, -1,
		Wx::TreeItemData->new(
			{   dir  => '',
				name => '',
				type => 'folder',
			}
		)
	);
}

###################################################################################
# _list_dir                                                                       #
# Updates a node's content                                                        #
#                                                                                 #
# Called only if project directory changes or show/hide hidden files is requested #
###################################################################################
sub _list_dir {
	my ( $self, $node ) = @_;
	my $node_data = $self->GetPlData($node);
	my $path      = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	my $cached    = \%{ $self->{CACHED}->{$path} };

	#####################################################################
	# If the folder had changes or isn't cached, read its content and cache
	if ( $self->_updated_dir($path) ) {

		#####################################################################
		# Open the folder and sort its content by name and type
		opendir( my $dh, $path ) or return;
		my @items =
			sort { ( -d File::Spec->catfile( $path, $b ) ) <=> ( -d File::Spec->catfile( $path, $a ) ) }
			sort { lc($a) cmp lc($b) } grep { not $self->{SKIP}->{$_} } readdir $dh;
		closedir $dh;

		#####################################################################
		# For each item, creates its CACHE data
		@{ $cached->{Data} } =
			map { { name => $_, dir => $path, type => ( -d File::Spec->catfile( $path, $_ ) ? 'folder' : 'package' ) } }
			@items;
		$cached->{Change} = ( stat $path )[10];
	}

	my @data = @{ $cached->{Data} };
	#####################################################################
	# Shows / hides hidden files
	unless ( $cached->{ShowHidden} ) {
		if (IS_WIN32) { # TODO Test if this Windows solutions works
			require Win32::File;
			use constant HIDDEN => 2;
			my $attribs;
			@data = grep {
				Win32::File::GetAttributes( File::Spec->catfile( $_->{dir}, $_->{name} ), $attribs )
					and !( $attribs & HIDDEN )
			} @{ $cached->{Data} };
		} else {
			@data = grep { $_->{name} !~ /^\./ } @{ $cached->{Data} };
		}
	}

	#####################################################################
	# Delete node children and populates it again
	$self->DeleteChildren($node);
	foreach my $each (@data) {
		my $new_elem = $self->AppendItem(
			$node,
			$each->{name},
			-1, -1,
			Wx::TreeItemData->new( { dir => $each->{dir}, name => $each->{name}, type => $each->{type} } )
		);
		$self->SetItemHasChildren( $new_elem, 1 ) if $each->{type} eq 'folder';
		$self->SetItemImage( $new_elem, $self->{file_types}->{ $each->{type} }, Wx::wxTreeItemIcon_Normal );
	}
}

sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	return unless -e $dir;

	my $root    = $self->GetRootItem;
	my $project = $self->{current_project};

	if ( defined($project) and ( $project ne $dir ) or $self->_updated_dir($dir) ) {
		$self->_update_root_data($dir);
		$self->_list_dir($root);
	}

	$self->{current_project} = $dir;
	_update_subdirs( $self, $root );
}

sub _update_root_data {
	my $self = shift;
	my ( $volume, $path, $name ) = File::Spec->splitpath(shift);

	my $root_data = $self->GetPlData( $self->GetRootItem );
	$root_data->{dir}  = $volume . $path;
	$root_data->{name} = $name;
}

sub _updated_dir {
	my $self   = shift;
	my $dir    = shift;
	my $cached = $self->{CACHED}->{$dir};

	if ( not defined($cached) or !$cached->{Data} or !$cached->{Change} or ( stat $dir )[10] != $cached->{Change} ) {
		return 1;
	}
	return 0;
}

sub _update_subdirs {
	my ( $self, $root ) = @_;
	my $project = $self->{current_project};

	my $cookie;
	for my $item ( 1 .. $self->GetChildrenCount($root) ) {

		( my $node, $cookie ) = $item == 1 ? $self->GetFirstChild($root) : $self->GetNextChild( $root, $cookie );
		my $item_data = $self->GetPlData($node);
		my $path = File::Spec->catfile( $item_data->{dir}, $item_data->{name} );

		if ( defined $self->{CACHED}->{$project}->{Expanded}->{$path} ) {
			$self->Expand($node);
			$self->_list_dir($node) if $self->_updated_dir($path);
			_update_subdirs( $self, $node );
		}
		if ( defined $self->{current_item}->{$project} and $self->{current_item}->{$project} eq $path ) {
			$self->SelectItem($node);
			$self->ScrollTo($node);
		}
	}
}

sub _on_focus {
	my ( $self, $event ) = @_;
	my $main = $self->main;
	$self->update_gui if $main->has_directory;
}

sub _on_tree_item_activated {
	my ( $self, $event ) = @_;

	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	return if not defined $node_data;

	if ( $node_data->{type} eq "folder" ) {
		$self->Toggle($node);
		return;
	}

	my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	return if not defined $path;
	my $main = $self->main;
	if ( my $id = $main->find_editor_of_file($path) ) {
		my $page = $main->notebook->GetPage($id);
		$page->SetFocus;
	} else {
		$main->setup_editors($path);
	}
	return;
}

sub _on_tree_begin_label_edit {
	my ( $dir, $event ) = @_;

	# If any restriction, can do veto here
}

sub _on_tree_end_label_edit {
	my ( $self, $event ) = @_;

	return unless $event->GetLabel();

	my $node_data = $self->GetPlData( $event->GetItem );
	my $old_file  = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	my $new_file  = File::Spec->catfile( $node_data->{dir}, $event->GetLabel() );
	my $new_label = ( File::Spec->splitpath($new_file) )[2];

	while ( -e $new_file ) {

		my $prompt = Wx::TextEntryDialog->new(
			$self,
			Wx::gettext('Please, choose a different name.'),
			Wx::gettext('File already exists'),
			$new_label,
		);

		if ( $prompt->ShowModal == Wx::wxID_CANCEL ) {
			$event->Veto();
			return;
		}

		$new_file = File::Spec->catfile( $node_data->{dir}, $prompt->GetValue );
		$new_label = ( File::Spec->splitpath($new_file) )[2];
		$prompt->Destroy;
	}

	$self->Veto() unless $self->_rename_or_move( $old_file, $new_file );
	return;
}

sub _on_tree_sel_changed {
	my ( $self, $event ) = @_;
	my $node_data = $self->GetPlData( $event->GetItem );
	if ( ref $node_data eq 'HASH' ) {
		$self->{current_item}->{ $self->{current_project} } =
			File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
	}
}

sub _on_tree_item_expanding {
	my ( $self, $event ) = @_;
	my $current   = $self->current;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	if ( defined( $node_data->{type} ) && $node_data->{type} eq 'folder' ) {

		my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
		$self->{CACHED}->{ $self->{current_project} }->{Expanded}->{$path} = 1;

		if ( $self->_updated_dir($path) or !$self->GetChildrenCount($node) ) {
			$self->_list_dir($node);
		}
	}
}

sub _on_tree_item_collapsing {
	my ( $self, $event ) = @_;
	my $node_data = $self->GetPlData( $event->GetItem );

	if ( defined( $node_data->{type} ) and $node_data->{type} eq 'folder' ) {
		my $path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );
		delete $self->{CACHED}->{ $self->{current_project} }->{Expanded}->{$path};
	}
}

sub _on_tree_begin_drag {
	my ( $self, $event ) = @_;
	my $node = $event->GetItem;
	if ( $node != $self->GetRootItem ) {
		$self->{dragged_item} = $node;
		$event->Allow;
	}
}

sub _on_tree_end_drag {
	my ( $self, $event ) = @_;
	my $node = $event->GetItem;

	#####################################################################
	# If drops to a file, the new destination will be it's folder
	if ( $node->IsOk and !$self->ItemHasChildren($node) ) {
		$node = $self->GetItemParent($node);
	}

	return if !$node->IsOk;

	my $new_data = $self->GetPlData($node);
	my $old_data = $self->GetPlData( $self->{dragged_item} );

	my $from = $old_data->{dir};
	my $to = File::Spec->catfile( $new_data->{dir}, $new_data->{name} );
	return if $from eq $to;

	my $old_file = File::Spec->catfile( $old_data->{dir}, $old_data->{name} );
	my $new_file = File::Spec->catfile( $to, $old_data->{name} );

	if ( -e $new_file ) {
		Wx::MessageBox(
			Wx::gettext('Already exists a file with the same name in this directory'),
			Wx::gettext('Error'),
			Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
		);
		return;
	}

	$self->update_gui if $self->_rename_or_move( $old_file, $new_file );
	return;
}

#####################################################################
# Removes '..' and its previous directories
sub _removes_double_dot {
	my ( $self, $file ) = @_;
	my @dirs = File::Spec->splitdir($file);
	for ( my $i = 0; $i < @dirs; $i++ ) {
		splice @dirs, $i - 1, 2 if $i > 0 and $dirs[$i] eq "..";
	}
	return File::Spec->catfile(@dirs);
}

sub _rename_or_move {
	my $self     = shift;
	my $old_file = $self->_removes_double_dot(shift);
	my $new_file = $self->_removes_double_dot(shift);

	if ( rename $old_file, $new_file ) {

		my $project = $self->{current_project};
		$self->{current_item}->{$project} = $new_file;

		my $cached = $self->{CACHED};
		$cached->{$project}->{Expanded}->{ File::Basename::dirname($new_file) } = 1;
		if ( defined $cached->{$project}->{Expanded}->{$old_file} ) {
			$cached->{$project}->{Expanded}->{$new_file} = 1;
			delete $cached->{$project}->{Expanded}->{$old_file};
		}

		my $separator = File::Spec->catfile( $old_file, 'temp' );
		$separator =~ s/^$old_file(.?)temp$/$1/;
		map {
			$cached->{ $new_file . ( defined $1 ? $1 : '' ) } = $cached->{$_}, delete $cached->{$_}
				if $_ =~ /^$old_file($separator.+?)?$/
		} keys %$cached;
		return 1;
	} else {
		my $error_msg = $!;
		Wx::MessageBox( $error_msg, Wx::gettext('Error'), Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
		return 0;
	}
}

sub _on_tree_item_menu {
	my ( $self, $event ) = @_;
	my $node      = $event->GetItem;
	my $node_data = $self->GetPlData($node);

	if ( defined $node_data ) {

		my $menu          = Wx::Menu->new;
		my $selected_dir  = $node_data->{dir};
		my $selected_path = File::Spec->catfile( $node_data->{dir}, $node_data->{name} );

		#####################################################################
		# Default action - same when the item is activated
		my ( $default_text, $default_sub );
		if ( $node_data->{type} eq 'folder' ) {
			$default_text = Wx::gettext('Expand / Collapse\t');
			$default_sub = sub { $self->Toggle($node) };
		} else {
			$default_text = Wx::gettext('Open File');
			$default_sub = sub { $self->_on_tree_item_activated($event) };
		}

		Wx::Event::EVT_MENU(
			$self,
			$menu->Append( -1, $default_text ),
			$default_sub,
		);
		$menu->AppendSeparator();

		#####################################################################
		# Rename and/or move the item
		my $rename = $menu->Append( -1, Wx::gettext('Rename / Move') );
		Wx::Event::EVT_MENU(
			$self, $rename,
			sub {
				$self->EditLabel($node);
			},
		);

		#####################################################################
		# Move item to trash
		# Note: File::Remove->trash() Works only in Win and Mac
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

		#####################################################################
		# Delete item
		my $delete = $menu->Append( -1, Wx::gettext('Delete') );
		Wx::Event::EVT_MENU(
			$self, $delete,
			sub {

				my $dialog = Wx::MessageDialog->new(
					$self,
					Wx::gettext('You sure want to delete this item?') . $/ . $selected_path,
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

		#####################################################################
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

		#####################################################################
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

		#####################################################################
		# Updates the directory listing
		my $reload = $menu->Append( -1, Wx::gettext('Reload') );
		Wx::Event::EVT_MENU(
			$self, $reload,
			sub {
				delete $self->{CACHED}->{ $self->GetPlData($node)->{dir} }->{Change};
			}
		);

		#####################################################################
		# Pops up the context menu
		my $x = $event->GetPoint->x;
		my $y = $event->GetPoint->y;
		$self->PopupMenu( $menu, $x, $y );
	}
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

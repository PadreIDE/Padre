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

use constant IS_MAC   => !! ( $^O eq 'darwin' );
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
		folder => 'wxART_FOLDER',
		package => 'wxART_NORMAL_FILE',
		@_,
	);

	my $image_list = Wx::ImageList->new( 16, 16 );

	for my $type (keys %file_types){
		$self->{file_types}->{$type} = $image_list->Add(
							Wx::ArtProvider::GetBitmap( $file_types{$type},
							'wxART_OTHER_C',
							[16, 16] )
						)
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
		Wx::TreeItemData->new({
				dir  => '',
				name => '',
				type => 'folder',
		})
	);
}

#####################################################################
# Event Handlers

sub _list_dir {
	my ( $self, $dir ) = @_;

	my $cached = $self->{CACHED}->{$dir};
	$self->{CACHED}->{$dir} = {} unless $cached;

	if ( $self->_updated_dir($dir) ) {

		$cached->{Change} = ( stat $dir )[10];

		if ( opendir my $dh, $dir ) {

			my @items = sort { lc($a) cmp lc($b) } grep { not $self->{SKIP}->{$_} } readdir $dh;

			unless ( $cached->{ShowHidden} ) {

				#####################################################################
				# TODO Test if this Windows solutions works
				if (IS_WIN32) {
					#require Win32::File;
					#my $attribs;
					#@items = grep { Win32::File::GetAttributes( $_, $attribs ) and !( $attribs & HIDDEN ) } @items;
				} else {
					@items = grep { not /^\./ } @items;
				}
			}

			my @data;
			foreach my $thing (@items) {
				my $path = File::Spec->catfile( $dir, $thing );
				my %item = (
					type => 'package' ,
					name => $thing,
					dir  => $dir,
				);
				$item{type} = 'folder' if  -d $path;
				push @data, \%item;
			}

			@{ $cached->{Data} } = sort {($b->{type} eq 'folder') <=> ($a->{type} eq 'folder')} @data;
			closedir $dh;
		}
	}
	return $cached->{Data};
}

sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	my $updated = $self->_updated_dir($dir);
	my $data    = $self->_list_dir($dir);
	return unless @{$data};

	my $root    = $self->GetRootItem;
	my $project = $self->{current_project};

	if ( ( defined($project) and $project ne $dir ) or $updated ) {
		$self->DeleteChildren($root);
		$self->_update_root_data($dir);
		_update_treectrl( $self, $data, $root );
	}

	$project = $dir;
	_update_subdirs( $self, $root );
}

sub _update_root_data {
	my $self = shift;
	my ( $volume, $path, $name ) = File::Spec->splitpath( shift );

	my $root_data = $self->GetPlData( $self->GetRootItem );
	$root_data->{dir} = $volume . $path;
	$root_data->{name} = $name;
}

sub _updated_dir {
	my $self = shift;
	my $dir  = shift;

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

		if (    defined $item_data->{type}
			and $item_data->{type} eq 'folder'
			and defined $self->{CACHED}->{$project}->{Expanded}->{$path} )
		{

			$self->Expand($node);

			if ( $self->_updated_dir($path) ) {
				$self->DeleteChildren($node);
				_update_treectrl( $self, $self->_list_dir($path), $node );
			}
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

	my $item_obj = $event->GetItem;
	my $item     = $self->GetPlData($item_obj);

	return if not defined $item;

	if ( $item->{type} eq "folder" ) {
		$self->Toggle($item_obj);
		return;
	}

	my $path = File::Spec->catfile( $item->{dir}, $item->{name} );
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

	my $item_obj  = $event->GetItem;
	my $item_data = $self->GetPlData($item_obj);

	my $old_file = File::Spec->catfile( $item_data->{dir}, $item_data->{name} );
	my $new_file = File::Spec->catfile( $item_data->{dir}, $event->GetLabel() );
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

		$new_file = File::Spec->catfile( $item_data->{dir}, $prompt->GetValue );
		$new_label = ( File::Spec->splitpath($new_file) )[2];
		$prompt->Destroy;
	}

	if ( rename $old_file, $new_file ) {

		$item_data->{name} = $new_label;
		my $project = $self->{current_project};
		$self->{current_item}->{$project} = $new_file;

		my $cached = $self->{CACHED};
		if ( defined $cached->{$project}->{Expanded}->{$old_file} ) {
			$cached->{$project}->{Expanded}->{$new_file} = 1;
			delete $cached->{$project}->{Expanded}->{$old_file};
		}

		my $separator = File::Spec->catfile($old_file,"temp");
		$separator =~ s/^$old_file(.?)temp$/$1/;
		map {
			$cached->{ $new_file . ( defined $1 ? $1 : '' ) } = $cached->{$_}, delete $cached->{$_}
				if $_ =~ m#^$old_file(($separator).+)?$#
		} keys %$cached;
	} else {
		my $error_msg = $!;
		Wx::MessageBox( $error_msg, Wx::gettext('Error'), Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
		$event->Veto();
	}
	return;
}

sub _on_tree_sel_changed {
	my ( $self, $event ) = @_;
	my $item_obj  = $event->GetItem;
	my $item_data = $self->GetPlData($item_obj);
	if ( ref $item_data eq 'HASH' ) {
		$self->{current_item}->{ $self->{current_project} } =
			File::Spec->catfile( $item_data->{dir}, $item_data->{name} );
	}
}

sub _on_tree_item_expanding {
	my ( $self, $event ) = @_;
	my $current   = $self->current;
	my $item_obj  = $event->GetItem;
	my $item_data = $self->GetPlData($item_obj);

	if ( defined( $item_data->{type} ) && $item_data->{type} eq 'folder' ) {

		my $path = File::Spec->catfile( $item_data->{dir}, $item_data->{name} );
		$self->{CACHED}->{ $self->{current_project} }->{Expanded}->{$path} = 1;

		if ( $self->_updated_dir($path) or !$self->GetChildrenCount($item_obj) ) {
			$self->DeleteChildren($item_obj);
			_update_treectrl( $self, $self->_list_dir($path), $item_obj );
		}
	}
}

sub _on_tree_item_collapsing {
	my ( $self, $event ) = @_;
	my $item_obj  = $event->GetItem;
	my $item_data = $self->GetPlData($item_obj);

	if ( defined( $item_data->{type} ) and $item_data->{type} eq 'folder' ) {
		my $path = File::Spec->catfile( $item_data->{dir}, $item_data->{name} );
		delete $self->{CACHED}->{ $self->{current_project} }->{Expanded}->{$path};
	}
}

sub _on_tree_begin_drag {
	my( $self, $event ) = @_;
	my $item_obj = $event->GetItem;
	if( $item_obj != $self->GetRootItem ) {
		$self->{dragged_item} = $item_obj;
		$event->Allow;
	}
}

sub _on_tree_end_drag {
	my( $self, $event ) = @_;
	my $item_obj = $event->GetItem;

	#####################################################################
	# If drops to a file, the new destination will be it's folder
	if( $item_obj->IsOk and !$self->ItemHasChildren( $item_obj ) ) {
		$item_obj = $self->GetItemParent( $item_obj );
	}

	return if !$item_obj->IsOk;

	my $new_data = $self->GetPlData( $item_obj );
	my $old_data = $self->GetPlData( $self->{dragged_item} );

	my $from = $old_data->{dir};
	my $to = File::Spec->catfile($new_data->{dir}, $new_data->{name} );
	return if $from eq $to;

	my $old_file = File::Spec->catfile($old_data->{dir}, $old_data->{name} );
	my $new_file = File::Spec->catfile($to, $old_data->{name} );
	
	if(-e $new_file){
		Wx::MessageBox(
			Wx::gettext('Already exists a file with the same name in this directory'),
			Wx::gettext('Error'),
			Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR
		);
		return;
	}

	if ( rename $old_file, $new_file ) {
		my $project = $self->{current_project};
		$self->{current_item}->{$project} = $new_file;

		my $cached = $self->{CACHED};
		$cached->{$project}->{Expanded}->{$to} = 1;
		if ( defined $cached->{$project}->{Expanded}->{$old_file} ) {
			$cached->{$project}->{Expanded}->{$new_file} = 1;
			delete $cached->{$project}->{Expanded}->{$old_file};
		}

		my $separator = File::Spec->catfile($old_file,"temp");
		$separator =~ s/^$old_file(.?)temp$/$1/;
		map {
			$cached->{ $new_file . ( defined $1 ? $1 : '' ) } = $cached->{$_}, delete $cached->{$_}
				if $_ =~ m#^$old_file(($separator).+)?$#
		} keys %$cached;

	} else {
		my $error_msg = $!;
		Wx::MessageBox( $error_msg, Wx::gettext('Error'), Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
	}
	$self->update_gui;
	return;
}

sub _on_tree_item_menu {
	my ( $self, $event ) = @_;
	my $item_obj  = $event->GetItem;
	my $item_data = $self->GetPlData($item_obj);

	if ( defined $item_data ) {

		my $menu          = Wx::Menu->new;
		my $selected_dir  = $item_data->{dir};
		my $selected_path = File::Spec->catfile( $item_data->{dir}, $item_data->{name} );

		#####################################################################
		# Default action - same when the item is activated
		my ( $default_text, $default_sub );
		if ( $item_data->{type} eq 'folder' ) {
			$default_text = Wx::gettext('Expand / Collapse');
			$default_sub = sub { $self->Toggle($item_obj) };
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
				$self->EditLabel($item_obj);
			},
		);

		#####################################################################
		# Move item to trash
		# Note: File::Remove->trash() Works only in Win and Mac
		if (IS_WIN32 or IS_MAC ) {
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
						Wx::MessageBox( $error_msg, Wx::gettext('Error'),
							Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
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
					Wx::MessageBox( $error_msg, Wx::gettext('Error'),
						Wx::wxOK | Wx::wxCENTRE | Wx::wxICON_ERROR );
				}
				return;
			},
		);


		#####################################################################
		# ?????
		if ( defined $item_data->{type} and ( $item_data->{type} eq 'modules' or $item_data->{type} eq 'pragmata' ) ) {
			my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
			Wx::Event::EVT_MENU(
				$self, $pod,
				sub {

					# TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
					require Padre::Wx::DocBrowser;
					my $help = Padre::Wx::DocBrowser->new;
					$help->help( $item_data->{name} );
					$help->SetFocus;
					$help->Show(1);
					return;
				},
			);
		}
		$menu->AppendSeparator();

		#####################################################################
		# Shows / Hides dot started files and folers (not avaiable for Windows)
		my $hiddenFiles = $menu->AppendCheckItem( -1, Wx::gettext('Show hidden files') );
		if ( $item_data->{type} eq 'folder' ) {
			$selected_dir = $selected_path;
		}
		my $cached = $self->{CACHED}->{$selected_dir};
		my $show   = $cached->{ShowHidden};
		$hiddenFiles->Check($show);
		Wx::Event::EVT_MENU(
			$self,
			$hiddenFiles,
			sub {
				$cached->{ShowHidden} = !$show;
				delete $cached->{Data};
			},
		);


		#####################################################################
		# Updates the directory listing
		my $reload = $menu->Append( -1, Wx::gettext('Reload') );
		Wx::Event::EVT_MENU(
			$self, $reload,
			sub {
				delete $self->{CACHED}->{ $self->GetPlData($item_obj)->{dir} }->{Change};
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

sub _update_treectrl {
	my ( $self, $data, $root ) = @_;
	foreach my $pkg ( @{$data} ) {
		my $type_elem = $self->AppendItem(
			$root,
			$pkg->{name},
			-1, -1,
			Wx::TreeItemData->new(
				{   dir  => $pkg->{dir},
					name => $pkg->{name},
					type => $pkg->{type},
				}
			)
		);
		$self->SetItemHasChildren( $type_elem, 1 ) if $pkg->{type} eq 'folder';
		$self->SetItemImage( $type_elem, $self->{file_types}->{$pkg->{type}}, Wx::wxTreeItemIcon_Normal);
	}
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

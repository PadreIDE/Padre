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

	$self->{SKIP}            = { map { $_ => 1 } ( '.', '..', '.svn', 'CVS', '.git' ) };
	$self->{CACHED}          = {};
	$self->{force_next}      = 0;
	$self->{current_item}    = {};
	$self->{current_project} = '';

	$self->_setup_events;
	$self->_add_root();

	$self->SetIndent(10);

	#	Do they need to be used?
	#	$self->GetBestSize;
	#	$self->Thaw;
	#	$self->Hide;

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

}

sub _add_root {
	my ( $self, $name, $data ) = @_;

	$name |= Wx::gettext('Directory');
	$data |= {};

	$self->AddRoot(
		$name,
		-1,
		-1,
		Wx::TreeItemData->new($data)
	);
}

#####################################################################
# Event Handlers

sub _list_dir {
	my ( $self, $dir ) = @_;

	my $cached = $self->{CACHED}->{$dir};

	if ( $self->_updated_dir($dir) ) {

		$cached->{Change} = ( stat $dir )[10];

		if ( opendir my $dh, $dir ) {

			my @items = sort { lc($a) cmp lc($b) } grep { not $self->{SKIP}->{$_} } readdir $dh;


			unless ( $cached->{ShowHidden} ) {

#####################################################################
# Show/Hide Windows hidden files and directories - NEED TO BE TESTED
#
#				if ( $^O !~ /^win32/i ) {
#					require Win32::File;
#					my $attribs;
#					@items = grep { Win32::File::GetAttributes( $_, $attribs ) and !( $attribs & HIDDEN ) } @items;
#				}
#				else {
#
				@items = grep { not /^\./ } @items;

#
#				}
#####################################################################
			}

			my @data;
			foreach my $thing (@items) {
				my $path = File::Spec->catfile( $dir, $thing );
				my %item = (
					name => $thing,
					dir  => $dir,
				);
				$item{isDir} = -d $path ? 1 : 0;
				push @data, \%item;
			}

			@{ $cached->{Data} } = sort { $b->{isDir} <=> $a->{isDir} } @data;
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
		_update_treectrl( $self, $data, $root );
	}

	$project = $dir;
	_update_subdirs( $self, $root );
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

		my $itemData = $self->GetPlData($node);
		my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );

		if (    defined $itemData->{type}
			and $itemData->{type} eq 'folder'
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

	my $itemObj = $event->GetItem;
	my $item    = $self->GetPlData($itemObj);

	return if not defined $item;

	if ( $item->{type} eq "folder" ) {
		$self->Toggle($itemObj);
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
	my $itemObj  = $event->GetItem;
	my $itemData = $self->GetPlData($itemObj);

	my $newLabel = $event->GetLabel();

	$event->Veto() if $newLabel =~ m#/$#;

	my $oldFile = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
	my $newFile = File::Spec->catfile( $itemData->{dir}, $newLabel );

	$event->Veto() if -e $newFile;

	if ( rename $oldFile, $newFile ) {

		$itemData->{name} = $newLabel;
		my $project = $self->{current_project};
		$self->{current_item}->{$project} = $newFile;

		my $cached = $self->{CACHED};

		if ( defined $cached->{$project}->{Expanded}->{$oldFile} ) {
			$cached->{$project}->{Expanded}->{$newFile} = 1;
			delete $cached->{$project}->{Expanded}->{$oldFile};
		}
		map {
			$cached->{ $newFile . ( defined $1 ? $1 : '' ) } = $cached->{$_}, delete $cached->{$_}
				if $_ =~ m#^$oldFile(\/.+)?$#
		} keys %$cached;
	} else {
		$event->Veto();
	}
}

sub _on_tree_sel_changed {
	my ( $self, $event ) = @_;
	my $itemObj  = $event->GetItem;
	my $itemData = $self->GetPlData($itemObj);
	if ( ref $itemData eq 'HASH' ) {
		$self->{current_item}->{ $self->{current_project} } =
			File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
	}
}

sub _on_tree_item_expanding {
	my ( $self, $event ) = @_;
	my $current  = $self->current;
	my $itemObj  = $event->GetItem;
	my $itemData = $self->GetPlData($itemObj);

	if ( defined( $itemData->{type} ) && $itemData->{type} eq 'folder' ) {

		my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
		$self->{CACHED}->{ $self->{current_project} }->{Expanded}->{$path} = 1;

		if ( $self->_updated_dir($path) or !$self->GetChildrenCount($itemObj) ) {
			$self->DeleteChildren($itemObj);
			_update_treectrl( $self, $self->_list_dir($path), $itemObj );
		}
	}
}

sub _on_tree_item_collapsing {
	my ( $self, $event ) = @_;
	my $itemObj  = $event->GetItem;
	my $itemData = $self->GetPlData($itemObj);

	if ( defined( $itemData->{type} ) && $itemData->{type} eq 'folder' ) {
		my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
		delete $self->{CACHED}->{ $self->{current_project} }->{Expanded}->{$path};
	}
}

sub _on_tree_item_menu {
	my ( $self, $event ) = @_;

	my $itemObj   = $event->GetItem;
	my $item_data = $self->GetPlData($itemObj);

	if ( defined $item_data ) {

		my $menu         = Wx::Menu->new;
		my $selected_dir = $item_data->{dir};

		#####################################################################
		# Default action - same when the item is activated
		#
		if ( defined $item_data->{type} and $item_data->{type} eq 'folder' ) {
			my $default = $menu->Append( -1, Wx::gettext("Expand / Collapse") );
			Wx::Event::EVT_MENU(
				$self, $default,
				sub { $self->Toggle($itemObj) },
			);
		} else {
			my $default = $menu->Append( -1, Wx::gettext("Open File") );
			Wx::Event::EVT_MENU(
				$self, $default,
				sub { $self->on_tree_item_activated($event) },
			);
		}

		$menu->AppendSeparator();

		#####################################################################
		# Rename and/or move the item
		my $rename = $menu->Append( -1, Wx::gettext("Rename") );
		Wx::Event::EVT_MENU(
			$self, $rename,
			sub {
				$self->EditLabel($itemObj);
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
		if ( $^O !~ /^win32/i ) {

			my $hiddenFiles = $menu->AppendCheckItem( -1, Wx::gettext("Show hidden files") );
			if ( $item_data->{type} eq 'folder' ) {
				$selected_dir = File::Spec->catfile( $item_data->{dir}, $item_data->{name} );
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

		}

		#####################################################################
		# Updates the directory listing
		my $reload = $menu->Append( -1, Wx::gettext("Reload") );
		Wx::Event::EVT_MENU(
			$self, $reload,
			sub {
				delete $self->{CACHED}->{ $self->GetPlData($itemObj)->{dir} }->{Change};
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
					type => $pkg->{isDir} ? 'folder' : 'package',
				}
			)
		);
		$self->SetItemHasChildren( $type_elem, 1 ) if $pkg->{isDir};
	}
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

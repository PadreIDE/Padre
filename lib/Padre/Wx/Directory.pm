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

my %CACHED;
my $current_dir;
my $current_item;
my %SKIP = map { $_ => 1 } ( '.', '..', '.svn', 'CVS', '.git' );

sub new {
	my $class = shift;
	my $main  = shift;

	my $self  = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS | Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE | Wx::wxTR_FULL_ROW_HIGHLIGHT
	);
	$self->SetIndent(10);
	$self->{force_next} = 0;

	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		sub {
			$self->on_tree_item_activated( $_[1] );
		},
	);

	Wx::Event::EVT_SET_FOCUS( $self,
		\&on_focus
	);

	Wx::Event::EVT_TREE_ITEM_MENU(
		$self, $self,
		\&_on_tree_item_menu,
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

	my $root = $self->AddRoot(
		Wx::gettext('Directory'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	$self->GetBestSize;
	$self->Thaw;

	$self->Hide;

	return $self;
}

sub on_focus {
	my ( $self, $event ) = @_;
	my $main = $self->main;

	if ( $main->has_directory ) {
		if ( $main->menu->view->{directory}->IsChecked ) {
			$main->directory->update_gui;
		}
	}
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
	unless( $_[0]->current->filename ) {
		$_[0]->DeleteChildren( $_[0]->GetRootItem );
		$current_dir = "";
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

#####################################################################
# Event Handlers

sub on_tree_item_activated {
	my ( $self, $event ) = @_;

	my $itemObj = $event->GetItem;
	my $item = $self->GetPlData( $itemObj );

	return if not defined $item;

	if($item->{type} eq "folder"){
		$self->Toggle( $itemObj );
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

sub list_dir {
	my $dir = shift;
	my @data;

	if ( UpdatedDir($dir) ) {

		$CACHED{$dir}->{Change} = (stat $dir)[10];

		if ( opendir my $dh, $dir ) {

			my @items = sort { lc($a) cmp lc($b) } grep { not $SKIP{$_} } readdir $dh;
			@items = grep { not /^\./ } @items unless $CACHED{$dir}->{ShowHidden};

			foreach my $thing (@items) {
				my $path = File::Spec->catfile( $dir, $thing );
				my %item = (
					name => $thing,
					dir  => $dir,
				);
				$item{isDir} = -d $path?1:0;
				push @data, \%item;
			}

			@{$CACHED{$dir}->{Data}} = sort { $b->{isDir} <=> $a->{isDir} } @data;
			closedir $dh;
		}
	}
	return $CACHED{$dir}->{Data};
}

sub UpdatedDir {
	my $dir = shift;
	my $dirChange = (stat $dir)[10];
	return ( !defined $CACHED{$dir} || !$CACHED{$dir}->{Data} || $dirChange != $CACHED{$dir}->{Change} ) ? 1 : 0;
}

sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	my $updated = UpdatedDir( $dir );
	list_dir( $dir );
	return unless @{ $CACHED{$dir}->{Data} };

	my $directory = $self->main->directory;
	my $root = $directory->GetRootItem;

	_update_treectrl( $directory, $CACHED{$dir}->{Data}, $root ) unless defined $current_dir;

	if( (defined( $current_dir ) and $current_dir ne $dir) or $updated){
		$directory->DeleteChildren( $root );
		_update_treectrl( $directory, $CACHED{$dir}->{Data}, $root );
	}

	$current_dir = $dir;

	_update_subdirs( $directory, $root );
}

sub _update_subdirs {
	my ( $self, $root ) = @_;

	my $cookie;
	for my $item ( 1.. $self->GetChildrenCount( $root ) ) {

		( my $node, $cookie ) = $item == 1 ? $self->GetFirstChild( $root ) : $self->GetNextChild( $root, $cookie ) ;

		my $itemData = $self->GetPlData( $node );
		my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );

		if ( defined $itemData->{type} and $itemData->{type} eq 'folder' and defined $CACHED{$current_dir}->{Expanded}->{$path} ) {

			$self->Expand( $node );

			if( UpdatedDir( $path ) ) {
				$self->DeleteChildren( $node );
				_update_treectrl( $self, list_dir( $path ), $node );
			}
			_update_subdirs( $self, $node );
		}
		if ( defined $current_item and $current_item eq $path ) {
			$self->SelectItem( $node );
			$self->ScrollTo( $node );
			undef $current_item;
		}
	}
}

sub _on_tree_begin_label_edit {
	my ( $dir, $event ) = @_;

	# If any restriction, can do veto here
}

sub _on_tree_end_label_edit {
	my ( $self, $event ) = @_;

	my $itemObj = $event->GetItem;
	my $itemData = $self->GetPlData( $itemObj );

	my $newLabel = $event->GetLabel();
		
	my $oldFile = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
	my $newFile = File::Spec->catfile( $itemData->{dir}, $newLabel );

	if ( rename $oldFile, $newFile  ) {
		$itemData->{name} = $newLabel;
	} else {
		$event->Veto();
	}
	$current_item = $newFile;
}

sub _on_tree_item_expanding {
	my ( $self, $event ) = @_;
	my $current = $self->current;
	my $itemObj = $event->GetItem;
	my $itemData = $self->GetPlData( $itemObj );

	if( defined( $itemData->{type} ) && $itemData->{type} eq 'folder' ) {

		my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
		$CACHED{$current_dir}->{Expanded}->{ $path } = 1;

		if( UpdatedDir( $path) or !$self->GetChildrenCount( $itemObj ) ){
			$self->DeleteChildren( $itemObj );
			_update_treectrl( $self, list_dir( $path ), $itemObj );
		}
	}
}

sub _on_tree_item_collapsing {
	my ( $self, $event ) = @_;
	my $itemObj = $event->GetItem;
	my $itemData = $self->GetPlData( $itemObj );
	my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
	delete $CACHED{$current_dir}->{Expanded}->{ $path };
}


sub _on_tree_item_menu {
	my ( $dir, $event ) = @_;

	my $itemObj  = $event->GetItem;
	my $itemData = $dir->GetPlData( $itemObj );
	my $SelectDir = $itemData->{dir};

	if( defined $itemData ) {

		my $menu     = Wx::Menu->new;

		if (	defined ( $itemData->{type} )
			&& $itemData->{type} eq 'folder' )
		{
			my $default = $menu->Append( -1, Wx::gettext( "Expand / Collapse" ) );
			Wx::Event::EVT_MENU(
				$dir, $default,
				sub {
					$dir->Toggle( $itemObj );
				}
			),
		} else {
			my $default = $menu->Append( -1, Wx::gettext("Open File") );
			Wx::Event::EVT_MENU(
				$dir, $default,
				sub {
					$dir->on_tree_item_activated( $event );
				},
			);
		}

		$menu->AppendSeparator();

		my $rename = $menu->Append( -1, Wx::gettext( "Rename" ) );
		Wx::Event::EVT_MENU(
			$dir, $rename,
			sub {
				$dir->EditLabel( $itemObj );
			},
		);


		if (	defined( $itemData->{type} )
			&& ( $itemData->{type} eq 'modules' || $itemData->{type} eq 'pragmata' ) )
		{
			my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
			Wx::Event::EVT_MENU(
				$dir, $pod,
				sub {

					# TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
					require Padre::Wx::DocBrowser;
					my $help = Padre::Wx::DocBrowser->new;
					$help->help( $itemData->{name} );
					$help->SetFocus;
					$help->Show(1);
					return;
				},
			);
		}

		$menu->AppendSeparator();

		#####################################################################
		# Shows / Hides dot started files and folers
if( $^O !~ /^win32/i ){
		my $hiddenFiles = $menu->AppendCheckItem( -1, Wx::gettext( "Show hidden files" ) );

		my $show = $CACHED{ $SelectDir }->{ShowHidden};
		$hiddenFiles->Check( $show );

		Wx::Event::EVT_MENU(
			$dir, $hiddenFiles,
			sub {
				$CACHED{$SelectDir}->{ShowHidden} = !$show;
				delete $CACHED{$SelectDir}->{Data};
				_update_tree_folder( $dir, $itemObj );
			},
		);
}
		#####################################################################
		# Updates the directory listing

		my $reload= $menu->Append( -1, Wx::gettext( "Reload" ) );
		Wx::Event::EVT_MENU(
			$dir, $reload,
			sub {
				_update_tree_folder( $dir, $itemObj );
			}
		);

		my $x = $event->GetPoint->x;
		my $y = $event->GetPoint->y;
		$dir->PopupMenu( $menu, $x, $y );
	}
	return;
}

sub _update_tree_folder {
	my ( $dir, $itemObj ) = @_;
	my $itemData = $dir->GetPlData( $itemObj );
	my $SelectDir = $itemData->{dir};

	# Updates Cache if directory has changed
	list_dir( $SelectDir );

	my $parent = $dir->GetItemParent($itemObj);

	$dir->DeleteChildren($parent);
	_update_treectrl( $dir, $CACHED{$SelectDir}->{Data}, $parent );
}

sub _update_treectrl {
	my ( $self, $data, $root ) = @_;
	foreach my $pkg ( @{$data} ) {
		if ( $pkg->{isDir} ) {
			my $type_elem = $self->AppendItem(
				$root,
				$pkg->{name},
				-1, -1,
				Wx::TreeItemData->new(
					{
						dir => $pkg->{dir},
						name =>$pkg->{name},
						type => 'folder',
					}
				)
			);
			$self->SetItemHasChildren($type_elem,1);
		} else {
			my $branch = $self->AppendItem(
				$root,
				$pkg->{name},
				-1, -1,
				Wx::TreeItemData->new(
					{	dir  => $pkg->{dir},
						name => $pkg->{name},
						type => 'package',
					}
				)
			);
		}
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

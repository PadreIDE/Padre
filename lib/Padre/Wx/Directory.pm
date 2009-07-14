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

	$self->Hide;

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
	$_[0]->DeleteAllItems;
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

{
	my %SKIP = map { $_ => 1 } ( '.', '..', '.svn', 'CVS', '.git' );

	sub list_dir {
		my $dir = shift;
		my @data;

		if ( opendir my $dh, $dir ) {
			my @items = sort grep { not $SKIP{$_} } readdir $dh;
			
			foreach my $thing (@items) {
				my $path = File::Spec->catfile( $dir, $thing );
				my %item = (
					name => $thing,
					dir  => $dir,
				);
				$item{isDir} = 1 if -d $path;
				push @data, \%item;
			}
			closedir $dh;
		}
		return \@data;
	}
}

sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	return if $current_dir and $current_dir eq $dir;

	my $dirChange = (stat $dir)[10];
	if ( !defined $CACHED{$dir} || !$CACHED{$dir}->{Data} || $dirChange != $CACHED{$dir}{Change} ) {
		$CACHED{$dir}->{Data} = list_dir($dir);
		$CACHED{$dir}->{Change} = $dirChange;
	}

	return unless @{ $CACHED{$dir}->{Data} };

	my $directory = $self->main->directory;
	$directory->Freeze;
	$directory->clear;

	my $root = $directory->AddRoot(
		Wx::gettext('Directory'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	_update_treectrl( $directory, $CACHED{$dir}->{Data}, $root );

	Wx::Event::EVT_TREE_ITEM_MENU(
		$directory,
		$directory,
		\&_on_tree_item_menu,
	);

	Wx::Event::EVT_TREE_ITEM_EXPANDING(
		$directory,
		$directory,
		\&_on_tree_item_expanding,
	);

	Wx::Event::EVT_TREE_BEGIN_LABEL_EDIT(
		$directory,
		$directory,
		\&_on_tree_begin_label_edit,
	);

	Wx::Event::EVT_TREE_END_LABEL_EDIT(
		$directory,
		$directory,
		\&_on_tree_end_label_edit,
	);

	$directory->GetBestSize;
	$directory->Thaw;
}


sub _on_tree_begin_label_edit {
	my ( $dir, $event ) = @_;

	# If any restriction, can do veto here
}

sub _on_tree_end_label_edit {
	my ( $dir, $event ) = @_;
	my $itemObj = $event->GetItem;
	my $itemData = $dir->GetPlData( $itemObj );

	my $newLabel = $event->GetLabel();
		
	my $oldFile = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
	my $newFile = File::Spec->catfile( $itemData->{dir}, $newLabel );

	if ( rename $oldFile, $newFile  ) {
		$itemData->{name} = $newLabel;
	} else {
		$event->Veto();
	}
}

sub _on_tree_item_expanding {
	my ( $dir, $event ) = @_;
	my $itemData = $dir->GetPlData( $event->GetItem );

	if(	defined( $itemData->{type} )
		&& $itemData->{type} eq 'folder' )
	{
		my $path = File::Spec->catfile( $itemData->{dir}, $itemData->{name} );
		$dir->DeleteChildren( $event->GetItem );
		_update_treectrl( $dir, list_dir($path), $event->GetItem);
	}
}

sub _on_tree_item_menu {
	my ( $dir, $event ) = @_;

	my $itemObj  = $event->GetItem;
	my $itemData = $dir->GetPlData( $itemObj );

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

		my $reload= $menu->Append( -1, Wx::gettext( "Reload" ) );
		Wx::Event::EVT_MENU(
			$dir, $reload,
			sub {
				$dir->update_gui;
			},
		);


		my $x = $event->GetPoint->x;
		my $y = $event->GetPoint->y;
		$dir->PopupMenu( $menu, $x, $y );
	}
	return;
}

sub _update_treectrl {
	my ( $dir, $data, $root ) = @_;
	foreach my $pkg ( @{$data} ) {
		if ( $pkg->{isDir} ) {
			my $type_elem = $dir->AppendItem(
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
			$dir->SetItemHasChildren($type_elem,1);
		} else {
			my $branch = $dir->AppendItem(
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

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
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS | Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE
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

	my $item = $self->GetPlData( $event->GetItem );
	return if not defined $item;

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

my %SKIP = map { $_ => 1 } ( '.', '..', '.svn', 'CVS', '.git' );

sub list_dir {
	my ( $dir, $depth ) = @_;
	my @data;
	$depth ||= 1;

	# Avoid deep recursion
	# TODO: make this more clever then simply stopping after 10 levels
	return if $depth > 10;
	if ( opendir my $dh, $dir ) {
		my @items = sort grep { not $SKIP{$_} } readdir $dh;
		foreach my $thing (@items) {
			my $path = File::Spec->catfile( $dir, $thing );
			my %item = (
				name => $thing,
				dir  => $dir,
			);
			if ( -d $path ) {
				$item{subdir} = list_dir( $path, $depth + 1 );
			}
			push @data, \%item;
		}
	}
	return \@data;
}

sub update_gui {
	my $self    = shift;
	my $current = $self->current;
	$current->ide->wx or return;

	my $filename = $current->filename or return;
	my $dir = Padre::Util::get_project_dir($filename)
		|| File::Basename::dirname($filename);

	# TODO empty CACHE if forced ?
	# TODO how to recognize real change in ?
	return if $current_dir and $current_dir eq $dir;
	unless ( $CACHED{$dir} ) {
		$CACHED{$dir} = list_dir($dir);
	}

	return unless @{ $CACHED{$dir} };

	my $directory = $self->main->directory;
	$directory->Freeze;
	$directory->clear;

	my $root = $directory->AddRoot(
		Wx::gettext('Directory'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	_update_treectrl( $directory, $CACHED{$dir}, $root );

	Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK(
		$directory,
		$directory,
		\&_on_tree_item_right_click,
	);

	$directory->GetBestSize;

	$directory->Thaw;
}

sub _on_tree_item_right_click {
	my ( $dir, $event ) = @_;

	my $showMenu = 0;
	my $menu     = Wx::Menu->new;
	my $itemData = $dir->GetPlData( $event->GetItem );

	if ( defined $itemData ) {
		my $goTo = $menu->Append( -1, Wx::gettext("Open File") );
		Wx::Event::EVT_MENU(
			$dir, $goTo,
			sub {
				$dir->on_tree_item_activated($event);
			},
		);
		$showMenu++;
	}

	if (   defined($itemData)
		&& defined( $itemData->{type} )
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
		$showMenu++;
	}

	if ( $showMenu > 0 ) {
		my $x = $event->GetPoint->x;
		my $y = $event->GetPoint->y;
		$dir->PopupMenu( $menu, $x, $y );
	}

	return;
}

sub _update_treectrl {
	my ( $dir, $data, $root ) = @_;

	foreach my $pkg ( @{$data} ) {
		if ( $pkg->{subdir} ) {
			my $type_elem = $dir->AppendItem(
				$root,
				$pkg->{name},
				-1,
				-1,
				Wx::TreeItemData->new
			);
			_update_treectrl( $dir, $pkg->{subdir}, $type_elem );
		} else {
			my $branch = $dir->AppendItem(
				$root,
				$pkg->{name},
				-1, -1,
				Wx::TreeItemData->new(
					{   dir  => $pkg->{dir},
						name => $pkg->{name},
						type => 'package',
					}
				)
			);
			$dir->Expand($branch);
		}
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

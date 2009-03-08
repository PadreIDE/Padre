package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use Params::Util   qw{_INSTANCE};
use Padre::Wx      ();
use Padre::Current ();
use File::Basename ();

our $VERSION = '0.28';
our @ISA     = 'Wx::TreeCtrl';

sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS  
	);
	$self->SetIndent(10);
	$self->{force_next} = 0;

	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self,
		sub {
			$self->on_tree_item_activated($_[1]);
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
	}
	else {
		return $self->{force_next};
	}
}


#####################################################################
# Event Handlers

sub on_tree_item_activated {
	my ($self, $event) = @_;


	my $item = $self->GetPlData( $event->GetItem );
	return if not defined $item;

	my $path = File::Spec->catfile($item->{dir}, $item->{name});
	return if not defined $path;
	my $main = $self->main;
	if (my $id = $main->find_editor_of_file($path)) {
		my $page = $main->notebook->GetPage($id);
		$page->SetFocus;
	} else {
		$main->setup_editors($path);
	}
	return;
}

sub list_dir {
	my ($dir) = @_;
	my @data;
	if (opendir my $dh, $dir) {
		my @items = sort readdir $dh;
		foreach my $thing (@items)  {
			next if $thing eq '.' or $thing eq '..';
			push @data, {
				name => $thing,
				dir  => $dir,
			};
		}
	}
	return \@data;
}

sub update_gui {
	return if not Padre->ide->wx;
	my $directory   = Padre->ide->wx->main->directory;
	$directory->clear;

	my $filename = Padre::Current->filename;
	return if not $filename;
	my $dir = File::Basename::dirname($filename);
	my $data = list_dir($dir);
	return if not @$data;

	my $root = $directory->AddRoot(
		Wx::gettext('Directory'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	_update_treectrl( $directory, $data, $root );

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

	my $menu = Wx::Menu->new;
	my $itemData = $dir->GetPlData( $event->GetItem );

	if ( defined($itemData) ) {
		my $goTo = $menu->Append( -1, Wx::gettext("Open File") );
		Wx::Event::EVT_MENU( $dir, $goTo,
			sub { $dir->on_tree_item_activated($event); },
		);
		$showMenu++;
	}

	if ( 
		defined($itemData)
		&& defined( $itemData->{type} ) 
		&& ( $itemData->{type} eq 'modules' || $itemData->{type} eq 'pragmata' )
	) {
		my $pod = $menu->Append( -1, Wx::gettext("Open &Documentation") );
		Wx::Event::EVT_MENU( $dir, $pod,
			sub {
				# TODO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
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

	foreach my $pkg ( @{ $data } ) {
		my $branch = $dir->AppendItem(
			$root,
			$pkg->{name},
			-1,
			-1,
			Wx::TreeItemData->new( {
				dir  => $pkg->{dir},
				name => $pkg->{name},
				type => 'package',
			} )
		);
#		foreach my $type ( qw(pragmata modules methods) ) {
#			_add_subtree( $dir, $pkg, $type, $branch );
#		}
		$dir->Expand($branch);
	}

	return;
}

sub _add_subtree {
	my ( $dir, $pkg, $type, $root ) = @_;

	my $type_elem = undef;
	if ( defined($pkg->{$type}) && scalar(@{ $pkg->{$type} }) > 0 ) {
		$type_elem = $dir->AppendItem(
			$root,
			ucfirst($type),
			-1,
			-1,
			Wx::TreeItemData->new()
		);

		my @sorted_entries = ();
		if ( $type eq 'methods' ) {
			my $config = Padre->ide->config;
			if ( $config->main_functions_order eq 'original' ) {
				# That should be the one we got
				@sorted_entries = @{ $pkg->{$type} };
			}
			elsif ( $config->main_functions_order eq 'alphabetical_private_last' ) {
				# ~ comes after \w
				my @pre = map { $_->{name} =~ s/^_/~/; $_ } @{ $pkg->{$type} };
				@pre = sort { $a->{name} cmp $b->{name} } @pre;
				@sorted_entries = map { $_->{name} =~ s/^~/_/; $_ } @pre;
			}
			else {
				# Alphabetical (aka 'abc')
				@sorted_entries = sort { $a->{name} cmp $b->{name} } @{ $pkg->{$type} };
			}
		}
		else {
			@sorted_entries = sort { $a->{name} cmp $b->{name} } @{ $pkg->{$type} };
		}

		foreach my $item ( @sorted_entries ) {
			$dir->AppendItem(
				$type_elem,
				$item->{name},
				-1,
				-1,
				Wx::TreeItemData->new( {
					dir  => $item->{dir},
					name => $item->{name},
					type => $type,
				} )
			);
		}
	}
	if ( defined $type_elem ) {
		if ( $type eq 'methods' ) {
			$dir->Expand($type_elem);
		}
		else {
			$dir->Collapse($type_elem);
		}
	}

	return;
}


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

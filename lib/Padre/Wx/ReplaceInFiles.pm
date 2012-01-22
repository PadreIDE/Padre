package Padre::Wx::ReplaceInFiles;

# Class for the output window at the bottom of Padre that is used to display
# results from Replace in Files searches.

use 5.008;
use strict;
use warnings;
use File::Spec            ();
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx::TreeCtrl   ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Padre::Wx::TreeCtrl
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$panel,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TR_SINGLE | Wx::TR_FULL_ROW_HIGHLIGHT | Wx::TR_HAS_BUTTONS | Wx::CLIP_CHILDREN
	);

	# Create the image list
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{images} = {
		folder => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_FOLDER',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		file => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_NORMAL_FILE',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		result => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_FORWARD',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		root => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_HELP_FOLDER',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
	};
	$self->AssignImageList($images);

	# Inialise statistics
	$self->{files}   = 0;
	$self->{matches} = 0;

	return $self;
}





######################################################################
# Search Methods

sub replace {
	my $self  = shift;
	my %param = @_;

	# If we are given a root and no project, and the root path
	# is precisely the root of a project, switch so that the search
	# will automatically pick up the manifest/skip rules for it.
	if ( defined $param{root} and not exists $param{project} ) {
		my $project = $self->ide->project_manager->project( $param{root} );
		$param{project} = $project if $project;
	}

	# Kick off the replace task
	$self->task_reset;
	$self->task_request(
		task       => 'Padre::Task::ReplaceInFiles',
		on_message => 'replace_message',
		on_finish  => 'replace_finish',
		dryrun     => 0,
		%param,
	);
	$self->clear;

	my $root = $self->AddRoot('Root');
	$self->SetItemText(
		$root,
		sprintf( Wx::gettext(q{Replacing '%s' in '%s'...}), $param{search}->find_term, $param{root} )
	);
	$self->SetItemImage( $root, $self->{images}->{root} );

	return 1;
}

sub replace_message {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $path = shift;
	my $root = $self->GetRootItem;

	# Lock the tree to reduce flicker and prevent auto-scrolling
	my $lock = $self->lock_scroll;

	# Add the file node to the tree.
	# Added to avoid crash in next line.
	require Padre::Wx::Directory::Path;
	my $name  = $path->name;
	my $dir   = File::Spec->catfile( $task->root, $path->dirs );
	my $full  = File::Spec->catfile( $task->root, $path->path );
	my $count = shift or next;
	if ( $count > 0 ) {
		my $label = sprintf( Wx::gettext('%s (%s changed)'), $full, $count );
		my $file = $self->AppendItem( $root, $label, $self->{images}->{file} );
		$self->SetPlData( $file, { dir => $dir, file => $name } );

		# Update statistics
		$self->{matches} += $count;
		$self->{files}   += 1;
	} else {
		my $label = sprintf( Wx::gettext('%s (crashed)'), $full );
		my $file = $self->AppendItem( $root, $label, $self->{images}->{file} );
		$self->SetItemTextColour( $file => Padre::Wx::color('990000') );
		$self->SetItemBold( $file => 1 );
		$self->SetPlData( $file => { dir => $dir, file => $name } );
	}

	# Ensure the root is expanded
	$self->Expand($root);

	return 1;
}

sub replace_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $term = $task->{search}->find_term;
	my $dir  = $task->{root};

	# Display the summary
	my $root = $self->GetRootItem;
	if ( $self->{files} ) {
		$self->SetItemText(
			$root,
			sprintf(
				Wx::gettext(q{Replace complete, found '%s' %d time(s) in %d file(s) inside '%s'}),
				$term,
				$self->{matches},
				$self->{files},
				$dir,
			)
		);
	} else {
		$self->SetItemText(
			$root,
			sprintf(
				Wx::gettext(q{No results found for '%s' inside '%s'}),
				$term,
				$dir,
			)
		);
	}

	return 1;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	Wx::gettext('Replace in Files');
}

sub view_close {
	$_[0]->task_reset;
	$_[0]->main->show_replaceinfiles(0);
}





#####################################################################
# General Methods

sub select {
	my $self   = shift;
	my $parent = $self->GetParent;
	$parent->SetSelection( $parent->GetPageIndex($self) );
	return;
}

sub clear {
	my $self = shift;
	$self->{files}   = 0;
	$self->{matches} = 0;
	$self->DeleteAllItems;
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

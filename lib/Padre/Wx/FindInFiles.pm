package Padre::Wx::FindInFiles;

# Class for the output window at the bottom of Padre that is used to display
# results from Find in Files searches.

use 5.008;
use strict;
use warnings;
use File::Basename                      ();
use File::Spec                          ();
use Params::Util                        ();
use Padre::Role::Task                   ();
use Padre::Wx::Role::View               ();
use Padre::Wx::Role::Main               ();
use Padre::Wx                           ();
use Padre::Wx::TreeCtrl                 ();
use Padre::Wx::FBP::FindInFiles::Output ();
use Padre::Logger;

our $VERSION = '0.92';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::FBP::FindInFiles::Output
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	my $self = $class->SUPER::new($panel);

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
	};
	my $tree = $self->{tree};
	$tree->AssignImageList($images);

	# Set the bitmap button icons
	$self->{repeat}->SetBitmapLabel( Padre::Wx::Icon::find('actions/view-refresh') );
	$self->{stop}->SetBitmapLabel( Padre::Wx::Icon::find('actions/stop') );
	$self->{expand_all}->SetBitmapLabel( Padre::Wx::Icon::find('actions/zoom-in') );
	$self->{collapse_all}->SetBitmapLabel( Padre::Wx::Icon::find('actions/zoom-out') );

	# Set the button tooltips
	$self->{stop}->SetToolTip( Wx::gettext('Stop search') );
	$self->{expand_all}->SetToolTip( Wx::gettext('Expand all') );
	$self->{collapse_all}->SetToolTip( Wx::gettext('Collapse all') );

	# Create the render data store and timer
	$self->{search_task}     = undef;
	$self->{search_queue}    = [];
	$self->{search_timer_id} = Wx::NewId();
	$self->{search_timer}    = Wx::Timer->new(
		$self,
		$self->{search_timer_id},
	);
	Wx::Event::EVT_TIMER(
		$self,
		$self->{search_timer_id},
		sub {
			$self->search_timer( $_[1], $_[2] );
		},
	);
	$self->{last_search} = undef;

	# Initialise statistics
	$self->{files}   = 0;
	$self->{matches} = 0;

	return $self;
}





######################################################################
# Padre::Role::Task Methods

sub task_reset {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# As a convenience, reset any timers used by task message processing
	$self->{search_task}  = undef;
	$self->{search_queue} = [];
	$self->{search_timer}->Stop;

	# Reset normally as well
	$self->SUPER::task_reset(@_);
}





######################################################################
# Search Methods

sub search {
	my $self  = shift;
	my %param = @_;

	# If we are given a root and no project, and the root path
	# is precisely the root of a project, switch so that the search
	# will automatically pick up the manifest/skip rules for it.
	if ( defined $param{root} and not exists $param{project} ) {
		my $project = $self->ide->project_manager->project( $param{root} );
		$param{project} = $project if $project;
	}

	# Kick off the search task
	$self->task_reset;
	$self->clear;
	$self->task_request(
		task       => 'Padre::Task::FindInFiles',
		on_run     => 'search_run',
		on_message => 'search_message',
		on_finish  => 'search_finish',
		%param,
	);

	$self->{tree}->AddRoot('Root');
	$self->{status}->SetLabel(
		sprintf(
			Wx::gettext(q{Searching for '%s' in '%s'...}),
			$param{search}->find_term,
			$param{root},
		)
	);

	# Start the render timer
	$self->{search_timer}->Start(250);

	# Enable the stop button
	$self->{stop}->Enable;

	return 1;
}

sub search_run {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	$self->{search_task} = $task;
}

sub search_message {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	push @{ $self->{search_queue} }, [@_];
}

sub search_timer {
	TRACE( $_[0] ) if DEBUG;
	$_[0]->search_render;
}

sub search_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Render any final results
	$self->{search_timer}->Stop;
	$self->search_render;

	# Display the summary
	my $task = delete $self->{search_task} or return;
	$self->{last_search} = $task->{search};
	my $term = $task->{search}->find_term;
	my $dir  = $task->{root};
	my $tree = $self->{tree};
	if ( $self->{files} ) {
		$self->{status}->SetLabel(
			sprintf(
				Wx::gettext(q{Search complete, found '%s' %d time(s) in %d file(s) inside '%s'}),
				$term,
				$self->{matches},
				$self->{files},
				$dir,
			)
		);
	} else {
		$self->{status}->SetLabel(
			sprintf(
				Wx::gettext(q{No results found for '%s' inside '%s'}),
				$term,
				$dir,
			)
		);
	}

	# Clear support variables
	$self->task_reset;

	# Enable the repeat search button again
	$self->{repeat}->Enable;
	$self->{repeat}->SetToolTip( sprintf( Wx::gettext(q{Search again for '%s'}), $term ) );

	# Disable the stop button
	$self->{stop}->Disable;

	# Only enable collapse all when we have results
	if ( $self->{files} ) {
		$self->{collapse_all}->Enable;
	}

	return 1;
}

sub search_render {
	TRACE( $_[0] ) if DEBUG;
	my $self  = shift;
	my $tree  = $self->{tree};
	my $root  = $tree->GetRootItem;
	my $task  = $self->{search_task} or return;
	my $queue = $self->{search_queue};
	return unless @$queue;

	# Lock the tree to reduce flicker and prevent auto-scrolling
	my $lock = $tree->lock_scroll;

	# Added to avoid crashes when calling methods on path objects
	require Padre::Wx::Directory::Path;

	# Add the file nodes to the tree
	foreach my $entry (@$queue) {
		my $path  = shift @$entry;
		my $name  = $path->name;
		my $dir   = File::Spec->catfile( $task->root, $path->dirs );
		my $full  = File::Spec->catfile( $task->root, $path->path );
		my $lines = scalar @$entry;
		my $label =
			$lines > 1
			? sprintf(
			Wx::gettext('%s (%s results)'),
			$full,
			$lines,
			)
			: $full;
		my $file = $tree->AppendItem( $root, $label, $self->{images}->{file} );
		$tree->SetPlData(
			$file,
			{   dir  => $dir,
				file => $name,
			}
		);

		# Add the lines nodes to the tree
		foreach my $row (@$entry) {

			# Tabs don't display properly
			$row->[1] =~ s/\t/    /g;
			my $line = $tree->AppendItem(
				$file,
				$row->[0] . ': ' . $row->[1],
				$self->{images}->{result},
			);
			$tree->SetPlData(
				$line,
				{   dir  => $dir,
					file => $name,
					line => $row->[0],
					msg  => $row->[1],
				}
			);
		}

		# Expand nodes
		$tree->Expand($root) unless $self->{files};
		$tree->Expand($file);

		# Update statistics
		$self->{matches} += $lines;
		$self->{files}   += 1;

		# Ensure both the root and the new file are expanded
	}

	# Flush the pending queue
	$self->{search_queue} = [];

	return 1;
}

# Handle the clicking of a find result
sub on_find_result_clicked {
	my ( $self, $event ) = @_;

	my $item_data = $self->{tree}->GetPlData( $event->GetItem ) or return;
	my $dir       = $item_data->{dir}                           or return;
	my $file      = $item_data->{file}                          or return;
	my $line      = $item_data->{line};
	my $msg = $item_data->{msg} || '';

	if ( defined $line ) {
		$self->open_file_at_line( File::Spec->catfile( $dir, $file ), $line - 1 );
	} else {
		$self->open_file_at_line( File::Spec->catfile( $dir, $file ) );
	}

	return;
}

# Opens the file at the correct line position
# If no line is given, the function just opens the file
# and sets the focus to it.
sub open_file_at_line {
	my ( $self, $file, $line ) = @_;

	return unless -f $file;
	my $main = $self->main;

	# Try to open the file now
	my $editor;
	if ( defined( my $page_id = $main->editor_of_file($file) ) ) {
		$editor = $main->notebook->GetPage($page_id);
	} else {
		$main->setup_editor($file);
		if ( defined( my $page_id = $main->editor_of_file($file) ) ) {
			$editor = $main->notebook->GetPage($page_id);
		}
	}

	# Center the current position on the found result's line if an editor is found.
	# NOTE: we are EVT_IDLE event to make sure we can do that after a file is opened.
	if ($editor) {
		Wx::Event::EVT_IDLE(
			$self,
			sub {
				if ( defined($line) ) {
					$editor->EnsureVisible($line);
					$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
				}
				$editor->SetFocus;
				Wx::Event::EVT_IDLE( $self, undef );
			},
		);
	}

	return;
}

# Called when the "Repeat" button is clicked
sub on_repeat_click {
	my ( $self, $event ) = @_;

	my $last_search = $self->{last_search} or return;
	my $main = $self->main;

	require Padre::Wx::Dialog::FindInFiles;
	my $findinfiles = Padre::Wx::Dialog::FindInFiles->new($main);
	$main->findinfiles->search(
		root   => $findinfiles->find_directory->SaveValue,
		search => $last_search,
	);
	$findinfiles->Destroy;
}

# Called when the "Expand all" button is clicked
sub on_expand_all_click {
	my ( $self, $event ) = @_;

	my $tree = $self->{tree};
	my $root = $tree->GetRootItem;
	my ( $child, $cookie ) = $tree->GetFirstChild($root);
	while ( $child->IsOk ) {
		$tree->Expand($child);
		( $child, $cookie ) = $tree->GetNextChild( $root, $cookie );
	}

	$self->_flip_button_state;
}

# Called when the "Collapse all" button is clicked
sub on_collapse_all_click {
	my ( $self, $event ) = @_;

	my $tree = $self->{tree};
	my $root = $tree->GetRootItem;
	my ( $child, $cookie ) = $tree->GetFirstChild($root);
	while ( $child->IsOk ) {
		$tree->Collapse($child);
		( $child, $cookie ) = $tree->GetNextChild( $root, $cookie );
	}

	$self->_flip_button_state;
}

sub _flip_button_state {
	my $self = shift;

	if ( $self->{expand_all}->IsEnabled ) {
		$self->{expand_all}->Disable;
		$self->{collapse_all}->Enable;
	} else {
		$self->{expand_all}->Enable;
		$self->{collapse_all}->Disable;
	}
}

# Called when the "Stop search" button is clicked
sub on_stop_click {
	my $self = shift;

	$self->task_reset;
	$self->{stop}->Disable;
}

######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	$_[0]->task_reset;
	$_[0]->main->show_findinfiles(0);
}





#####################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Find in Files');
}

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

	$self->{tree}->DeleteAllItems;
	$self->{repeat}->Disable;
	$self->{expand_all}->Disable;
	$self->{collapse_all}->Disable;
	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

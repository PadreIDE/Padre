package Padre::Wx::Panel::FoundInFiles;

# Class for the output window at the bottom of Padre that is used to display
# results from Find in Files searches.

use 5.008;
use strict;
use warnings;
use File::Spec                   ();
use Params::Util                 ();
use Padre::Wx                    ();
use Padre::Role::Task            ();
use Padre::Wx::Role::View        ();
use Padre::Wx::FBP::FoundInFiles ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::FBP::FoundInFiles
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;
	my $self  = $class->SUPER::new($panel);

	# Create the image list
	my $tree   = $self->{tree};
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
	$tree->AssignImageList($images);

	# Create the render data store and timer
	$self->{search}          = undef;
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

	# Initialise statistics
	$self->{files}   = 0;
	$self->{matches} = 0;

	return $self;
}





######################################################################
# Event Handlers

# Called when the "Stop search" button is clicked
sub stop_clicked {
	my $self = shift;
	$self->task_reset;
	$self->{stop}->Disable;
}

# Called when the "Repeat" button is clicked
sub repeat_clicked {
	my $self = shift;

	# Stop any existing search
	$self->stop_clicked(@_);

	# Run the previous search again
	my $search = $self->{search} or return;
	$self->search(%$search);
}

# Called when the "Expand all" button is clicked
sub expand_all_clicked {
	my $self  = shift;
	my $event = shift;
	my $tree  = $self->{tree};
	my $lock  = $tree->lock_scroll;
	my $root  = $tree->GetRootItem;

	my ( $child, $cookie ) = $tree->GetFirstChild($root);
	while ( $child->IsOk ) {
		$tree->Expand($child);
		( $child, $cookie ) = $tree->GetNextChild( $root, $cookie );
	}

	$self->{expand_all}->Disable;
	$self->{collapse_all}->Enable;
}

# Called when the "Collapse all" button is clicked
sub collapse_all_clicked {
	my $self  = shift;
	my $event = shift;
	my $tree  = $self->{tree};
	my $lock  = $tree->lock_scroll;
	my $root  = $tree->GetRootItem;

	my ( $child, $cookie ) = $tree->GetFirstChild($root);
	while ( $child->IsOk ) {
		$tree->Collapse($child);
		( $child, $cookie ) = $tree->GetNextChild( $root, $cookie );
	}

	$self->{expand_all}->Enable;
	$self->{collapse_all}->Disable;
}

# Handle the clicking of a find result
sub item_clicked {
	my $self  = shift;
	my $event = shift;
	my $tree  = $self->{tree};
	my $item  = $event->GetItem;
	my $data  = $tree->GetPlData($item) or return;
	my $dir   = $data->{dir}            or return;
	my $file  = $data->{file}           or return;
	my $path  = File::Spec->catfile( $dir, $file );

	if ( defined $data->{line} ) {
		my $line = $data->{line} - 1;
		my $text = $data->{text};
		$self->open_file_at_line( $path, $line, $text );
	} else {
		$self->open_file_at_line($path);
	}

	$event->Skip(0);
}





######################################################################
# Padre::Role::Task Methods

sub task_reset {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Reset any timers used by task message processing
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

	# Save a copy of the search in case we want to repeat it
	$self->{search} = { %param };

	# Kick off the search task
	$self->task_reset;
	$self->task_request(
		task       => 'Padre::Task::FindInFiles',
		on_run     => 'search_run',
		on_message => 'search_message',
		on_finish  => 'search_finish',
		%param,
	);

	# After a previous search with many results the clear method can be
	# relatively slow, so instead of calling it first, delay calling it
	# until after we have dispatched the search to the worker thread.
	$self->clear;

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

		# Only enable collapse all when we have results
		$self->{collapse_all}->Enable;
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

	# Enable repeat and disable stop
	$self->{repeat}->Enable;
	$self->{stop}->Disable;

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

	# Added to avoid crashes when calling methods on path objects
	require Padre::Wx::Directory::Path;

	# Add the file nodes to the tree
	my $lock = $tree->lock_scroll;
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
			{
				dir  => $dir,
				file => $name,
			}
		);

		# Add the lines nodes to the tree
		foreach my $row (@$entry) {

			# Tabs don't display properly
			my $msg = $row->[1];
			$msg =~ s/\t/    /g;
			my $line = $tree->AppendItem(
				$file,
				"$row->[0]: $msg",
				$self->{images}->{result},
			);
			$tree->SetPlData(
				$line,
				{
					dir  => $dir,
					file => $name,
					line => $row->[0],
					text => $row->[1],
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

# Opens the file at the correct line position
# If no line is given, the function just opens the file
# and sets the focus to it.
sub open_file_at_line {
	my $self = shift;
	my $file = shift;
	my $main = $self->main;
	return unless -f $file;

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
	if ( $editor and @_ ) {
		my @params = @_;
		Wx::Event::EVT_IDLE(
			$self,
			sub {
				$editor->goto_line_centerize(@params);
				$editor->SetFocus;
				Wx::Event::EVT_IDLE( $_[0], undef );
			},
		);
	}

	return;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	Wx::gettext('Find in Files');
}

sub view_close {
	$_[0]->task_reset;
	$_[0]->main->show_foundinfiles(0);
	$_[0]->clear;
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
	my $tree = $self->{tree};
	my $lock = $tree->lock_scroll;

	$self->{files}   = 0;
	$self->{matches} = 0;
	$self->{repeat}->Disable;
	$self->{expand_all}->Disable;
	$self->{collapse_all}->Disable;
	$tree->DeleteAllItems;

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

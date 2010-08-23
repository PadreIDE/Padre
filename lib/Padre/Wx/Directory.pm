package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use Params::Util                   ();
use Padre::Cache                   ();
use Padre::Role::Task              ();
use Padre::Wx::Role::View          ();
use Padre::Wx::Role::Main          ();
use Padre::Wx::Directory::TreeCtrl ();
use Padre::Wx                      ();
use Padre::Logger;

our $VERSION = '0.69';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::Panel
};

use Class::XSAccessor {
	getters => {
		root   => 'root',
		tree   => 'tree',
		search => 'search',
	},
};





######################################################################
# Constructor

# Creates the Directory Left Panel with a Search field
# and the Directory Browser
sub new {
	TRACE( $_[0] ) if DEBUG;
	my $class = shift;
	my $main  = shift;

	# Create the parent panel, which will contain the search and tree
	my $self = $class->SUPER::new(
		$main->directory_panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	# Modes
	$self->{searching} = 0;

	# Where is the current root directory of the tree
	$self->{root} = '';

	# The list of all files to build into the tree
	$self->{files} = [];

	# The directories in the tree that should be expanded
	$self->{expand} = {};

	# Create the search control
	my $search = $self->{search} = Wx::SearchCtrl->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);
	$search->SetDescriptiveText( Wx::gettext('Search') );

	Wx::Event::EVT_TEXT(
		$self, $search,
		sub {
			shift->on_text(@_);
		},
	);

	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self, $search,
		sub {
			shift->{search}->SetValue('');
		},
	);

	# Create the search control menu
	my $menu = Wx::Menu->new;
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append(
			-1,
			Wx::gettext('Move to other panel')
		),
		sub {
			shift->move;
		}
	);
	$search->SetMenu($menu);

	# Create the tree control
	$self->{tree} = Padre::Wx::Directory::TreeCtrl->new($self);

	# Fill the panel
	my $sizerv = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizerh = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizerv->Add( $self->{search}, 0, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizerv->Add( $self->{tree},   1, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizerh->Add( $sizerv,         1, Wx::wxALL | Wx::wxEXPAND, 0 );

	# Fits panel layout
	$self->SetSizerAndFit($sizerh);
	$sizerh->SetSizeHints($self);

	return $self;
}





######################################################################
# Padre::Role::Task Methods

sub task_request {
	my $self    = shift;
	my $current = $self->current;
	my $project = $current->project;
	if ( $project ) {
		return $self->SUPER::task_request(
			@_,
			project => $project,
		);
	} else {
		return $self->SUPER::task_request(
			@_,
			root => $current->config->main_directory_root,
		);
	}
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	shift->side(@_);
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	TRACE( $_[0] ) if DEBUG;
	shift->main->show_directory(0);
}





######################################################################
# Event Handlers

# If it is a project, caches search field content while it is typed and
# searchs for files that matchs the type word.
sub on_text {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $search = $self->{search};

	if ( $self->{searching} ) {
		if ( $search->IsEmpty ) {
			# Leaving search mode
			$self->{searching} = 0;
			$search->ShowCancelButton(0);
			$self->task_reset;
			$self->refresh_render;
		} else {
			# Changing search term
			$self->find;
		}
	} else {
		if ( $search->IsEmpty ) {
			# Nothing to do
			# NOTE: Why would this even fire?
		} else {
			# Entering search mode
			$self->{expand}    = $self->tree->expanded;
			$self->{searching} = 1;
			$search->ShowCancelButton(1);
			$self->find;
		}
	}

	return 1;
}





######################################################################
# General Methods

# Returns the window label
sub gettext_label {
	Wx::gettext('Project');
}

# The search term if we have one
sub term {
	$_[0]->{search}->GetValue;
}

# Are we in search mode?
sub searching {
	$_[0]->{search}->IsEmpty ? 0 : 1;
}

# Updates the gui, so each compoment can update itself
# according to the new state.
sub clear {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');
	$self->{search}->SetValue('');
	$self->{search}->ShowCancelButton(0);
	$self->{tree}->DeleteChildren( $self->{tree}->GetRootItem );
	return;
}





######################################################################
# Directory Tree Methods

# Updates the gui if needed, calling Searcher and Browser respectives
# refresh function.
# Called outside Directory.pm, on directory browser focus and item dragging
sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# NOTE: Without a file open, Padre does not consider itself to
	# have a "current project". We should probably try to find a way
	# to correct this in future.
	my $current = $self->current;
	my $config  = $current->config;
	my $project = $current->project;
	my $root    = $project ? $project->root : $config->main_directory_root;
	my @options = (
		order => $config->main_directory_order,
	);

	# Before we change anything, store the expansion state
	unless ( $self->searching ) {
		$self->{expand} = $self->tree->expanded;
	}

	# Switch project states if needed
	unless ( $self->{root} eq $root ) {
		my $ide = $current->ide;

		# Save the current model data to the cache
		# if we potentially need it again later.
		if ( $ide->project_exists( $self->{root} ) ) {
			my $stash = Padre::Cache::stash(
				__PACKAGE__,
				$ide->project( $self->{root} ),
			);
			%$stash = (
				root   => $self->{root},
				files  => $self->{files},
				expand => $self->{expand},
			);
		}

		# Flush the now-unusable state
		$self->{root}   = $root;
		$self->{files}  = [];
		$self->{expand} = {};

		# Do we have an (out of date) cached state we can use?
		# If so, display it immediately and update it later.
		if ($project) {
			my $stash = Padre::Cache::stash(
				__PACKAGE__,
				$project,
			);
			if ( $stash->{root} ) {

				# We have a cached state
				$self->{files}  = $stash->{files};
				$self->{expand} = $stash->{expand};
			}
		}

		# Flush the search box and rerender the tree
		$self->{search}->SetValue('');
		$self->{search}->ShowCancelButton(0);
		$self->refresh_render;

		# Trigger the refresh task to update the temporary state
		$self->task_request(
			task      => 'Padre::Wx::Directory::Task',
			on_finish => 'refresh_finish',
			recursive => 1,
			@options,
		);

	}

	return 1;
}

sub refresh_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	$self->{files} = $task->{model};
	$self->refresh_render;
}

# This is a primitive first attempt to get familiar with the tree API
sub refresh_render {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $tree   = $self->tree;
	my $root   = $tree->GetRootItem;
	my $expand = $self->{expand};

	# Flush the old tree contents
	# TO DO: This is inefficient, upgrade to something that does the
	# equivalent of a treewise diff application, modifying the tree
	# to get the result we want instead of rebuilding it entirely.
	my $lock = $self->main->lock('UPDATE');
	$tree->DeleteChildren($root);

	# Fill the new tree
	my @stack = ();
	my @files = @{$self->{files}};
	while (@files) {
		my $path  = shift @files;
		my $image = $path->type ? 'folder' : 'package';
		while (@stack) {

			# If we are not the child of the deepest element in
			# the stack, move up a level and try again
			last if $tree->GetPlData( $stack[-1] )->is_parent($path);

			# We have finished filling the directory.
			# Now it (maybe) has children, we can expand it.
			my $complete = pop @stack;
			if ( $expand->{ $tree->GetPlData($complete)->unix } ) {
				$tree->Expand($complete);
			}
		}

		# If there is anything left on the stack it is our parent
		my $parent = $stack[-1] || $root;

		# Add the next item to that parent
		my $item = $tree->AppendItem(
			$parent,                      # Parent node
			$path->name,                  # Label
			$tree->{images}->{$image},    # Icon
			-1,                           # Wx Identifier
			Wx::TreeItemData->new($path), # Embedded data
		);

		# If it is a folder, it goes onto the stack
		if ( $path->type == 1 ) {
			push @stack, $item;
		}
	}

	# Apply the same Expand logic above to any remaining stack elements
	while (@stack) {
		my $complete = pop @stack;
		if ( $expand->{ $tree->GetPlData($complete)->unix || 0 } ) {
			$tree->Expand($complete);
		}
	}

	return 1;
}





######################################################################
# Incremental Search Methods

sub find {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	return unless $self->searching;

	# Switch tasks to the find task
	$self->task_reset;
	$self->task_request(
		task       => 'Padre::Wx::Directory::Search',
		on_message => 'find_message',
		on_finish  => 'find_finish',
		filter     => $self->term,
	);

	# Create the find timer
	$self->{find_timer} = Wx::Timer->new(
		$self,
		Padre::Wx::ID_TIMER_DIRECTORY
	);
	Wx::Event::EVT_TIMER(
		$self,
		Padre::Wx::ID_TIMER_ACTIONQUEUE,
		sub {
			$self->find_timer( $_[1], $_[2] );
		},
	);
	$self->{find_timer}->Start(1000);

	# Make sure no existing files are listed
	$self->{tree}->DeleteChildren( $self->{tree}->GetRootItem );

	return;
}

# We have hit a find_message render interval
sub find_timer {
	TRACE( $_[0] ) if DEBUG;
}

# Add any matching file to the tree
sub find_message {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $file = Params::Util::_INSTANCE(shift, 'Padre::Wx::Directory::Path') or return;

	# Find where we need to start creating nodes from
	my $tree   = $self->tree;
	my $cursor = $tree->GetRootItem;
	my @base   = ();
	my @dirs   = $file->path;
	pop @dirs;
	while ( @dirs ) {
		my $name  = shift @dirs;
		my $child = $tree->GetLastChild($cursor);
		if ( $child->IsOk and $tree->GetPlData($child)->name eq $name ) {
			$cursor = $child;
			push @base, $name;
		} else {
			unshift @dirs, $name;
			last;
		}
	}

	# Will we need to expand anything at the end?
	my $expand = $cursor if @dirs;

	# Because this should never be called from inside some larger
	# update locker, lets risk the use of our own more targetted locking
	# instead of using the official main->lock functionality.
	# NOTE: It will HOPEFULLY be faster than the main one.
	# NOTE: If we could avoid the scrollback snapping around on its own,
	# we probably wouldn't need this lock at all.
	my $scroll = $tree->GetScrollPos( Wx::wxVERTICAL );
	my $lock   = Wx::WindowUpdateLocker->new( $tree );

	# Create any new child directories
	while ( @dirs  ) {
		my $name = shift @dirs;
		my $path = Padre::Wx::Directory::Path->directory( @base, $name );
		my $item = $tree->AppendItem(
			$cursor,                      # Parent node
			$path->name,                  # Label
			$tree->{images}->{folder},    # Icon
			-1,                           # Wx identifier
			Wx::TreeItemData->new($path), # Embedded data
		);
		$cursor = $item;
		push @base, $name;
	}

	# Create the file itself
	$tree->AppendItem(
		$cursor,
		$file->name,
		$tree->{images}->{package},
		-1,
		Wx::TreeItemData->new($file),
	);

	# Expand anything we created.
	$tree->ExpandAllChildren( $expand ) if $expand;

	# Make sure the scroll position has not changed
	$tree->SetScrollPos( Wx::wxVERTICAL, 0, 0 );

	return 1;
}

sub find_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;

	# Done... but we don't need to do anything
}





######################################################################
# Panel Migration (Experimental)

# What side of the application are we on
sub side {
	my $self  = shift;
	my $panel = $self->GetParent;
	if ( $panel->isa('Padre::Wx::Left') ) {
		return 'left';
	}
	if ( $panel->isa('Padre::Wx::Right') ) {
		return 'right';
	}
	die "Bad parent panel";
}

# Moves the panel to the other side.
# To prevent corrupting the layout engine we do this in a specific order.
# Hide, Reconfigure, Show
# TO DO: This results in loss of all state, and the need to rescan the tree.
# Come up with a saner approach to migrating views between arbitrary panels
# that we can expand out so all views can potentially be moved around.
sub move {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $main   = $self->main;
	my $config = $main->config;
	my $side   = $config->main_directory_panel;
	$main->show_directory(0);
	if ( $side eq 'left' ) {
		$config->apply( main_directory_panel => 'right' );
	} elsif ( $side eq 'right' ) {
		$config->apply( main_directory_panel => 'left' );
	} else {
		die "Bad main_directory_panel setting '$side'";
	}
	$main->show_directory(1);
	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

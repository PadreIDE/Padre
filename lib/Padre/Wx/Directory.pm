package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use Params::Util                   ();
use Padre::Current                 ();
use Padre::Util                    ();
use Padre::Feature                 ();
use Padre::Role::Task              ();
use Padre::Wx::Role::Dwell         ();
use Padre::Wx::Role::View          ();
use Padre::Wx::Role::Main          ();
use Padre::Wx::Directory::TreeCtrl ();
use Padre::Wx                      ();
use Padre::Logger;

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::Dwell
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::Panel
};

use constant TIMER_DIRECTORY => Wx::NewId();

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

	# Where is the current root directory of the tree
	$self->{root} = '';

	# Modes (browse or search)
	$self->{searching} = 0;

	# Flag to ignore tree events when an automated process is
	# making large numbers of automated changes.
	$self->{ignore} = 0;

	# Create the search control
	my $search = $self->{search} = Wx::SearchCtrl->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);

	# Set the descriptive text for the search button.
	# This line is causing an error on Ubuntu due to some Wx problems.
	# see https://bugs.launchpad.net/ubuntu/+source/padre/+bug/485012
	# Supporting Ubuntu seems to be more important than having this text:
	if ( Padre::Util::DISTRO() ne 'UBUNTU' ) {
		$search->SetDescriptiveText( Wx::gettext('Search') );
	}

	# Use a long and obvious 3 second dwell timer for text events
	Wx::Event::EVT_TEXT(
		$self, $search,
		sub {
			return if $_[0]->{ignore};
			$_[0]->dwell_start( 'on_text', 333 );
		},
	);

	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self, $search,
		sub {
			return if $_[0]->{ignore};
			$_[0]->{search}->SetValue('');

			# Don't wait for dwell in this case,
			# shortcut and trigger immediately.
			$_[0]->dwell_stop('on_text');
			$_[0]->on_text;
		},
	);

	# Create the search control menu
	$search->SetMenu( $self->new_menu );

	# Create the tree control
	$self->{tree} = Padre::Wx::Directory::TreeCtrl->new($self);
	$self->{tree}->SetPlData(
		$self->{tree}->GetRootItem,
		Padre::Wx::Directory::Path->directory,
	);
	Wx::Event::EVT_TREE_ITEM_EXPANDED(
		$self,
		$self->{tree},
		sub {
			return if $_[0]->{ignore};
			shift->on_expand(@_);
		}
	);

	# Fill the panel
	my $sizerv = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizerh = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizerv->Add( $self->{search}, 0, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizerv->Add( $self->{tree},   1, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizerh->Add( $sizerv,         1, Wx::wxALL | Wx::wxEXPAND, 0 );

	# Fits panel layout
	$self->SetSizerAndFit($sizerh);
	$sizerh->SetSizeHints($self);

	if (Padre::Feature::STYLE_GUI) {
		$self->recolour;
	}

	return $self;
}

# We need to create the menu whenever our locale changes
sub new_menu {
	my $self = shift;
	my $menu = Wx::Menu->new;

	Wx::Event::EVT_MENU(
		$self,
		$menu->Append(
			-1,
			Wx::gettext('Refresh'),
		),
		sub {
			$_[0]->rebrowse;
		},
	);

	$menu->AppendSeparator;

	Wx::Event::EVT_MENU(
		$self,
		$menu->Append(
			-1,
			Wx::gettext('Move to other panel'),
		),
		sub {
			$_[0]->move;
		},
	);

	return $menu;
}





######################################################################
# Padre::Role::Task Methods

sub task_request {
	my $self    = shift;
	my $current = $self->current;
	my $project = $current->project;
	unless ( defined $project ) {
		$project = $current->ide->project_manager->project( $current->config->main_directory_root );
	}
	return $self->SUPER::task_request(
		@_,
		project => $project,
	);
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
	$_[0]->task_reset;
	$_[0]->dwell_stop('on_text'); # Just in case
	$_[0]->main->show_directory(0);
}





######################################################################
# Event Handlers

# If it is a project, caches search field content while it is typed and
# searchs for files that matchs the type word.
sub on_text {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $search = $self->{search};

	# Operations in here often trigger secondary event triggers that
	# we definitely don't want to fire. Temporarily suppress them.
	$self->{ignore}++;

	if ( $self->{searching} ) {
		if ( $search->IsEmpty ) {

			# Leaving search mode
			TRACE("Leaving search mode") if DEBUG;
			$self->{searching} = 0;
			$self->task_reset;
			$self->clear;
			$self->refill;
			$self->rebrowse;
		} else {

			# Changing search term
			TRACE("Changing search term") if DEBUG;
			$self->find;
		}
	} else {
		if ( $search->IsEmpty ) {

			# Nothing to do
			# NOTE: I don't understand why this should ever fire,
			# but it does seem to fire very late when the directory
			# browser changes projects directories.
			# TRACE("WARNING: This should never fire") if DEBUG;
		} else {

			# Entering search mode
			TRACE("Entering search mode") if DEBUG;
			$self->{files}     = $self->tree->GetChildrenPlData;
			$self->{expand}    = $self->tree->expanded;
			$self->{searching} = 1;
			$search->ShowCancelButton(1);
			$self->find;
		}
	}

	# Stop ignoring user events
	$self->{ignore}--;

	return 1;
}

sub on_expand {
	my $self  = shift;
	my $event = shift;
	my $item  = $event->GetItem;
	my $path  = $self->{tree}->GetPlData($item);
	return $self->browse($path);
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

# Pick up colouring from the current editor style
sub recolour {
	my $self   = shift;
	my $config = $self->config;

	# Load the editor style
	require Padre::Wx::Editor;
	my $data = Padre::Wx::Editor::data( $config->editor_style ) or return;

	# Find the colours we need
	my $foreground = $data->{padre}->{colors}->{PADRE_BLACK}->{foreground};
	my $background = $data->{padre}->{background};

	# Apply them to the widgets
	if ( defined $foreground and defined $background ) {
		$foreground = Padre::Wx::color($foreground);
		$background = Padre::Wx::color($background);

		$self->{tree}->SetForegroundColour($foreground);
		$self->{tree}->SetBackgroundColour($background);

		# $self->{search}->SetForegroundColour($foreground);
		# $self->{search}->SetBackgroundColour($background);
	}

	return 1;
}

# Refill the tree from storage
sub refill {
	my $self   = shift;
	my $tree   = $self->{tree};
	my $root   = $tree->GetRootItem;
	my $files  = delete $self->{files} or return;
	my $expand = delete $self->{expand} or return;
	my $lock   = $self->main->lock('UPDATE');
	my @stack  = ();
	shift @$files;

	# Suppress events while rebuilding the tree
	$self->{ignore}++;

	foreach my $path (@$files) {
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
			$parent,                           # Parent
			$path->name,                       # Label
			$tree->{images}->{ $path->image }, # Icon
			-1,                                # Icon (Selected)
			Wx::TreeItemData->new($path),      # Embedded data
		);

		# If it is a folder, it goes onto the stack
		if ( $path->type == 1 ) {
			push @stack, $item;
		}
	}

	# Apply the same Expand logic above to any remaining stack elements
	while (@stack) {
		my $complete = pop @stack;
		if ( $expand->{ $tree->GetPlData($complete)->unix } ) {
			$tree->Expand($complete);
		}
	}

	# If we moved during the fill, move back
	my $first = ( $tree->GetFirstChild($root) )[0];
	$tree->ScrollTo($first) if $first->IsOk;

	# End suppressing events
	$self->{ignore}--;

	return 1;
}





######################################################################
# Directory Tree Methods

# Updates the gui if needed, calling Searcher and Browser respectives
# refresh function.
# Called outside Directory.pm, on directory browser focus and item dragging
sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self    = shift;
	my $current = Padre::Current::_CURRENT(@_);
	my $manager = $current->ide->project_manager;

	# NOTE: Without a file open, Padre does not consider itself to
	# have a "current project". We should probably try to find a way
	# to correct this in future.
	# NOTE: There's a semi-working hacky fix just for the directory
	# browser here now, but really it needs to be integrated more deeply.
	my $config  = $current->config;
	my $project = $current->project;
	my $root    = $project ? $project->root : $config->main_directory_root;
	if ( $root and not $project ) {
		if ( $manager->project_exists($root) ) {
			$project = $manager->project($root);
		}
	}
	my @options = (
		order => $config->main_directory_order,
	);

	# Switch project states if needed
	unless ( $self->{root} eq $root ) {
		my $manager = $current->ide->project_manager;

		# Save the current model data to the cache
		# if we potentially need it again later.
		if ( $manager->project_exists( $self->{root} ) ) {
			require Padre::Cache;
			my $stash = Padre::Cache->stash(
				__PACKAGE__ => $manager->project( $self->{root} ),
			);
			if ( $self->{searching} ) {

				# Save the stored browse state
				%$stash = (
					root   => $self->{root},
					files  => $self->{files},
					expand => $self->{expand},
				);
			} else {

				# Capture the browse state fresh.
				%$stash = (
					root   => $self->{root},
					files  => $self->tree->GetChildrenPlData,
					expand => $self->tree->expanded,
				);
			}
		}

		# Flush the now-unusable local state
		$self->clear;
		$self->{root}   = $root;
		$self->{files}  = undef;
		$self->{expand} = undef;

		# Do we have an (out of date) cached state we can use?
		# If so, display it immediately and update it later on.
		if ( defined $project ) {
			require Padre::Cache;
			my $stash = Padre::Cache->stash(
				__PACKAGE__ => $project,
			);
			if ( $stash->{root} ) {

				# We have a cached state
				$self->{files}  = $stash->{files};
				$self->{expand} = $stash->{expand};
				$self->refill;
				$self->rebrowse;
			} else {
				$self->task_reset;
				$self->browse;
			}

		} else {
			$self->task_reset;
			$self->browse;
		}
	}

	return 1;
}

sub relocale {
	my $self   = shift;
	my $search = $self->{search};

	# Reset the descriptive text
	if ( Padre::Util::DISTRO() ne 'UBUNTU' ) {
		$search->SetDescriptiveText( Wx::gettext('Search') );
	}

	# Rebuild the menu
	$search->SetMenu( $self->new_menu );

	return 1;
}





######################################################################
# Browse Methods

# Rebrowse issues a browse task for ALL currently expanded nodes in the
# browse tree. This will cause all changes on disk to be reflected in the
# visible browse tree.
sub rebrowse {
	TRACE( $_[0] ) if DEBUG;
	my $self     = shift;
	my $expanded = $self->{tree}->GetExpandedPlData;
	$self->task_reset;
	$self->browse(@$expanded);
}

sub browse {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	return if $self->searching;

	# Switch tasks to the browse task
	$self->task_request(
		task       => 'Padre::Wx::Directory::Browse',
		on_message => 'browse_message',
		on_finish  => 'browse_finish',
		list       => [ @_ ? @_ : Padre::Wx::Directory::Path->directory ],
	);

	return;
}

sub browse_message {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $task   = shift;
	my $parent = shift;

	# Find the parent, discarding the message if we can't find it
	my $tree   = $self->{tree};
	my $cursor = $tree->GetRootItem;
	foreach my $name ( $parent->path ) {

		# Locate the child to descend to.
		# Discard the entire message if the target child doesn't exist.
		$cursor = $tree->GetChildByText( $cursor, $name ) or return 1;
	}

	# Mix the returned files into the existing entries.
	# If there aren't any existing entries, this shortcuts quite nicely.
	my ( $child, $cookie ) = $tree->GetFirstChild($cursor);
	my $position = 0;
	while (@_) {
		if ( $child->IsOk ) {

			# Are we before, after, or a duplicate
			my $chd = $tree->GetPlData($child);
			if ( not defined $_[0] or not defined $chd ) {

				# TODO: this should never happen, but it does and it crashes padre in the compare method
				# when calling is_directory on the object.
				warn
					"Something is wrong as one of the directory objects is undef (position=$position, child=$child, chd=$chd)";
				$self->main->error(
					Wx::gettext(
						'The directory browser got an undef object and may stop working now. Please save your work and restart Padre.'
					)
				);
				last;
			}
			my $compare = $self->compare( $_[0], $chd );
			if ( $compare > 0 ) {

				# Deleted entry, remove the current position
				my $delete = $child;
				( $child, $cookie ) = $tree->GetNextChild( $cursor, $cookie );
				$tree->Delete($delete);

			} elsif ( $compare < 0 ) {

				# New entry, insert before the current position
				my $path = shift;
				$tree->InsertItem(
					$cursor,                           # Parent
					$position,                         # Before
					$path->name,                       # Label
					$tree->{images}->{ $path->image }, # Icon
					-1,                                # Icon (Selected)
					Wx::TreeItemData->new($path),      # Embedded data
				);
				$position++;

			} else {

				# Already exists, discard the duplicate
				( $child, $cookie ) = $tree->GetNextChild( $cursor, $cookie );
				$position++;
				shift @_;
			}

		} else {

			# We are past the last entry
			my $path = shift;
			$tree->AppendItem(
				$cursor,                           # Parent
				$path->name,                       # Label
				$tree->{images}->{ $path->image }, # Icon
				-1,                                # Icon (Selected)
				Wx::TreeItemData->new($path),      # Embedded data
			);
		}
	}

	# Remove any deleted trailing entries
	while ( $child->IsOk ) {

		# Deleted entry, remove the current position
		my $delete = $child;
		( $child, $cookie ) = $tree->GetNextChild( $cursor, $cookie );
		$tree->Delete($delete);
	}

	return 1;
}

sub browse_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
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
		TIMER_DIRECTORY
	);
	Wx::Event::EVT_TIMER(
		$self,
		TIMER_DIRECTORY,
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
	my $file = Params::Util::_INSTANCE( shift, 'Padre::Wx::Directory::Path' ) or return;

	# Find where we need to start creating nodes from
	my $tree   = $self->tree;
	my $cursor = $tree->GetRootItem;
	my @base   = ();
	my @dirs   = $file->path;
	pop @dirs;
	while (@dirs) {
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
	my $expand = @dirs ? $cursor : undef;

	# Because this should never be called from inside some larger
	# update locker, lets risk the use of our own more targetted locking
	# instead of using the official main->lock functionality.
	# Allow the lock to release naturally at the end of the method.
	my $lock = $tree->scroll_lock;

	# Create any new child directories
	while (@dirs) {
		my $name = shift @dirs;
		my $path = Padre::Wx::Directory::Path->directory( @base, $name );
		my $item = $tree->AppendItem(
			$cursor,                      # Parent
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
	$tree->ExpandAllChildren($expand) if $expand;

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

# Compare two paths to see which should be first
sub compare {
	my $self  = shift;
	my $left  = shift;
	my $right = shift;
	return ( $right->is_directory <=> $left->is_directory or lc( $left->name ) cmp lc( $right->name ) );
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

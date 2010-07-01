package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use Padre::Cache                   ();
use Padre::Role::Task              ();
use Padre::Wx::Role::View          ();
use Padre::Wx::Role::Main          ();
use Padre::Wx::Directory::TreeCtrl ();
use Padre::Wx                      ();

our $VERSION = '0.66';
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
# Padre::Wx::Role::View Methods

sub view_panel {
	shift->side(@_);
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	shift->main->show_directory(0);
}





######################################################################
# Event Handlers

# If it is a project, caches search field content while it is typed and
# searchs for files that matchs the type word.
sub on_text {
	my $self   = shift;
	my $search = $self->{search};

	# Show or hide the cancel button
	$search->ShowCancelButton( $search->IsEmpty ? 0 : 1 );

	# The changed search state requires a rerender
	$self->render;
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
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');
	$self->{search}->SetValue('');
	$self->{search}->ShowCancelButton(0);
	$self->{tree}->DeleteChildren( $self->{tree}->GetRootItem );
	return;
}

# Updates the gui if needed, calling Searcher and Browser respectives
# refresh function.
# Called outside Directory.pm, on directory browser focus and item dragging
sub refresh {
	my $self = shift;

	# NOTE: Without a file open, Padre does not consider itself to
	# have a "current project". We should probably try to find a way
	# to correct this in future.
	my $current = $self->current;
	my $project = $current->project;
	my $root    = '';
	my @options = ();
	if ($project) {
		$root = $project->root;
		@options = ( project => $project );
	} else {
		$root = $current->config->default_projects_directory;
		@options = ( root => $root );
	}

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
		$self->render;
	}

	# Trigger the refresh task to update the temporary state
	$self->task_request(
		task      => 'Padre::Wx::Directory::Task',
		callback  => 'refresh_response',
		recursive => 1,
		@options,
	);

	return 1;
}

sub refresh_response {
	my $self = shift;
	my $task = shift;
	$self->{files} = $task->{model};
	$self->render;
}

# This is a primitive first attempt to get familiar with the tree API
sub render {
	my $self   = shift;
	my $tree   = $self->tree;
	my $root   = $tree->GetRootItem;
	my $expand = $self->{expand};

	# Prepare search mode if needed
	my $search = $self->searching;
	my @files = $search ? $self->filter( $self->term ) : @{ $self->{files} };

	# Flush the old tree contents
	# TO DO: This is inefficient, upgrade to something that does the
	# equivalent of a treewise diff application, modifying the tree
	# to get the result we want instead of rebuilding it entirely.
	my $lock = $self->main->lock('UPDATE');
	$tree->DeleteChildren($root);

	# Fill the new tree
	my @stack = ();
	while (@files) {
		my $path = shift @files;
		my $image = $path->type ? 'folder' : 'package';
		while (@stack) {

			# If we are not the child of the deepest element in
			# the stack, move up a level and try again
			last if $tree->GetPlData( $stack[-1] )->is_parent($path);

			# We have finished filling the directory.
			# Now it (maybe) has children, we can expand it.
			my $complete = pop @stack;
			if ( $search or $expand->{ $tree->GetPlData($complete)->unix } ) {
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
		if ( $search or $expand->{ $tree->GetPlData($complete)->unix } ) {
			$tree->Expand($complete);
		}
	}

	# When in search mode, force the scroll position to the top after
	# every refresh. It tends to want to scroll to the bottom.
	if ($search) {
		my ( $first, $cookie ) = $tree->GetFirstChild($root);
		$tree->ScrollTo($first) if $first;
	}

	return 1;
}

# Filter the file list to remove all files that do not match a search term
# TO DO: I believe that the two phases shown below can be merged into one.
sub filter {
	my $self = shift;
	my $term = shift;

	# Apply a simple substring match on the file name only
	my $quote = quotemeta $term;
	my $regex = qr/$quote/i;
	my @match =
		grep { $_->is_directory or $_->name =~ $regex } @{ $self->{files} };

	# Prune empty directories
	# NOTE: This is tricky and hard to make sense of, but damned fast :)
	foreach my $i ( reverse 0 .. $#match ) {
		my $path  = $match[$i];
		my $after = $match[ $i + 1 ];
		my $prune = (
			$path->is_directory and not( defined $after
				and $after->depth - $path->depth == 1 )
		);
		if ($prune) {
			splice @match, $i, 1;
		}
	}

	return @match;
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

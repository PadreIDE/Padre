package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task                ();
use Padre::Wx::Role::View            ();
use Padre::Wx::Role::Main            ();
use Padre::Wx::Directory::TreeCtrl   ();
use Padre::Wx                        ();

our $VERSION = '0.64';
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
	$self->{files} = [ ];

	# The directories in the tree that should be expanded
	$self->{expand} = { };

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
		$self,
		$search,
		sub {
			$DB::single = 1;
			shift->on_text(@_);
		},
	);

	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self,
		$search,
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
	$search->SetMenu( $menu );

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

# Updates the gui, so each compoment can update itself
# according to the new state.
sub clear {
	my $self = shift;
	my $tree = $self->tree;
	my $root = $tree->GetRootItem;
	$tree->DeleteChildren($root);
	return;
}

# Updates the gui if needed, calling Searcher and Browser respectives
# refresh function.
# Called outside Directory.pm, on directory browser focus and item dragging
sub refresh {
	my $self = shift;

	# Save the list of expanded directories
	$self->{expand} = $self->tree->expanded;

	# NOTE: Without a file open, Padre does not consider itself to
	# have a "current project". We should probably try to find a way
	# to correct this in future.
	my $current = $self->current;
	my $project = $current->project;
	my @options = ();
	if ( $project ) {
		$self->{root} = $project->root;
		@options      = ( project => $project );
	} else {
		$self->{root} = $current->config->default_projects_directory;
		@options      = ( root => $self->{root} );
	}

	# Trigger the second-generation refresh task
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
	my $expand = $self->{expand};
	my $lock   = $self->main->lock('UPDATE');

	# Flush the old state
	$self->clear;

	# Fill the new tree
	my @stack = ();
	my @files = @{$self->{files}};
	while ( @files ) {
		my $path  = shift @files;
		my $image = $path->type ? 'folder' : 'package';
		while ( @stack ) {
			# If we are not the child of the deepest element in
			# the stack, move up a level and try again
			last if $tree->GetPlData($stack[-1])->is_parent($path);

			# We have finished filling the directory.
			# Now it (maybe) has children, we can expand it.
			my $filled = pop @stack;
			if ( $expand->{ $tree->GetPlData($filled)->unix } ) {
				$tree->Expand($filled);
			}
		}

		# If there is anything left on the stack it is our parent
		my $parent = $stack[-1] || $tree->GetRootItem;

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

	return 1;
}





######################################################################
# Panel Migration Support

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

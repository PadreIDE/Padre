package Padre::Wx::Directory;

use 5.008;
use strict;
use warnings;
use Padre::Wx                        ();
use Padre::Wx::Directory::TreeCtrl   ();
use Padre::Wx::Directory::SearchCtrl ();

our $VERSION = '0.54';
our @ISA     = 'Wx::Panel';

use Class::XSAccessor {
	getters => {
		tree   => 'tree',
		search => 'search',
	},
	accessors => {
		mode                  => 'mode',
		project_dir           => 'project_dir',
		previous_dir          => 'previous_dir',
		project_dir_original  => 'project_dir_original',
		previous_dir_original => 'previous_dir_original',
	},
};

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

	# Creates the Search Field and the Directory Browser
	$self->{tree}   = Padre::Wx::Directory::TreeCtrl->new($self);
	$self->{search} = Padre::Wx::Directory::SearchCtrl->new($self);

	# Fill the panel
	my $sizerv = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizerh = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizerv->Add( $self->search, 0, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizerv->Add( $self->tree,   1, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizerh->Add( $sizerv,       1, Wx::wxALL | Wx::wxEXPAND, 0 );

	# Fits panel layout
	$self->SetSizerAndFit($sizerh);
	$sizerh->SetSizeHints($self);

	return $self;
}

# The parent panel
sub panel {
	$_[0]->GetParent;
}

# Returns the main object reference
sub main {
	$_[0]->GetGrandParent;
}

sub current {
	Padre::Current->new( main => $_[0]->main );
}

# Returns the window label
sub gettext_label {
	my $self = shift;
	if ( defined( $self->mode ) and ( $self->mode eq 'tree' ) ) {
		return Wx::gettext('Project');
	} else {
		return Wx::gettext('Directory');
	}
}

# Updates the gui, so each compoment can update itself
# according to the new state
sub clear {
	$_[0]->refresh;
	return;
}

# Updates the gui if needed, calling Searcher and Browser respectives
# refresh function.
# Called outside Directory.pm, on directory browser focus and item dragging
sub refresh {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document;

	# Finds project base
	my $dir;
	if ( defined($document) ) {
		$dir = $document->project_dir;
		$self->{file} = $document->{file};
	} else {
		$dir = $self->main->config->default_projects_directory;
		delete $self->{file};
	}

	# Shortcut if there's no directory, or we haven't changed directory
	return unless $dir;
	if ( defined $self->project_dir and $self->project_dir eq $dir ) {
		return;
	}

	$self->{projects}->{$dir}->{dir} ||= $dir;
	$self->{projects}->{$dir}->{mode} ||=
		$document->{is_project}
		? 'tree'
		: 'navigate';

	# The currently view mode
	$self->mode( $self->{projects}->{$dir}->{mode} );

	# Save the current project path
	$self->project_dir( $self->{projects}->{$dir}->{dir} );
	$self->project_dir_original($dir);

	# Calls Searcher and Browser refresh
	$self->tree->refresh;
	$self->search->refresh;

	# Sets the last project to the current one
	$self->previous_dir( $self->{projects}->{$dir}->{dir} );
	$self->previous_dir_original($dir);

	# Update the panel label
	$self->panel->refresh;

	return 1;
}

# When a project folder is changed
sub _change_project_dir {
	my $self   = shift;
	my $dialog = Wx::DirDialog->new(
		undef,
		Wx::gettext('Choose a directory'),
		$self->project_dir,
	);
	if ( $dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	$self->{projects_dirs}->{ $self->project_dir_original } = $dialog->GetPath;
	$self->refresh;
}

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

# Moves the panel to the other side
sub move {
	my $self   = shift;
	my $config = $self->main->config;
	my $side   = $config->main_directory_panel;
	if ( $side eq 'left' ) {
		$config->apply( main_directory_panel => 'right' );
	} elsif ( $side eq 'right' ) {
		$config->apply( main_directory_panel => 'left' );
	} else {
		die "Bad main_directory_panel setting '$side'";
	}
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

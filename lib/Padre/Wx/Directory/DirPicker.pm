package Padre::Wx::Directory::DirPicker;

use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.41';
our @ISA = 'Wx::DirPickerCtrl';

# Creates the Directory Picker 
sub new {
	my $class = shift;
	my $main = shift;
	my $self = $class->SUPER::new(
		$main, -1, '',
		Wx::gettext('Choose a directory'),
		Wx::wxDefaultPosition, Wx::wxDefaultSize
	);

	Wx::Event::EVT_DIRPICKER_CHANGED(
		$self, $self,
		\&on_change
	);

	return $self;
}

# Returns the Directory Panel object reference
sub parent {
	$_[0]->GetParent;
}

# Updates the gui if needed
sub refresh {
	my $self   = shift;
	my $parent = $self->parent;

	# Gets the last and current actived projects
	my $project_dir  = $parent->project_dir;
	my $project_dir_original  = $parent->project_dir_original;
	my $previous_dir_original = $parent->previous_dir_original;

	# If the project have changed
	if ( defined($project_dir_original) and (not defined($previous_dir_original) or $previous_dir_original ne $project_dir_original ) ) {
		$self->{do_not_update} = 1;
		$self->SetPath( $project_dir );
	}
}

# When there is a change in the picker
sub on_change {
	my $self = shift;
	my $event = shift;
	my $parent = $self->parent;

	# Finds project base
	my $project_dir = $parent->project_dir_original;

	# Ignore if it is a project switching
	if ( $self->{do_not_update}  ) {
		delete $self->{do_not_update};
		return;
	}

	# Updates the Project Directory
	$parent->{projects_dirs}->{$project_dir} = $event->GetPath;
	$parent->refresh;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

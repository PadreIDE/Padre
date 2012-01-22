package Padre::Wx::Dialog::ReplaceInFiles;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::ReplaceInFiles ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::FBP::ReplaceInFiles
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->CenterOnParent;
	return $self;
}





######################################################################
# Event Handlers

sub directory {
	my $self    = shift;
	my $default = $self->find_directory->GetValue;
	unless ($default) {
		$default = $self->config->default_projects_directory;
	}

	# Ask the user for a directory
	my $dialog = Wx::DirDialog->new(
		$self,
		Wx::gettext("Select Directory"),
		$default,
	);

	# Update the dialog
	my $result = $dialog->ShowModal;
	unless ( $result == Wx::ID_CANCEL ) {
		$self->find_directory->SetValue( $dialog->GetPath );
	}

	$dialog->Destroy;
}





######################################################################
# Main Methods

sub run {
	my $self    = shift;
	my $main    = $self->main;
	my $find    = $self->find_term;
	my $current = $self->current;

	# Inherit the search term from the other search tools
	if ( $main->has_findfast and $main->findfast->IsShown ) {
		$find->refresh( $main->findfast->find_term->GetValue );
		$main->show_findfast(0);
	} else {
		$find->refresh( $current->text );
	}
	$self->replace_term->refresh('');

	# Default the search directory to the root of the current project
	my $project = $current->project;
	if ( defined $project ) {
		$self->find_directory->SetValue( $project->root );
	}

	# Refresh the dialog and prepare to show
	$self->refresh;
	if ( length $find->GetValue ) {
		$self->replace_term->SetFocus;
	} else {
		$find->SetFocus;
	}

	# Show the dialog
	my $result = $self->ShowModal;
	if ( $result == Wx::ID_CANCEL ) {

		# As we leave the dialog return the user to the current editor
		# window so they don't need to click it.
		$main->editor_focus;
		return;
	}

	# Save user input for next time
	my $lock = $main->lock('DB');
	$self->find_term->SaveValue;
	$self->find_directory->SaveValue;
	$self->replace_term->SaveValue;

	# Run the search in the Replace in Files tool
	$main->show_replaceinfiles;
	$main->replaceinfiles->replace(
		search  => $self->as_search,
		replace => $self->replace_term->GetValue,
		root    => $self->find_directory->GetValue,
		mime    => $self->find_types->GetClientData(
			$self->find_types->GetSelection
		),
	);

	$main->editor_focus;
}

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self = shift;
	$self->replace->Enable( $self->find_term->GetValue ne '' );
}

# Generate a search object for the current dialog state
sub as_search {
	my $self = shift;
	require Padre::Search;
	Padre::Search->new(
		find_term    => $self->find_term->GetValue,
		find_case    => $self->find_case->GetValue,
		find_regex   => $self->find_regex->GetValue,
		replace_term => $self->replace_term->GetValue,
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

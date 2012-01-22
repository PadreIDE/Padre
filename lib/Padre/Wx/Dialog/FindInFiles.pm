package Padre::Wx::Dialog::FindInFiles;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::FindInFiles ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::FBP::FindInFiles
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->CenterOnParent;

	Wx::Event::EVT_KEY_UP(
		$self,
		sub {
			shift->key_up(@_);
		},
	);

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
	my $result = $dialog->ShowModal;
	$dialog->Destroy;

	# Update the dialog
	unless ( $result == Wx::ID_CANCEL ) {
		$self->find_directory->SetValue( $dialog->GetPath );
	}

	return;
}





######################################################################
# Main Methods

sub run {
	my $self    = shift;
	my $main    = $self->main;
	my $find    = $self->find_term;
	my $current = $self->current;

	# Clear out and reset the search term box
	if ( $main->has_findfast and $main->findfast->IsShown ) {
		$find->refresh( $main->findfast->find_term->GetValue );
		$main->show_findfast(0);
	} else {
		$find->refresh( $current->text );
	}

	# Default the search directory to the root of the current project
	my $project = $current->project;
	if ( defined $project ) {
		$self->find_directory->SetValue( $project->root );
	}

	# Update the user interface
	$self->refresh;
	$find->SetFocus;

	# Show the dialog
	my $result = $self->ShowModal;
	if ( $result == Wx::ID_CANCEL ) {

		# As we leave the Find dialog, return the user to the current editor
		# window so they don't need to click it.
		$main->editor_focus;
		return;
	}

	# Save user input for next time
	my $lock = $main->lock('DB');
	$self->find_term->SaveValue;
	$self->find_directory->SaveValue;

	# Run the search in the Find in Files view
	$main->show_foundinfiles;
	$main->foundinfiles->search(
		search => $self->as_search,
		root   => $self->find_directory->GetValue,
		mime   => $self->find_types->GetClientData(
			$self->find_types->GetSelection
		),
	);

	$main->editor_focus;
}

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self = shift;
	$self->find->Enable( $self->find_term->GetValue ne '' );
}

# Generate a search object for the current dialog state
sub as_search {
	my $self = shift;
	require Padre::Search;
	Padre::Search->new(
		find_term  => $self->find_term->GetValue,
		find_case  => $self->find_case->GetValue,
		find_regex => $self->find_regex->GetValue,
	);
}

sub key_up {
	my $self  = shift;
	my $event = shift;
	my $mod   = $event->GetModifiers || 0;
	my $code  = $event->GetKeyCode;

	# A fixed key binding isn't good at all.
	# TODO: Change this to the action's keybinding

	# Handle Ctrl-F only
	return unless $mod == 2;
	return unless $code == 70;

	$self->Hide;

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

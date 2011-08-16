package Padre::Wx::Dialog::ReplaceInFiles;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::ReplaceInFiles ();

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::FBP::ReplaceInFiles
};

use constant CONFIG => qw{
	find_case
	find_regex
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Default the search directory to the root of the current project
	my $project = $self->current->project;
	if ( defined $project ) {
		$self->find_directory->SetValue( $project->root );
	}

	# Prepare to be shown
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
	my $result = $dialog->ShowModal;
	$dialog->Destroy;

	# Update the dialog
	unless ( $result == Wx::wxID_CANCEL ) {
		$self->find_directory->SetValue( $dialog->GetPath );
	}

	return;
}





######################################################################
# Main Methods

sub run {
	my $self    = shift;
	my $current = $self->current;
	my $config  = $current->config;

	# Do they have a specific search term in mind?
	my $text = $current->text;
	$text = '' if $text =~ /\n/;

	# Clear out and reset the search term box
	$self->find_term->refresh($text);
	$self->find_term->SetFocus;

	# Load search preferences
	foreach my $name (CONFIG) {
		$self->$name()->SetValue( $config->$name() );
	}

	# Update the user interface
	$self->refresh;

	# Show the dialog
	my $result = $self->ShowModal;

	# Save any changed preferences
	$self->save;

	if ( $result == Wx::wxID_CANCEL ) {

		# As we leave the dialog return the user to the current editor
		# window so they don't need to click it.
		my $editor = $current->editor;
		$editor->SetFocus if $editor;

		return;
	}

	# Run the search in the Replace in Files tool
	$self->main->show_replaceinfiles;
	$self->main->replaceinfiles->(
		root    => $self->find_directory->SaveValue,
		search  => $self->as_search,
		replace => $self->replace_term->GetValue,
	);

	return;
}

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self = shift;
	$self->replace->Enable( $self->find_term->GetValue ne '' );
}

# Save the dialog settings to configuration.
# Returns the config object as a convenience.
sub save {
	my $self    = shift;
	my $config  = $self->current->config;
	my $changed = 0;

	foreach my $name (CONFIG) {
		my $value = $self->$name()->GetValue;
		next if $config->$name() == $value;
		$config->set( $name => $value );
		$changed = 1;
	}

	$config->write if $changed;

	return $config;
}

# Generate a search object for the current dialog state
sub as_search {
	my $self = shift;
	require Padre::Search;
	Padre::Search->new(
		find_term  => $self->find_term->SaveValue,
		find_case  => $self->find_case->GetValue,
		find_regex => $self->find_regex->GetValue,
	);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

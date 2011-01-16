package Padre::Wx::Dialog::Find2;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::Find ();

our $VERSION = '0.78';
our @ISA     = qw{
	Padre::Wx::FBP::Find
};

use constant SAVE => qw{
	find_case
	find_regex
	find_first
	find_reverse
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Prepare to be shown
	$self->CenterOnParent;

	# As the user types the search term, make sure the find button
	# enabled status is correct
	Wx::Event::EVT_TEXT(
		$self,
		$self->{find_term},
		sub {
			shift->refresh;
		}
	);

	return $self;
}





######################################################################
# Main Methods

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self   = shift;
	my $enable = $self->{find_term}->GetValue ne '';
	$self->{find_next}->Enable($enable);
	$self->{find_all}->Enable($enable);
}

sub run {
	my $self = shift;

	# Do they have a specific search term in mind?
	my $text = $self->current->text;
	$text = '' if $text =~ /\n/;

	# Clear out and reset the search term box
	$self->{find_term}->refresh;
	$self->{find_term}->SetValue($text) if length $text;
	$self->{find_term}->SetFocus;

	# Refresh
	$self->refresh;

	# Show the dialog
	my $result = $self->ShowModal;

	# Save any changed preferences
	$self->save;

	if ( $result == Wx::wxID_CANCEL ) {

		# As we leave the Find dialog, return the user to the current editor
		# window so they don't need to click it.
		my $editor = $self->current->editor;
		$editor->SetFocus if $editor;

		return;
	}

	# Run the search in the Find in Files tool
	$self->main->show_findinfiles;
	$self->main->findinfiles->search(
		root   => $self->{find_directory}->GetValue,
		search => $self->as_search,
	);

	return;
}

# Save the dialog settings to configuration.
# Returns the config object as a convenience.
sub save {
	my $self    = shift;
	my $config  = $self->current->config;
	my $changed = 0;

	foreach my $name ( SAVE ) {
		my $value = $self->{$name}->GetValue;
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
	Padre::Search->new(
		find_term    => $self->{find_term}->GetValue,
		find_case    => $self->{find_case}->GetValue,
		find_regex   => $self->{find_regex}->GetValue,
		find_reverse => $self->{find_reverse}->GetValue
	);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

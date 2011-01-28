package Padre::Wx::Dialog::Find;

use 5.008;
use strict;
use warnings;
use Padre::Search        ();
use Padre::Wx::FBP::Find ();

our $VERSION = '0.80';
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
			$_[0]->refresh;
		}
	);

	return $self;
}





######################################################################
# Event Handlers

sub find_next {
	my $self   = shift;
	my $main   = $self->main;
	my $config = $self->save;

	# Generate the search object
	my $search = $self->as_search;
	unless ($search) {
		$main->error('Not a valid search');

		# Move the focus back to the search text
		# so they can tweak their search.
		$self->{find_term}->SetFocus;

		return;
	}

	# Apply the search to the current editor
	my $result = $main->search_next($search);

	# If we're only searching once, we won't need the dialog any more
	if ( $self->{find_first}->GetValue ) {
		$self->Hide;

	} elsif ( not $result ) {
		$main->info(
			Wx::gettext('No matches found'),
			Wx::gettext('Search')
		);

		# Move the focus back to the search text
		# so they can tweak their search.
		$self->{find_term}->SetFocus;
	}

	return;
}





######################################################################
# Main Methods

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self = shift;
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

	return;
}

# Save the dialog settings to configuration.
# Returns the config object as a convenience.
sub save {
	my $self    = shift;
	my $config  = $self->current->config;
	my $changed = 0;

	foreach my $name (SAVE) {
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
		find_term    => $self->{find_term}->SaveValue,
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

package Padre::Wx::Dialog::Replace;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::Replace ();

our $VERSION = '0.91';
our @ISA     = 'Padre::Wx::FBP::Replace';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Prepare to be shown
	$self->CenterOnParent;

	return $self;
}





######################################################################
# Main Methods

sub run {
	my $self    = shift;
	my $main    = $self->main;
	my $current = $self->current;
	my $config  = $current->config;

	# Do they have a specific search term in mind?
	my $text = $current->text;
	unless ( defined $text ) {
		$text = '';
	}
	unless ( length $text ) {
		if ( $main->has_findfast ) {
			my $fast = $main->findfast->find_term;
			$text = $fast if length $fast;	
		}
	}
	if ( $text =~ /\n/ ) {
		$text = '';
	}

	# Clear out and reset the search term box
	$self->find_term->refresh($text);
	if ( length $text ) {
		$self->replace_term->SetFocus;
	} else {
		$self->find_term->SetFocus;
	}

	# Hide the Fast Find if visible
	$main->show_findfast(0);

	# Show the dialog
	my $result = $self->ShowModal;

	# As we leave the Find dialog, return the user to the current editor
	# window so they don't need to click it.
	my $editor = $self->current->editor;
	$editor->SetFocus if $editor;

	return;
}

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self = shift;
	my $show = $self->find_term->GetValue ne '';
	$self->find->Enable($show);
	$self->replace->Enable($show);
}

# Generate a search object for the current dialog state
sub as_search {
	my $self = shift;
	require Padre::Search;
	Padre::Search->new(
		find_term    => $self->find_term->SaveValue,
		find_case    => $self->find_case->GetValue,
		find_regex   => $self->find_regex->GetValue,
		replace_term => $self->replace_term->GetValue,
	);
}

1;



# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


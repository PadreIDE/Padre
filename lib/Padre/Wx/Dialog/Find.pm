package Padre::Wx::Dialog::Find;

use 5.008;
use strict;
use warnings;
use Padre::Search        ();
use Padre::Wx::FBP::Find ();

our $VERSION = '0.93';
our @ISA     = qw{
	Padre::Wx::FBP::Find
};





######################################################################
# Event Handlers

sub on_close {
	my $self  = shift;
	my $event = shift;
	$self->main->editor_focus;
	$event->Skip(1);
}

sub find_next_clicked {
	my $self   = shift;
	my $main   = $self->main;
	my $search = $self->as_search;
	if ( $search ) {
		$self->find_term->SaveValue;
	} else {
		# Move the focus back to the search text
		# so they can tweak their search.
		$self->find_term->SetFocus;
		return;
	}

	# Apply the search to the current editor
	my $result = $main->search_next($search);

	# If we're only searching once, we won't need the dialog any more
	$main->info(
		sprintf(
			Wx::gettext('No matches found for "%s".'),
			$self->find_term->GetValue,
		),
		Wx::gettext('Search')
	);

	# Move the focus back to the search text
	# so they can tweak their search.
	$self->find_term->SetFocus;

	return;
}





######################################################################
# Main Methods

sub run {
	my $self = shift;
	my $main = $self->main;
	my $text = '';

	# If Find Fast is showing inherit settings from it
	if ( $main->has_findfast and $main->findfast->IsShown ) {
		$text = $main->findfast->find_term->GetValue;
		$main->show_findfast(0);

	} else {
		$text = $self->current->text;
		$text = '' if $text =~ /\n/;
	}

	# Clear out and reset the search term box
	$self->find_term->refresh($text);
	$self->find_term->SetFocus;
	$self->refresh;

	# Show the dialog
	$self->Show;
}

# Ensure the find button is only enabled if the field values are valid
sub refresh {
	my $self   = shift;
	my $enable = $self->find_term->GetValue ne '';
	$self->find_next->Enable($enable);
	$self->find_all->Enable($enable);
}

# Generate a search object for the current dialog state
sub as_search {
	my $self = shift;
	Padre::Search->new(
		find_term    => $self->find_term->GetValue,
		find_case    => $self->find_case->GetValue,
		find_regex   => $self->find_regex->GetValue,
		find_reverse => $self->find_reverse->GetValue,
	);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

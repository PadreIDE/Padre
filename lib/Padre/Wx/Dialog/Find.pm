package Padre::Wx::Dialog::Find;

use 5.008;
use strict;
use warnings;
use Padre::Search        ();
use Padre::Wx::FBP::Find ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::FBP::Find
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

sub on_close {
	my $self  = shift;
	my $event = shift;
	$self->Hide;
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
	$main->search_next($search) and return;

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
	my $find = $self->find_term;

	# If Find Fast is showing inherit settings from it
	if ( $main->has_findfast and $main->findfast->IsShown ) {
		$find->refresh( $main->findfast->find_term->GetValue );
		$main->show_findfast(0);
	} else {
		$find->refresh( $self->current->text );
	}

	# Refresh and show the dialog
	$self->refresh;
	$find->SetFocus;
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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

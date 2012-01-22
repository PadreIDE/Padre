package Padre::Wx::Dialog::Replace;

use 5.008;
use strict;
use warnings;
use Padre::Search           ();
use Padre::Wx::FBP::Replace ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::Replace';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->CenterOnParent;
	return $self;
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
	$self->replace_term->refresh('');

	# Refresh the dialog and prepare to show
	$self->refresh;
	if ( length $find->GetValue ) {
		$self->replace_term->SetFocus;
	} else {
		$find->SetFocus;
	}

	# Show the dialog
	$self->Show;
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

# Makes sure the find button is only enabled when the field
# values are valid
sub refresh {
	my $self = shift;
	my $show = $self->as_search ? 1 : 0;
	$self->find_next->Enable($show);
	$self->replace->Enable($show);
	$self->replace_all->Enable($show);
	return;
}

sub find_next_clicked {
	my $self   = shift;
	my $search = $self->as_search or return;

	# Apply the search to the current editor
	if ( $self->main->search_next($search) ) {
		$self->find_term->SaveValue;
		$self->replace_term->SaveValue;
	} else {
		$self->no_matches;
	}

	return;
}

sub replace_clicked {
	my $self   = shift;
	my $search = $self->as_search or return;

	# Replace the current selection, or find the next match
	# if the current selection is not a match.
	if ( $self->main->replace_next($search) ) {
		$self->find_term->SaveValue;
		$self->replace_term->SaveValue;
	} else {
		$self->no_matches;
	}

	return;
}

sub replace_all_clicked {
	my $self   = shift;
	my $main   = $self->main;
	my $search = $self->as_search or return;

	# Apply the search to the current editor
	my $changes = $main->replace_all($search);
	if ($changes) {
		$self->find_term->SaveValue;
		$self->replace_term->SaveValue;

		# remark: It would be better to use gettext for plural handling, but wxperl does not seem to support this at the moment.
		my $message_text =
			$changes == 1 ? Wx::gettext('Replaced %d match') : Wx::gettext('Replaced %d matches');
		$main->info(
			sprintf( $message_text, $changes ),
			Wx::gettext('Search and Replace')
		);
	} else {
		$main->info(
			sprintf( Wx::gettext('No matches found for "%s".'), $self->find_term->GetValue ),
			Wx::gettext('Search and Replace'),
		);
	}

	# Move the focus back to the search text
	# so they can change it if they want.
	$self->find_term->SetFocus;
	return;
}





######################################################################
# Support Methods

sub no_matches {
	my $self = shift;

	$self->main->message(
		sprintf(
			Wx::gettext('No matches found for "%s".'),
			$self->find_term->GetValue,
		),
		Wx::gettext('Search and Replace'),
	);

	# Move the focus back to the search text
	# so they can change it if they want.
	$self->find_term->SetFocus;
}

# Generate a search object for the current dialog state
sub as_search {
	my $self = shift;
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

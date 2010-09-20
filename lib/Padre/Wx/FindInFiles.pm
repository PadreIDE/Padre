package Padre::Wx::FindInFiles;

# Class for the output window at the bottom of Padre that is used to display
# results from Find in Files searches.

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.69';
our @ISA     = qw{
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::TextCtrl
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$panel,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_READONLY
			| Wx::wxTE_MULTILINE
			| Wx::wxTE_DONTWRAP
			| Wx::wxNO_FULL_REPAINT_ON_RESIZE,
	);

	# Set the font and colours
	$self->SetBackgroundColour(
		Wx::Colour->new('#FFFFFF')
	);
	my $font = Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL );
	my $name = $self->config->editor_font;
	if ( defined $name and length $name ) {
		$font->SetNativeFontInfoUserDesc($name);
	}
	my $style = $self->GetDefaultStyle;
	$style->SetFont($font);
	$self->SetDefaultStyle($style);

	return $self;
}





######################################################################
# Search Methods

sub search {
	my $self = shift;

	# Kick off the search task
	$self->task_reset;
	$self->clear;
	$self->task_request(
		task       => 'Padre::Task::FindInFiles',
		on_message => 'search_message',
		on_finish  => 'search_finish',
		@_,
	);

	return 1;
}

sub search_message {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $path = shift;
	my $unix = $path->unix;

	# Generate the text all at once in advance and add to the control
	$self->AppendText(
		join(
			'',
			"----------------------------------------\n",
			"Find '$task->{find_term}' in '$unix':\n",
			( map { "$unix($_->[0]): $_->[1]\n" } @_ ),
			"Found '$task->{find_term}' " . scalar(@_) . " time(s).\n",
		)
	);

	return 1;
}

sub search_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	shift->main->show_output(0);
}





######################################################################
# Padre::Role::Task Methods

sub task_request {
	my $self    = shift;
	my $current = $self->current;
	my $project = $current->project;
	if ($project) {
		return $self->SUPER::task_request(
			@_,
			project => $project,
		);
	} else {
		return $self->SUPER::task_request(
			@_,
			root => $current->config->main_directory_root,
		);
	}
}





#####################################################################
# General Methods

sub bottom {
	warn "Unexpectedly called Padre::Wx::Output::bottom, it should be deprecated";
	shift->main->bottom;
}

sub gettext_label {
	Wx::gettext('Find in Files');
}

sub select {
	my $self   = shift;
	my $parent = $self->GetParent;
	$parent->SetSelection( $parent->GetPageIndex($self) );
	return;
}

sub clear {
	my $self = shift;
	$self->Remove( 0, $self->GetLastPosition );
	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

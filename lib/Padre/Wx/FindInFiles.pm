package Padre::Wx::FindInFiles;

# Class for the output window at the bottom of Padre that is used to display
# results from Find in Files searches.

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.72';
our @ISA     = qw{
	Padre::Role::Task
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
	$self->SetBackgroundColour( Wx::Colour->new('#FFFFFF') );
	my $font = Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL );
	my $name = $self->config->editor_font;
	if ( defined $name and length $name ) {
		$font->SetNativeFontInfoUserDesc($name);
	}
	my $style = $self->GetDefaultStyle;
	$style->SetFont($font);
	$self->SetDefaultStyle($style);

	# Inialise statistics
	$self->{files}   = 0;
	$self->{matches} = 0;

	return $self;
}





######################################################################
# Search Methods

sub search {
	my $self  = shift;
	my %param = @_;

	# If we are given a root and no project, and the root path
	# is precisely the root of a project, switch so that the search
	# will automatically pick up the manifest/skip rules for it.
	if ( defined $param{root} and not exists $param{project} ) {
		my $project = $self->ide->project( $param{root} );
		$param{project} = $project if $project;
	}

	# Kick off the search task
	$self->task_reset;
	$self->clear;
	$self->task_request(
		task       => 'Padre::Task::FindInFiles',
		on_message => 'search_message',
		on_finish  => 'search_finish',
		%param,
	);

	return 1;
}

sub search_message {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $path = shift;
	require Padre::Wx::Directory::Path; # added to avoid crash in next line
	my $unix = $path->unix;
	my $term = $task->{search}->find_term;

	# Generate the text all at once in advance and add to the control
	$self->AppendText(
		join(
			'',
			"----------------------------------------\n",
			"Find '$term' in '$unix':\n",
			( map {"$unix($_->[0]): $_->[1]\n"} @_ ),
			"Found '$term' " . scalar(@_) . " time(s).\n",
		)
	);

	# Update statistics
	$self->{files}   += 1;
	$self->{matches} += scalar @_;

	return 1;
}

sub search_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $term = $task->{search}->find_term;

	# Display the summary
	$self->AppendText( "Search complete, " . "found '$term' $self->{matches} time(s) " . "in $self->{files} file(s)" );

	return 1;
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
	shift->main->show_findinfiles(0);
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
	$self->{files}   = 0;
	$self->{matches} = 0;
	$self->Remove( 0, $self->GetLastPosition );
	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

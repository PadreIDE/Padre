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

our $VERSION = '0.75';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::ListView
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
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);

	# Add the columns
	my @titles = $self->titles;
	foreach ( 0 .. 2 ) {
		$self->InsertColumn( $_, $titles[$_] );
	}

	# When a find result is clicked, open it
	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self,
		sub {
			shift->_on_find_result_clicked(@_);
		}
	);

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

# Helper method to append item to the table
sub append_item {
	my ($self, $file, $line, $msg) = @_;
	
	my $item = $self->InsertStringItem( $self->GetItemCount+1, $file );
	$self->SetItemData($item, ($line ne '') ? $line : 0 );
	$self->SetItem( $item, 1, $line );
	$self->SetItem( $item, 2, $msg );
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
	my @results = @_;
	for my $result (@results) {
		$self->append_item($unix, $result->[0], $result->[1] );
	}
	my $num_results = scalar(@results);
	$self->append_item('', '', "Found '$term' " .  $num_results . " time(s).\n" );

	# Update statistics
	$self->{files}   += 1;
	$self->{matches} += $num_results;

	return 1;
}

sub search_finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $term = $task->{search}->find_term;

	# Display the summary
	$self->append_item(
		'', 
		'', 
		"Search complete, found '$term' $self->{matches} time(s) in $self->{files} file(s)" );

	# and resize them!
	$self->_resize_columns;

	return 1;
}

# Private method to resize list columns
sub _resize_columns {
	my $self = shift;

	# Resize all columns but the last to their biggest item width
	for ( 0 .. $self->GetColumnCount - 1 ) {
		$self->SetColumnWidth( $_, Wx::wxLIST_AUTOSIZE );
	}

	return;
}

# Private method to handle the clicking of a find result
sub _on_find_result_clicked {
	my ($self, $event)  = @_;

	my $selection    = $self->GetFirstSelected;
	
	my $file = $self->GetItem( $selection, 0 )->GetText or return;
	my $line = $self->GetItem( $selection, 1 )->GetText or return;
	my $msg  = $self->GetItem( $selection, 2 )->GetText || '';

	$self->open_file_at_line($file, $line-1);

	return;
}

# Opens the file at the correct line position
sub open_file_at_line {
	my ($self, $file, $line)   = @_;

	return unless -f $file;
	my $main = $self->main;

	# Try to open the file now
	if ( my $page_id = $main->find_editor_of_file($file) ) {
		my $editor = $main->notebook->GetPage($page_id);
		$editor->EnsureVisible($line);
		$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
		$editor->SetFocus;
	} else {
		$main->setup_editor($file);
		if(my $page_id = $main->find_editor_of_file($file) ) {
			my $editor = $main->notebook->GetPage($page_id);
			$editor->EnsureVisible($line);
			$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
			$editor->SetFocus;
		}
	}
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
	$self->DeleteAllItems;
	return 1;
}

sub titles {
	return (
		Wx::gettext('File'),
		Wx::gettext('Line'),
		Wx::gettext('Description'),
	);
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

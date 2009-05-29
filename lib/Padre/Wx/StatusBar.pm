package Padre::Wx::StatusBar;

=pod

=head1 NAME

Padre::Wx::StatusBar - Encapsulates status bar customizations

=head1 DESCRIPTION

C<Padre::Wx::StatusBar> implements Padre's statusbar. It is the bottom
pane holding various, err, status information on Padre.

The information shown are (in order):

=over 4

=item * Filename of current document, with a leading star if file has
been updated and not saved

=item * (Optional) Icon showing status of background tasks

=item * (Optional) Mimetype of current document

=item * Type of end of lines of current document

=item * Position in current document

=back

It inherits from C<Wx::StatusBar>, so check wx documentation to see all
the available methods that can be applied to it besides the added ones
(see below).

=cut

use strict;
use warnings;
use Padre::Util    ();
use Padre::Wx      ();
use Padre::Current ();

use Class::XSAccessor accessors => {
	_task_sbmp   => '_task_sbmp',      # Static bitmap holding the task status
	_task_status => '_task_status',    # Current task status
	_task_width  => '_task_width',     # Current width of task field
};

our $VERSION = '0.36';
our @ISA     = 'Wx::StatusBar';

use constant {
	FILENAME => 0,
	TASKLOAD => 1,
	MIMETYPE => 2,
	NEWLINE  => 3,
	POSTRING => 4,
};

#####################################################################

=pod

=head1 PUBLIC API

=head2 Constructor

There's only one constructor for this class.

=over 4

=item * my $statusbar = Padre::Wx::StatusBar->new( $main );

Create and return a new Padre statusbar. One should pass the C<$main>
Padre window as argument, to get a reference to the statusbar parent.

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the basic object
	my $self = $class->SUPER::new( $main, -1, Wx::wxST_SIZEGRIP | Wx::wxFULL_REPAINT_ON_RESIZE );

	# create the static bitmap that will hold the task load status
	my $sbmp = Wx::StaticBitmap->new( $self, -1, Wx::wxNullBitmap );
	$self->_task_sbmp($sbmp);
	$self->_task_status('foobar');    # init status to sthg defined
	Wx::Event::EVT_LEFT_DOWN(
		$sbmp,
		sub {
			require Padre::TaskManager;
			Padre::TaskManager::on_dump_running_tasks(@_);
		},
	);

	# Set up the fields
	$self->SetFieldsCount(5);
	$self->SetStatusWidths( -1, 0, 100, 50, 100 );

	# react to resize events, to adapt size of icon field
	Wx::Event::EVT_SIZE( $self, \&on_resize );

	return $self;
}

=pod

=back

=cut

#####################################################################

=pod

=head2 Public Methods

=over 4

=item * $sb->clear;

Clear all the status bar fields, ie, they will display an empty string
in all fields.

=cut

sub clear {
	my $self = shift;
	$self->SetStatusText( "", FILENAME );
	$self->SetStatusText( "", MIMETYPE );
	$self->SetStatusText( "", NEWLINE );
	$self->SetStatusText( "", POSTRING );
	return;
}

=pod

=item * my $main = $sb->main;

Handy method to get a reference on Padre's main window.

=cut

sub main {
	$_[0]->GetParent;
}

=pod

=item * my $current = $sb->current;

Get a new C<Padre::Current> object.

=cut

sub current {
	Padre::Current->new( main => $_[0]->GetParent, );
}

=pod

=item * $sb->refresh;

Force an update of the document fields in the statusbar.

=cut

sub refresh {
	my $self    = shift;
	my $current = $self->current;

	# Blank the status bar if no document is open
	my $editor = $current->editor or return $self->clear;

	# Prepare the various strings that form the status bar
	my $notebook = $current->notebook;
	my $document = $current->document;
	my $newline  = $document->get_newline_type || Padre::Util::NEWLINE;
	my $pageid   = $notebook->GetSelection;
	my $filename = $document->filename || '';
	my $old      = $notebook->GetPageText($pageid);
	my $text
		= $filename
		? File::Basename::basename($filename)
		: substr( $old, 1 );
	my $modified = $editor->GetModify ? '*' : ' ';
	my $title    = $modified . $text;
	my $position = $editor->GetCurrentPos;
	my $line     = $editor->GetCurrentLine;
	my $start    = $editor->PositionFromLine($line);
	my $char     = $position - $start;
	my $width    = $self->GetCharWidth;
	my $mimetype = $document->get_mimetype;
	my $postring = Wx::gettext('L:') . ( $line + 1 ) . ' ' . Wx::gettext('Ch:') . $char;

	# update task load status
	$self->update_task_status;

	# Write the new values into the status bar and update sizes
	$self->SetStatusText( "$modified $filename", FILENAME );
	$self->SetStatusText( $mimetype,             MIMETYPE );
	$self->SetStatusText( $newline,              NEWLINE );
	$self->SetStatusText( $postring,             POSTRING );
	$self->SetStatusWidths(
		-1,
		$self->_task_width,
		( length($mimetype) ) * $width,
		( length($newline) + 2 ) * $width,
		( length($postring) + 4 ) * $width,
	);

	# move the static bitmap holding the task load status
	$self->_move_bitmap;

	# Fixed ticket #190: Massive GDI object leakages
	# http://padre.perlide.org/ticket/190
	# Please remember to call SetPageText once per the same text
	# This still leaks but far less slowly (just on undo)
	if ( $old ne $title ) {
		$notebook->SetPageText( $pageid, $title );
	}

	return;
}

=pod

=item * $sb->update_task_status;

Checks whether a task status icon update is in order and if so, changes
the icon to one of the other states

=cut

sub update_task_status {
	my ($self) = @_;
	my $status = _get_task_status();
	return if $status eq $self->_task_status;    # nothing to do

	# store new status
	$self->_task_status($status);

	my $sbmp = $self->_task_sbmp;

	# if we're idling, just hide the icon in the statusbar
	if ( $status eq 'idle' ) {
		$sbmp->Hide;
		$sbmp->SetBitmap(Wx::wxNullBitmap);
		$sbmp->SetToolTip('');
		$self->_task_width(0);
		return;
	}

	# not idling, show the correct icon in the statusbar
	my $icon = Padre::Wx::Icon::find("status/padre-tasks-$status");
	$sbmp->SetToolTip(
		$status eq 'running'
		? Wx::gettext('Background Tasks are running')
		: Wx::gettext('Background Tasks are running with high load')
	);
	$sbmp->SetBitmap($icon);
	$sbmp->Show;
	$self->_task_width(20);
}

=pod

=back

=cut

#####################################################################

=pod

=head2 Event handlers

Those methods handle various events happening to the statusbar.

=over 4

=item * $sb->on_resize( $event );

Handler for the EVT_SIZE C<$event>. Used to move the task load bitmap to
its position.

=cut

sub on_resize {
	my ($self) = @_;

	# note: parent resize method will be called automatically

	$self->_move_bitmap;
	$self->Refresh;
}

=pod

=back

=cut

#####################################################################

# Private methods

#
# my $status = _get_task_status();
#
# return 'idle', 'running' or 'load' depending on the number of threads
# currently working.
#
sub _get_task_status {
	my $manager = Padre->ide->task_manager;

	# still in editor-startup phase, default to idle
	return 'idle' unless defined $manager;

	my $running = $manager->running_tasks;
	return 'idle' unless $running;

	my $max_workers = $manager->max_no_workers;
	my $jobs        = $manager->task_queue->pending + $running;

	# high load is defined as the state when the number of
	# running and pending jobs is larger that twice the
	# MAXIMUM number of workers
	return ( $jobs > 2 * $max_workers ) ? 'load' : 'running';
}

#
# $sb->_move_bitmap;
#
# move the static bitmap holding the task load status to its proper location.
#
sub _move_bitmap {
	my ($self) = @_;

	my $sbmp = $self->_task_sbmp;
	my $rect = $self->GetFieldRect(TASKLOAD);
	my $size = $sbmp->GetSize;
	$sbmp->Move(
		$rect->GetLeft + ( $rect->GetWidth - $size->GetWidth ) / 2,
		$rect->GetTop +  ( $rect->GetHeight - $size->GetHeight ) / 2,
	);
	$sbmp->Refresh;
}

=pod

=head1 SEE ALSO

Icons for background status courtesy of Mark James, at
L<http://www.famfamfam.com/lab/icons/silk/>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

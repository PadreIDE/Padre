package Padre::Wx::StatusBar;

=pod

=head1 NAME

Padre::Wx::StatusBar - Encapsulates status bar customizations

=head1 DESCRIPTION

C<Padre::Wx::StatusBar> implements Padre's status bar. It is the bottom
pane holding various, err, status information on Padre.

The information shown are (in order):

=over 4

=item * File name of current document, with a leading star if file has
been updated and not saved

=item * (Optional) Icon showing status of background tasks

=item * (Optional) MIME type of current document

=item * Type of end of lines of current document

=item * Position in current document

=back

It inherits from C<Wx::StatusBar>, so check Wx documentation to see all
the available methods that can be applied to it besides the added ones
(see below).

=cut

use 5.008;
use strict;
use warnings;
use Padre::Constant       ();
use Padre::Current        ();
use Padre::Util           ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Wx::Role::Main ();
use Padre::MIME           ();

use Class::XSAccessor {
	accessors => {
		_task_sbmp   => '_task_sbmp',   # Static bitmap holding the task status
		_task_status => '_task_status', # Current task status
		_task_width  => '_task_width',  # Current width of task field
	}
};

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::StatusBar
};

use constant {
	FILENAME    => 0,
	TASKLOAD    => 1,
	MIMETYPE    => 2,
	NEWLINE     => 3,
	POSTRING    => 4,
	RDONLY      => 5,
};





#####################################################################

=pod

=head1 METHODS

=head2 C<new>

    my $statusbar = Padre::Wx::StatusBar->new( $main );

Create and return a new Padre status bar. One should pass the C<$main>
Padre window as argument, to get a reference to the status bar parent.

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the basic object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::ST_SIZEGRIP | Wx::FULL_REPAINT_ON_RESIZE
	);

	$self->{main} = $main;

	# create the static bitmap that will hold the task load status
	my $sbmp = Wx::StaticBitmap->new( $self, -1, Wx::NullBitmap );
	$self->_task_sbmp($sbmp);
	$self->_task_status('foobar'); # init status to sthg defined
	                               # Wx::Event::EVT_LEFT_DOWN(
	                               # $sbmp,
	                               # sub {
	                               # require Padre::TaskManager;
	                               # Padre::TaskManager::on_dump_running_tasks(@_);
	                               # },
	                               # );

	# Set up the fields
	$self->SetFieldsCount(6);

	#$self->SetStatusWidths( -1, 0, 100, 100, 50, 100 );

	# react to resize events, to adapt size of icon field
	Wx::Event::EVT_SIZE( $self, \&on_resize );

	return $self;
}

#####################################################################

=pod

=head2 C<clear>

    $statusbar->clear;

Clear all the status bar fields, i.e. they will display an empty string
in all fields.

=cut

sub clear {
	my $self = shift;
	$self->SetStatusText( "", FILENAME );
	$self->SetStatusText( "", MIMETYPE );
	$self->SetStatusText( "", NEWLINE );
	$self->SetStatusText( "", POSTRING );
	$self->SetStatusText( "", RDONLY );
	return;
}

=pod

=head2 C<say>

    $statusbar->say('Hello World!');

Temporarily overwrite only the leftmost filename part of the status bar.

It will return to it's normal value when the status bar is next refreshed
for normal reasons (such as a keystroke or a file panel switch).

=cut

sub say {
	$_[0]->SetStatusText( $_[1], FILENAME );
}

=pod

=head2 C<refresh>

    $statusbar->refresh;

Force an update of the document fields in the status bar.

=cut

sub refresh {
	my $self    = shift;
	my $current = $self->current;

	# Blank the status bar if no document is open
	my $editor = $current->editor or return $self->clear;

	# Prepare the various strings that form the status bar
	my $main     = $self->{main};
	my $document = $current->document;
	my $newline  = $document->newline_type || Padre::Constant::NEWLINE;
	$self->{_last_editor}   = $editor;
	$self->{_last_modified} = $editor->GetModify;
	my $position  = $editor->GetCurrentPos;
	my $line      = $editor->GetCurrentLine;
	my $start     = $editor->PositionFromLine($line);
	my $lines     = $editor->GetLineCount;
	my $char      = $position - $start;
	my $width     = $self->GetCharWidth;
	my $percent   = int( 100 * $line / $lines );
	my $mime_name = Wx::gettext( $document->mime->name );
	my $format    = '%' . length( $lines + 1 ) . 's,%-3s %3s%%';
	my $length    = length( $lines + 1 ) + 8;
	my $postring  = sprintf( $format, ( $line + 1 ), $char, $percent );
	my $rdstatus  = $self->is_read_only;

	# update task load status
	$self->update_task_status;

	# Write the new values into the status bar and update sizes
	if (    defined( $main->{infomessage} )
		and ( $main->{infomessage} ne '' )
		and ( $main->{infomessage_timeout} > time ) )
	{
		$self->SetStatusText( $main->{infomessage}, FILENAME );
	} else {
		my $config = $self->config;
		$self->{_template_} = $main->process_template( $config->main_statusbar_template );
		my $status = $main->process_template_frequent( $self->{_template_} );
		$self->SetStatusText( $status, FILENAME );
	}
	$self->SetStatusText( $mime_name, MIMETYPE );
	$self->SetStatusText( $newline,   NEWLINE  );
	$self->SetStatusText( $postring,  POSTRING );
	$self->SetStatusText( $rdstatus,  RDONLY   );
	$self->SetStatusWidths(
		-1,
		$self->_task_width,
		( length($mime_name) + 2 ) * $width,
		( length($newline) + 2 ) * $width,
		( $length + 2 ) * $width,
		( length($rdstatus) + 2 ) * $width,
	);

	# Move the static bitmap holding the task load status
	$self->_move_bitmap;

	return;
}

=pod

=head2 C<update_task_status>

    $statusbar->update_task_status;

Checks whether a task status icon update is in order and if so, changes
the icon to one of the other states

=cut

sub update_task_status {
	my $self   = shift;
	my $status = $self->_get_task_status;
	return if $status eq $self->_task_status; # Nothing to do

	# Store new status
	$self->_task_status($status);
	my $sbmp = $self->_task_sbmp;

	# If we're idling, just hide the icon in the statusbar
	if ( $status eq 'idle' ) {
		$sbmp->Hide;
		$sbmp->SetBitmap(Wx::NullBitmap);
		$sbmp->SetToolTip('');
		$self->_task_width(0);
		return;
	}

	# Not idling, show the correct icon in the statusbar
	$sbmp->SetBitmap( Padre::Wx::Icon::find("status/padre-tasks-$status") );
	$sbmp->SetToolTip(
		$status eq 'running'
		? Wx::gettext('Background Tasks are running')
		: Wx::gettext('Background Tasks are running with high load')
	);
	$sbmp->Show;
	$self->_task_width(20);
}

=pod

=head2 C<update_pos>

    $statusbar->update_pos;

Update the cursor position

=cut

sub update_pos {
	my $self = shift;

	my $current  = $self->current;
	my $editor   = $current->editor or return $self->clear;
	my $position = $editor->GetCurrentPos;

	# Skip expensive update if there is nothing to update:
	return if defined( $self->{Last_Pos} ) and ( $self->{Last_Pos} == $position );

	# Detect modification:
	unless (defined( $self->{_last_editor} )
		and ( $self->{_last_editor} eq $editor )
		and defined( $self->{_last_modified} )
		and ( $self->{_last_modified} == $editor->GetModify ) )
	{

		# Either the tab has changed or the file has been modified:
		$self->refresh;

	}

	$self->{Last_Pos} = $position;

	my $line    = $editor->GetCurrentLine;
	my $start   = $editor->PositionFromLine($line);
	my $lines   = $editor->GetLineCount;
	my $char    = $position - $start;
	my $percent = int( 100 * $line / $lines );

	my $format = '%' . length( $lines + 1 ) . 's,%-3s %3s%%';
	my $postring = sprintf( $format, ( $line + 1 ), $char, $percent );

	$self->SetStatusText( $postring, POSTRING );


}

# this sub is called frequently, on every key stroke or mouse movement
# TODO speed should be improved
sub refresh_from_template {
	my $self = shift;

	return unless $self->{_template_};

	my $main   = $self->{main};
	my $status = $main->process_template_frequent( $self->{_template_} );
	$self->SetStatusText( $status, FILENAME );

	return;
}

#####################################################################

=pod

=head2 C<on_resize>

    $statusbar->on_resize( $event );

Handler for the C<EVT_SIZE> C<$event>. Used to move the task load bitmap to
its position.

=cut

sub on_resize {
	my ($self) = @_;

	# note: parent resize method will be called automatically

	$self->_move_bitmap;
	$self->Refresh;
}

#####################################################################
# Private methods

#
# my $status = $self->_get_task_status;
#
# return 'idle', 'running' or 'load' depending on the number of threads
# currently working.
#
sub _get_task_status {
	my $self    = shift;
	my $manager = undef; # $self->current->ide->task_manager;

	# still in editor start-up phase, default to idle
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
# $statusbar->_move_bitmap;
#
# move the static bitmap holding the task load status to its proper location.
#
sub _move_bitmap {
	my ($self) = @_;
	my $sbmp   = $self->_task_sbmp;
	my $rect   = $self->GetFieldRect(TASKLOAD);
	my $size   = $sbmp->GetSize;
	$sbmp->Move(
		$rect->GetLeft + ( $rect->GetWidth - $size->GetWidth ) / 2,
		$rect->GetTop +  ( $rect->GetHeight - $size->GetHeight ) / 2,
	);
	$sbmp->Refresh;
}

sub is_read_only {
	my ($self) = @_;

	my $document = $self->current->document;
	return '' unless defined($document);

	return $document->is_readonly ? Wx::gettext('Read Only') : Wx::gettext('R/W');
}


1;

=pod

=head1 SEE ALSO

Icons for background status courtesy of Mark James, at
L<http://www.famfamfam.com/lab/icons/silk/>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::StatusBar;

=head1 NAME

Padre::Wx::StatusBar - Encapsulates status bar customizations



=head1 DESCRIPTION

C<Padre::Wx::StatusBar> implements Padre's statusbar. It is the bottom pane
holding various, err, status information on Padre.

It inherits from C<Wx::StatusBar>, so check wx documentation to see all the
available methods that can be applied to it besides the added ones (see below).


=cut


use strict;
use warnings;
use Padre::Util    ();
use Padre::Wx      ();
use Padre::Current ();

use Class::XSAccessor
    accessors => {
        _task_load_width => '_task_load_width',
    };
our $VERSION = '0.35';
use base 'Wx::StatusBar';

use constant {
	FILENAME => 0,
	TASKLOAD => 1,
	MIMETYPE => 2,
	NEWLINE  => 3,
	POSTRING => 4,
};


#####################################################################

=head1 PUBLIC API

=head2 Constructor

There's only one constructor for this class.

=over 4

=item * my $statusbar = Padre::Wx::StatusBar->new( $main );

Create and return a new Padre statusbar. One should pass the C<$main> Padre
window as argument, to get a reference to the statusbar parent.

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the basic object
	my $self = $class->SUPER::new( $main, -1, Wx::wxST_SIZEGRIP | Wx::wxFULL_REPAINT_ON_RESIZE );

	# Set up the fields
    my $taskload_width = 16;
    $self->_task_load_width($taskload_width);
	$self->SetFieldsCount(5);
	$self->SetStatusWidths( -1, $taskload_width, 100, 50, 100 );

	return $self;
}


=back

=cut


#####################################################################

=head2 Public Methods


=over 4

=item * $sb->clear;

Clear all the status bar fields, ie, they will display an empty string in all
fields.

=cut


sub clear {
	my $self = shift;
	$self->SetStatusText( "", FILENAME );
	$self->SetStatusText( "", MIMETYPE );
	$self->SetStatusText( "", NEWLINE  );
	$self->SetStatusText( "", POSTRING );
	return;
}


=item * my $main = $sb->main;

Handy method to get a reference on Padre's main window.

=cut

sub main {
	$_[0]->GetParent;
}


=item * my $current = $sb->current;

Get a new C<Padre::Current> object.

=cut

sub current {
	Padre::Current->new( main => $_[0]->GetParent, );
}


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

	# Write the new values into the status bar and update sizes
	$self->SetStatusText( "$modified $filename", FILENAME );
	$self->SetStatusText( $mimetype,             MIMETYPE );
	$self->SetStatusText( $newline,              NEWLINE  );
	$self->SetStatusText( $postring,             POSTRING );
	$self->SetStatusWidths(
		-1,
        $self->_task_load_width,
		( length($mimetype) ) * $width,
		( length($newline) + 2 ) * $width,
		( length($postring) + 4 ) * $width,
	);

	# Fixed ticket #190: Massive GDI object leakages
	# http://padre.perlide.org/ticket/190
	# Please remember to call SetPageText once per the same text
	# This still leaks but far less slowly (just on undo)
	if ( $old ne $title ) {
		$notebook->SetPageText( $pageid, $title );
	}

	return;
}

=back



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

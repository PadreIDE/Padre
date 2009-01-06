package Padre::Wx::StatusBar;

# Encapsulates status bar customisations

use strict;
use warnings;
use Padre::Util    ();
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.24';
our @ISA     = 'Wx::StatusBar';

use Class::XSAccessor
	getters => {
		main => 'main',
	};

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the basic object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::wxST_SIZEGRIP | Wx::wxFULL_REPAINT_ON_RESIZE
	);
	$self->{main} = $main;

	# Set up the fields
	$self->SetFieldsCount(4);
	$self->SetStatusWidths(-1, 100, 50, 100);

	# Put the status bar onto the parent frame
	$main->SetStatusBar($self);

	return $self;
}

sub clear {
	my $self = shift;
	$self->SetStatusText("", 0);
	$self->SetStatusText("", 1);
	$self->SetStatusText("", 2);
	$self->SetStatusText("", 3);
	return;
}

sub current {
	Padre::Current->new(
		main => $_[0]->main,
	);
}

sub refresh {
	my $self     = shift;
	my $current  = $self->current;

	# Blank the status bar if no document is open
	my $editor   = $current->editor or return $self->clear;

	# Prepare the various strings that form the status bar
	my $notebook = $current->_notebook;
	my $document = $current->document;
	my $newline  = $document->get_newline_type || Padre::Util::NEWLINE;
	my $pageid   = $notebook->GetSelection;
	my $filename = $document->filename || '';
	my $old      = $notebook->GetPageText($pageid);
	my $text     = $filename
		? File::Basename::basename($filename)
		: substr($old, 1);
	my $modified = $editor->GetModify ? '*' : ' ';
	my $title    = $modified . $text;
	my $position = $editor->GetCurrentPos;
	my $line     = $editor->GetCurrentLine;
	my $start    = $editor->PositionFromLine($line);
	my $char     = $position - $start;
	my $width    = $self->GetCharWidth;
	my $mimetype = $document->get_mimetype;
	my $postring = Wx::gettext('L:')  . ($line + 1) . ' '
	             . Wx::gettext('Ch:') . $char;

	# Write the new values into the status bar and update sizes
	$self->SetStatusText( "$modified $filename", 0 );
	$self->SetStatusText( $mimetype,             1 );
	$self->SetStatusText( $newline,              2 );
	$self->SetStatusText( $postring,             3 );
	$self->SetStatusWidths(
		-1,
		(length($mimetype)    ) * $width,
		(length($newline)  + 2) * $width,
		(length($postring) + 2) * $width,
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

1;

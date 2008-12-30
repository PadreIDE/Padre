package Padre::Wx::StatusBar;

# Encapsulates status bar customisations

use strict;
use warnings;
use Padre::Util ();
use Padre::Wx   ();

our $VERSION = '0.22';
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

sub refresh {
	my $self = shift;
	my $main = $self->main;

	# Blank the status bar if no document is open
	my $pageid = $main->nb->GetSelection;
	if ( not defined $pageid or $pageid == -1) {
		$main->SetStatusText("", $_) for (0..3);
		return;
	}

	# Prepare the current state
	my $editor       = $main->nb->GetPage($pageid);
	my $doc          = Padre::Documents->current or return;
	my $line         = $editor->GetCurrentLine;
	my $filename     = $doc->filename || '';
	my $newline_type = $doc->get_newline_type || Padre::Util::NEWLINE;
	my $modified     = $editor->GetModify ? '*' : ' ';

	if ( $filename ) {
		$main->nb->SetPageText(
			$pageid,
			$modified . File::Basename::basename($filename)
		);
	} else {
		my $text = substr($main->nb->GetPageText($pageid), 1);
		$main->nb->SetPageText(
			$pageid,
			$modified . $text
		);
	}

	my $current = $editor->GetCurrentPos;
	my $start   = $editor->PositionFromLine($line);
	my $char    = $current - $start;

	$main->SetStatusText( "$modified $filename", 0 );

	my $width    = $main->{gui}->{statusbar}->GetCharWidth;
	my $mimetype = $doc->get_mimetype;
	my $position = Wx::gettext('L:') . ($line + 1)
		. ' '
		. Wx::gettext('Ch:') . $char;

	$main->SetStatusText( $mimetype,     1 );
	$main->SetStatusText( $newline_type, 2 );
	$main->SetStatusText( $position,     3 );

	# since charWidth is an average we adjust the values a little
	$main->{gui}->{statusbar}->SetStatusWidths(
		-1,
		(length($mimetype)        ) * $width,
		(length($newline_type) + 2) * $width,
		(length($position)     + 2) * $width
	); 

	return;
}

1;

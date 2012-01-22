package Padre::Wx::SelectionLock;

use 5.008;
use strict;
use warnings;
use Params::Util  ();
use Padre::Wx     ();
use Wx::Scintilla ();

our $VERSION = '0.94';

use Class::XSAccessor {
	getters => {
		object   => 'object',
		position => 'position',
		anchor   => 'anchor',
		start    => 'start',
		end      => 'end',
		vdelta   => 'vdelta',
		text     => 'text',
	},
};

sub new {
	my $class = shift;
	my $object = shift;
	unless ( Params::Util::_INSTANCE( $object, 'Wx::Scintilla::TextCtrl' ) ) {
		die "Did not provide a Wx::Scintilla::TextCtrl to lock";
	}

	# Capture the selection and relative position in the editor
	my $position = $object->GetCurrentPos;
	my $anchor   = $object->GetAnchor;

	# Find the relative offset of the start of the selection from the
	# top of the screen.
	my $start  = $position > $anchor ? $anchor : $position;
	my $end    = $position > $anchor ? $position : $anchor;
	my $first  = $object->GetFirstVisibleLine;
	my $vfirst = $object->VisibleFromDocLine($first);
	my $vstart = $object->VisibleFromDocLine($start);
	my $screen = $object->GetLinesOnScreen;
	my $vdelta = $vstart - $vfirst;
	unless ( $vdelta >= 0 and $vdelta <= $screen ) {
		# Select start is not visible on screen, do not store
		$vdelta = undef;
	}

	# Create the object
	return $class->new(
		object   => $object,
		position => $position,
		anchor   => $anchor,
		start    => $start,
		end      => $end,
		vdelta   => $vdelta,
		text     => $object->GetSelectedText,
	);
}

sub cancel {
	$_[0]->{cancel} = 1;
}

sub apply {
	my $object = $_[0]->{object};

	# If something is selected, don't restore the selection
	if ( $object->GetCurrentPos != $object->GetAnchor ) {
		return;
	}

	# Is the same content still at the original selection location
	if ( $_[0]->{text} ne $object->GetTextRange( $_[0]->{start}, $_[0]->{end} ) ) {
		return;
	}

	# Restore the selection
	my $lock = Wx::WindowUpdateLocker->new($object);
	$object->SetCurrentPos( $_[0]->{position} );
	$object->SetAnchor( $_[0]->{anchor} );

	# If the selection was on screen, restore to the same vertical
	# location in the editor.
	my $vstart = $object->VisibleFromDocLine( $_[0]->{start} );
	my $scroll = $vstart - $_[0]->{vdelta};

	### TO BE COMPLETED
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::FunctionList;

use 5.008;
use strict;
use warnings;
use Params::Util qw{ _STRING };
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.43';
our @ISA     = 'Wx::ListCtrl';

#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_SINGLE_SEL | Wx::wxLC_NO_HEADER | Wx::wxLC_REPORT | Wx::wxBORDER_NONE
	);

	# Set up the (only) column
	$self->InsertColumn( 0, $self->gettext_label );
	$self->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );

	# Snap to selected character
	Wx::Event::EVT_CHAR(
		$self,
		sub {
			$self->on_char( $_[1] );
		},
	);

	# Grab the kill focus to prevent deselection
	Wx::Event::EVT_KILL_FOCUS(
		$self,
		sub {
			return;
		},
	);

	# Double-click a function name
	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self, $self,
		sub {
			$self->on_list_item_activated( $_[1] );
		}
	);

	$self->Hide;

	return $self;
}

sub right {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub gettext_label {
	Wx::gettext('Functions');
}

#####################################################################
# Event Handlers

# To match the Ultraedit behaviour, the characters shouldn't accumulate
# into an overall string. Mostly this is because nobody can see what
# that string is, so it gets confusing fast.
sub on_char {
	my $self  = shift;
	my $event = shift;
	my $mod   = $event->GetModifiers || 0;
	my $code  = $event->GetKeyCode;

	# Remove the bit ( Wx::wxMOD_META) set by Num Lock being pressed on Linux
	# TODO: This is cargo-cult
	$mod = $mod & ( Wx::wxMOD_ALT + Wx::wxMOD_CMD + Wx::wxMOD_SHIFT );
	unless ($mod) {
		if ( $code <= 255 and $code > 0 and chr($code) =~ /^[\w_:-]$/ ) {

			# transform - => _ for convenience
			$code = 95 if $code == 45;

			# This does a partial match starting at the beginning of the function name
			my $position = $self->FindItem( 0, $code, 1 );
			if ( defined $position ) {
				$self->SetItemState(
					$position,
					Wx::wxLIST_STATE_SELECTED,
					Wx::wxLIST_STATE_SELECTED,
				);
			}
		}
	}

	$event->Skip(1);
	return;
}

sub on_list_item_activated {
	my $self  = shift;
	my $event = shift;

	# Which sub did they click
	my $subname = $event->GetItem->GetText;
	unless ( defined _STRING($subname) ) {
		return;
	}

	# Locate the function
	my $document = $self->main->current->document;
	my $editor   = $document->editor;
	my ( $start, $end ) = Padre::Util::get_matches(
		$editor->GetText,
		$document->get_function_regex($subname),
		$editor->GetSelection, # Provides two params
	);
	unless ( defined $start ) {

		# Couldn't find it
		return;
	}

	# Move the selection to the sub location
	$editor->goto_pos_centerize($start);

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

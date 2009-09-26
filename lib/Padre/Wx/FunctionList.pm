package Padre::Wx::FunctionList;

use 5.008;
use strict;
use warnings;
use Params::Util qw{ _STRING };
use Padre::Wx      ();
use Padre::Current ();

our $VERSION = '0.47';
our @ISA     = 'Wx::Panel';

#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the parent panel, which will contain the search and tree
	my $self = $class->SUPER::new(
		$main->right,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	
	# Store main for other methods
	$self->{main} = $main;

	# Temporary store for the function list.
	$self->{_methods} = [];

	# Create the search control
	$self->{search} = Wx::SearchCtrl->new(
		$self, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);

	# Create the functions list
	$self->{functions} = Wx::ListCtrl->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_SINGLE_SEL | Wx::wxLC_NO_HEADER | Wx::wxLC_REPORT | Wx::wxBORDER_NONE
	);

	# Set up the (only) column
	$self->{functions}->InsertColumn( 0, $self->gettext_label );
	$self->{functions}->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );

	# Create a sizer
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer->Add( $self->{search}, 0, Wx::wxALL | Wx::wxEXPAND, 0 );
	$sizer->Add( $self->{functions},   1, Wx::wxALL | Wx::wxEXPAND, 0 );

	# Fits panel layout
	$self->SetSizerAndFit($sizer);
	$sizer->SetSizeHints($self);

	# Snap to selected character
	Wx::Event::EVT_CHAR(
		$self->{functions},
		sub {
			$self->on_char( $_[1] );
		},
	);

	# Grab the kill focus to prevent deselection
	Wx::Event::EVT_KILL_FOCUS(
		$self->{functions},
		sub {
			return;
		},
	);

	# Double-click a function name
	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self->{functions}, $self->{functions},
		sub {
			$self->on_list_item_activated( $_[1] );
		}
	);

	return $self;
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
	my $document = $self->{main}->current->document;
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

#
# Refresh the functions list
#
sub refresh {
	my ($self, $current) = @_;

	# Flush the list if there is no active document
	my $document  = $current->document;
	my $functions = $self->{functions};
	unless ($document) {
		$functions->DeleteAllItems;
		return;
	}

	my $config  = $self->{main}->config;
	my @methods = $document->get_functions;
	if ( $config->main_functions_order eq 'original' ) {

		# That should be the one we got from get_functions
	} elsif ( $config->main_functions_order eq 'alphabetical_private_last' ) {

		# ~ comes after \w
		@methods = map { tr/~/_/; $_ } ## no critic
			sort
			map { tr/_/~/; $_ }        ## no critic
			@methods;
	} else {

		# Alphabetical (aka 'abc')
		@methods = sort @methods;
	}

	if ( scalar(@methods) == scalar( @{ $self->{_methods} } ) ) {
		my $new = join ';', @methods;
		my $old = join ';', @{ $self->{_methods} };
		return if $old eq $new;
	}

	$functions->DeleteAllItems;
	foreach my $method ( reverse @methods ) {
		$functions->InsertStringItem( 0, $method );
	}
	$functions->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );
	$self->{_methods} = \@methods;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

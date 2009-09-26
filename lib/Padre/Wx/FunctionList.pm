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
	$self->{search} = Wx::TextCtrl->new(
		$self, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER|Wx::wxSIMPLE_BORDER,
	);

	# Create the functions list
	$self->{functions} = Wx::ListBox->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxLB_SINGLE | Wx::wxBORDER_NONE
	);

	# Create a sizer
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer->Add( $self->{search},    0, Wx::wxALL | Wx::wxEXPAND );
	$sizer->Add( $self->{functions}, 1, Wx::wxALL | Wx::wxEXPAND );

	# Fits panel layout
	$self->SetSizerAndFit($sizer);
	$sizer->SetSizeHints($self);

	# Grab the kill focus to prevent deselection
	Wx::Event::EVT_KILL_FOCUS(
		$self->{functions},
		sub {
			return;
		},
	);

	# Double-click a function name
	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self->{functions},
		sub {
			$self->on_list_item_activated( $_[1] );
		}
	);


	# DOWN KEY/ENTER on the search field means select functions list
	Wx::Event::EVT_CHAR(
		$self->{search},
		sub {
			my ($this, $event)  = @_;

			my $code = $event->GetKeyCode;
			if ( $code == Wx::WXK_DOWN || $code == Wx::WXK_RETURN) {
				$self->{functions}->SetFocus;
				my $selection = $self->{functions}->GetSelection;
				if($selection == -1 && $self->{functions}->GetCount > 0) {
					$selection = 0;
				}
				$self->{functions}->Select($selection);
			} 

			$event->Skip(1);
		}
	);

	# React to user search
	Wx::Event::EVT_TEXT(
		$self,
		$self->{search},
		sub {
			$self->_update_functions_list;
		}
	);

	# Cancel the search when the user presses the X
	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self, 
		$self->{search},
		sub {
			$self->{search}->SetValue('');
		}
	);

	return $self;
}

sub gettext_label {
	Wx::gettext('Functions');
}

#####################################################################
# Event Handlers

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
	my ( $self, $current ) = @_;

	# Flush the list if there is no active document
	my $document  = $current->document;
	my $functions = $self->{functions};
	unless ($document) {
		$functions->Clear;
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

	$self->{_methods} = \@methods;

	$self->_update_functions_list;
}

#
# Populate the functions list with search results
#
sub _update_functions_list {
	my $self = shift;

	my $functions = $self->{functions};

	#quote the search string to make it safer
	my $search_expr = $self->{search}->GetValue();
	if ( $search_expr eq '' ) {
		$search_expr = '.*';
	} else {
		$search_expr = quotemeta $search_expr;
	}

	#populate the function list with matching functions
	$functions->Clear;
	foreach my $method ( reverse @{ $self->{_methods} } ) {
		if ( $method =~ /$search_expr/i ) {
			$functions->Insert( $method, 0 );
		}
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

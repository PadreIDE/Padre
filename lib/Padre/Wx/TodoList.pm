package Padre::Wx::TodoList;

use 5.008;
use strict;
use warnings;
use Params::Util qw{ _STRING };
use Padre::Wx ();
use Padre::Current ('_CURRENT');

our $VERSION = '0.63';
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

	# Temporary store for the todo list.
	$self->{_items} = [];

	# Create the search control
	$self->{search} = Wx::TextCtrl->new(
		$self, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER | Wx::wxSIMPLE_BORDER,
	);

	# Create the Todo list
	$self->{items} = Wx::ListBox->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxLB_SINGLE | Wx::wxBORDER_NONE
	);

	# Create a sizer
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer->Add( $self->{search}, 0, Wx::wxALL | Wx::wxEXPAND );
	$sizer->Add( $self->{items},  1, Wx::wxALL | Wx::wxEXPAND );

	# Fits panel layout
	$self->SetSizerAndFit($sizer);
	$sizer->SetSizeHints($self);

	# Grab the kill focus to prevent deselection
	Wx::Event::EVT_KILL_FOCUS(
		$self->{items},
		sub {
			return;
		},
	);

	# Double-click a function name
	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->{items},
		sub {
			$self->on_list_item_activated( $_[0], $_[1] );
		}
	);

	# Handle key events
	Wx::Event::EVT_KEY_UP(
		$self->{items},
		sub {
			my ( $this, $event ) = @_;
			if ( $event->GetKeyCode == Wx::WXK_RETURN ) {
				$self->on_list_item_activated($event);
			}
			$event->Skip(1);
		}
	);

	# Handle key events
	Wx::Event::EVT_CHAR(
		$self->{search},
		sub {
			my ( $this, $event ) = @_;

			my $code = $event->GetKeyCode;
			if ( $code == Wx::WXK_DOWN || $code == Wx::WXK_UP || $code == Wx::WXK_RETURN ) {

				# Up/Down and return keys focus on the functions lists
				$self->{items}->SetFocus;
				my $selection = $self->{items}->GetSelection;
				if ( $selection == -1 && $self->{items}->GetCount > 0 ) {
					$selection = 0;
				}
				$self->{items}->Select($selection);

			} elsif ( $code == Wx::WXK_ESCAPE ) {

				# Escape key clears search and returns focus
				# to the editor
				$self->{search}->SetValue('');
				my $current  = _CURRENT( $self->{main}->current );
				my $document = $current->document;
				if ($document) {
					$document->editor->SetFocus;
				}
			}

			$event->Skip(1);
		}
	);

	# React to user search
	Wx::Event::EVT_TEXT(
		$self,
		$self->{search},
		sub {
			$self->_update_list;
		}
	);

	$main->add_refresh_listener($self);

	return $self;
}

sub gettext_label {
	Wx::gettext('To-do');
}





#####################################################################
# Event Handlers

sub on_list_item_activated {
	my ( $self, $event ) = @_;

	# Which sub did they click
	my $item = $self->{items}->GetSelection;

	my $current  = _CURRENT( $self->{main}->current );
	my $document = $current->document or return;
	my $editor   = $document->editor;

	my $start = $self->{_items}->[$item];

	unless ( defined $start ) {

		# Couldn't find it
		return;
	}

	# Move the selection to the location
	$editor->goto_pos_centerize( $start->{pos} );

	return;
}

#
# Sets the focus on the search field
#
sub focus_on_search {
	my $self = shift;
	$self->{search}->SetFocus;
}

#
# Refresh the functions list
#
sub refresh {
	my ( $self, $current ) = @_;

	# Flush the list if there is no active document
	return unless $current;
	my $document = $current->document;
	my $items    = $self->{items};

	# Hide the widgets when no files are open
	if ($document) {
		$self->{search}->Show(1);
		$self->{items}->Show(1);
	} else {
		$items->Clear;
		$self->{search}->Hide;
		$self->{items}->Hide;
		$self->{_items} = [];
		return;
	}

	# Clear search when it is a different document
	if ( $self->{_document} && $document != $self->{_document} ) {
		$self->{search}->ChangeValue('');
	}
	$self->{_document} = $document;

	my $config = $self->{main}->config;
	my $regexp = $config->todo_regexp;

	#my @items = $document->get_todo; # XXX retrieving the list of items should become a method of ->document
	my $text = $document->text_get();
	my @items;
	while ( $text =~ /$regexp/gim ) {
		push @items, { text => $1 || '<no text>', 'pos' => pos($text) };
	}
	while ( $text =~ /#\s*(Ticket #\d+.*?)$/gim ) {
		push @items, { text => $1, 'pos' => pos($text) };
	}

	if ( scalar @items == 0 ) {
		$items->Clear;
		$self->{_items} = [];
		return;
	}

	#if ( $config->main_functions_order eq 'original' ) {

	# That should be the one we got from get_functions
	#} elsif ( $config->main_functions_order eq 'alphabetical_private_last' ) {
	#
	#	# ~ comes after \w
	#	tr/_/~/ foreach @methods;
	#	@methods = sort @methods;
	#	tr/~/_/ foreach @methods;
	#} else {

	# Alphabetical (aka 'abc')
	#@items = sort { $a->{text} cmp $b->{text} } @items;
	#}

	if ( scalar(@items) == scalar( @{ $self->{_items} } ) ) {
		my $new = join "\0", @items;
		my $old = join "\0", @{ $self->{_items} };
		return if $old eq $new;
	}

	$self->{_items} = \@items;

	# Show them again
	$self->{search}->Show;
	$self->{items}->Show;

	$self->_update_list;
}

#
# Populate the list with search results
#
sub _update_list {
	my $self = shift;

	my $items = $self->{items};

	#quote the search string to make it safer
	my $search_expr = $self->{search}->GetValue();
	if ( $search_expr eq '' ) {
		$search_expr = '.*';
	} else {
		$search_expr = quotemeta $search_expr;
	}

	#populate the function list with matching items
	$items->Clear;
	foreach my $item ( reverse @{ $self->{_items} } ) {
		if ( $item->{text} =~ /$search_expr/i ) {
			$items->Insert( $item->{text}, 0 );
		}
	}
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

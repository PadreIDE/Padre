package Padre::Wx::Syntax;

use 5.008;
use strict;
use warnings;
use Params::Util qw{_INSTANCE};
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.47';
our @ISA     = 'Wx::ListView';

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$main->bottom,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);

	my $list = Wx::ImageList->new( 14, 7 );
	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-error') );
	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-warning') );
	$self->AssignImageList( $list, Wx::wxIMAGE_LIST_SMALL );

	$self->InsertColumn( $_, _get_title($_) ) for 0 .. 2;

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self, $self,
		sub {
			$self->on_list_item_activated( $_[1] );
		},
	);
	Wx::Event::EVT_RIGHT_DOWN(
		$self, \&on_right_down,
	);

	$self->Hide;

	return $self;
}

sub bottom {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub gettext_label {
	Wx::gettext('Syntax Check');
}

# Remove all markers and empty the list
sub clear {
	my $self = shift;

	# Remove the margins for the syntax markers
	foreach my $editor ( Padre::Current->main($self)->editors ) {
		$editor->MarkerDeleteAll(Padre::Wx::MarkError);
		$editor->MarkerDeleteAll(Padre::Wx::MarkWarn);
	}

	# Remove all items from the tool
	$self->DeleteAllItems;

	return;
}

sub set_column_widths {
	my $self      = shift;
	my $ref_entry = shift;
	if ( !defined $ref_entry ) {
		$ref_entry = { line => ' ', };
	}

	my $width0_default = $self->GetCharWidth * length( Wx::gettext("Line") ) + 16;
	my $width0         = $self->GetCharWidth * length( $ref_entry->{line} x 2 ) + 14;

	my $refStr = '';
	if ( length( Wx::gettext('Warning') ) > length( Wx::gettext('Error') ) ) {
		$refStr = Wx::gettext('Warning');
	} else {
		$refStr = Wx::gettext('Error');
	}

	my $width1 = $self->GetCharWidth * ( length($refStr) + 2 );
	my $width2 = $self->GetSize->GetWidth - $width0 - $width1 - $self->GetCharWidth * 4;

	$self->SetColumnWidth( 0, ( $width0_default > $width0 ? $width0_default : $width0 ) );
	$self->SetColumnWidth( 1, $width1 );
	$self->SetColumnWidth( 2, $width2 );

	return;
}

#####################################################################
# Timer Control

sub start {
	my $self = shift;

	# Add the margins for the syntax markers
	foreach my $editor ( Padre::Current->main($self)->editors ) {

		# Margin number 1 for symbols
		$editor->SetMarginType( 1, Wx::wxSTC_MARGIN_SYMBOL );

		# Set margin 1 16 px wide
		$editor->SetMarginWidth( 1, 16 );
	}

	Padre::Util::debug('still starting the syntax checker');

	# List appearance: Initialize column widths
	$self->set_column_widths;

	if ( _INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->on_timer( undef, 1 );
	} else {
		Padre::Util::debug('Creating new timer');
		$self->{timer} = Wx::Timer->new(
			$self,
			Padre::Wx::ID_TIMER_SYNTAX
		);
		Wx::Event::EVT_TIMER(
			$self,
			Padre::Wx::ID_TIMER_SYNTAX,
			sub {
				$self->on_timer( $_[1], $_[2] );
			},
		);
	}
	$self->{timer}->Start( 1000, 0 );

	return;
}

sub stop {
	my $self = shift;

	# Stop the timer
	if ( _INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->{timer}->Stop;
	}

	# Clear out the existing data
	$self->clear;

	# Remove the editor margin
	foreach my $editor ( Padre::Current->main($self)->editors ) {
		$editor->SetMarginWidth( 1, 0 );
	}

	return;
}

sub running {
	!!( $_[0]->{timer} and $_[0]->{timer}->IsRunning );
}

#####################################################################
# Event Handlers

sub on_list_item_activated {
	my $self   = shift;
	my $event  = shift;
	my $editor = Padre::Current->main($self)->current->editor;
	my $line   = $event->GetItem->GetText;

	if (   not defined($line)
		or $line !~ /^\d+$/o
		or $editor->GetLineCount < $line )
	{
		return;
	}

	$self->select_problem( $line - 1 );

	return;
}

#
# Selects the problemistic line :)
#
sub select_problem {
	my ( $self, $line ) = @_;

	my $editor = Padre::Current->main($self)->current->editor;
	return if not $editor;

	$editor->EnsureVisible($line);
	$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
	$editor->SetFocus;
}

#
# Selects the next problem in the editor.
# Wraps to the first one when at the end.
#
sub select_next_problem {
	my $self = shift;

	my $editor = Padre::Current->main($self)->current->editor;
	return if not $editor;
	my $current_line = $editor->LineFromPosition( $editor->GetCurrentPos );

	my $first_line = undef;
	foreach my $i ( 0 .. $self->GetItemCount - 1 ) {

		# Get the line and check that it is a valid line number
		my $line = $self->GetItem($i)->GetText;
		next
			if ( not defined($line) )
			or ( $line !~ /^\d+$/o )
			or ( $line > $editor->GetLineCount );
		$line--;

		if ( not $first_line ) {

			# record the position of the first problem
			$first_line = $line;
		}

		if ( $line > $current_line ) {

			# select the next problem
			$self->select_problem($line);

			# no need to wrap around...
			$first_line = undef;

			# and we're done here...
			last;
		}
	}

	if ($first_line) {

		#the next problem is simply the first (wrap around)
		$self->select_problem($first_line);
	}
}

sub on_timer {
	my $self   = shift;
	my $event  = shift;
	my $force  = shift;
	my $editor = Padre::Current->main($self)->current->editor or return;

	my $document = $editor->{Document};

	# Don't check without document of if the document has no checker
	unless ( $document and $document->can('check_syntax') ) {
		$self->clear;
		return;
	}

	# Don't really check while typing but check if typing pauses,
	# because the user usually won't stop typing to correct a
	# syntax error but finish the current line and then fix the typo
	if ( defined( $document->{last_char_time} ) ) {
		if ( $self->main->ide->{has_Time_HiRes} ) {

			# Not typing for 500ms usually means that you got
			# time to look at the syntax check results
			return if ( Time::HiRes::time() - $document->{last_char_time} ) < .5;
		} else {

			# Without HiRes, we could only set the timeout to
			# one second, but this is very inaccurate
			return if $document->{last_char_time} == time;
		}
	}

	my $pre_exec_result = $document->check_syntax_in_background( force => $force );

	# In case we have created a new and still completely empty doc we
	# need to clean up the message list
	if ( ref $pre_exec_result eq 'ARRAY' && !@{$pre_exec_result} ) {
		$self->clear;
	}

	if ( defined $event ) {
		$event->Skip(0);
	}

	return;
}

sub _get_title {
	my $c = shift;

	return Wx::gettext('Line')        if $c == 0;
	return Wx::gettext('Type')        if $c == 1;
	return Wx::gettext('Description') if $c == 2;

	die "invalid value '$c'";
}

sub relocale {
	my $self = shift;

	for my $i ( 0 .. 2 ) {
		my $col = $self->GetColumn($i);
		$col->SetText( _get_title($i) );
		$self->SetColumn( $i, $col );
	}

	return;
}

#
# Called when the user presses a right click or a context menu key (on win32)
#
sub on_right_down {
	my ( $self, $event ) = @_;

	return if $self->GetItemCount == 0;

	# Create the popup menu
	my $menu = Wx::Menu->new;

	if ( $self->GetFirstSelected != -1 ) {

		# Copy selected
		Wx::Event::EVT_MENU(
			$self,
			$menu->Append( -1, Wx::gettext("Copy &Selected") ),
			sub {

				# Get selected message
				my $msg       = '';
				my $selection = $self->GetFirstSelected;
				if ( $selection != -1 ) {
					my $line = $self->GetItem( $selection, 0 )->GetText || '';
					my $type = $self->GetItem( $selection, 1 )->GetText || '';
					my $desc = $self->GetItem( $selection, 2 )->GetText || '';
					$msg = "$line, $type, $desc\n";

					# And copy it to clipboard
					if ( ( length $msg > 0 ) and Wx::wxTheClipboard->Open() ) {
						Wx::wxTheClipboard->SetData( Wx::TextDataObject->new($msg) );
						Wx::wxTheClipboard->Close();
					}
				}
			}
		);
	}

	# Copy all
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext("Copy &All") ),
		sub {

			# Append messages in one string
			my $msg = '';
			foreach my $i ( 0 .. $self->GetItemCount - 1 ) {

				my $line = $self->GetItem( $i, 0 )->GetText || '';
				my $type = $self->GetItem( $i, 1 )->GetText || '';
				my $desc = $self->GetItem( $i, 2 )->GetText || '';
				$msg .= "$line, $type, $desc\n";
			}

			# And copy it to clipboard
			if ( ( length $msg > 0 ) and Wx::wxTheClipboard->Open() ) {
				Wx::wxTheClipboard->SetData( Wx::TextDataObject->new($msg) );
				Wx::wxTheClipboard->Close();
			}
		}
	);

	if ( $event->isa('Wx::MouseEvent') ) {
		$self->PopupMenu( $menu, $event->GetX, $event->GetY );
	} else { #Wx::CommandEvent
		$self->PopupMenu( $menu, 50, 50 ); # TODO better location
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Syntax;

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Logger;

our $VERSION = '0.64';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::ListView
};

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);

	# Additional properties
	$self->{model}    = [];
	$self->{document} = '';
	$self->{length}   = -1;

	# Prepare the available images
	my $list = Wx::ImageList->new( 16, 16 );
	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-error') );
	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-warning') );
	$list->Add( Padre::Wx::Icon::icon('status/padre-syntax-ok') );
	$self->AssignImageList( $list, Wx::wxIMAGE_LIST_SMALL );

	# Flesh out the columns
	my @titles = $self->titles;
	foreach ( 0 .. 2 ) {
		$self->InsertColumn( $_, $titles[$_] );
	}

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self,
		sub {
			shift->on_list_item_activated(@_);
		},
	);
	Wx::Event::EVT_RIGHT_DOWN(
		$self,
		sub {
			shift->on_right_down(@_);
		},
	);

	$self->Hide;

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	shift->main->show_syntax(0);
}





#####################################################################
# Timer Control

sub start {
	my $self = shift;
	$self->running and return;
	TRACE('Starting the syntax checker') if DEBUG;

	# Add the margins for the syntax markers
	foreach my $editor ( $self->main->editors ) {

		# Margin number 1 for symbols
		$editor->SetMarginType( 1, Wx::wxSTC_MARGIN_SYMBOL );

		# Set margin 1 16 px wide
		$editor->SetMarginWidth( 1, 16 );
	}

	# List appearance: Initialize column widths
	$self->set_column_widths;

	if ( Params::Util::_INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->on_timer( undef, 1 );
	} else {
		TRACE('Creating new timer') if DEBUG;
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
	$self->running or return;
	TRACE('Stopping the syntax checker') if DEBUG;

	# Stop the timer
	if ( Params::Util::_INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->{timer}->Stop;
	}

	# Remove the editor margin
	foreach my $editor ( $self->main->editors ) {
		$editor->SetMarginWidth( 1, 0 );
	}

	# Clear out the existing data
	$self->clear;

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
	my $editor = $self->current->editor or return;
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

# Called when the user presses a right click or a context menu key (on win32)
sub on_right_down {
	my $self  = shift;
	my $event = shift;

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
				Wx::wxTheClipboard->Close;
			}
		}
	);

	if ( $event->isa('Wx::MouseEvent') ) {
		$self->PopupMenu( $menu, $event->GetX, $event->GetY );
	} else { #Wx::CommandEvent
		$self->PopupMenu( $menu, 50, 50 ); # TO DO better location
	}
}

sub on_timer {
	my $self  = shift;
	my $event = shift;
	$event->Skip(0) if defined $event;
	$self->refresh;
}






#####################################################################
# General Methods

sub bottom {
	TRACE("DEPRECATED") if DEBUG;
	shift->main->bottom;
}

sub gettext_label {
	Wx::gettext('Syntax Check');
}

sub titles {
	return (
		Wx::gettext('Line'),
		Wx::gettext('Type'),
		Wx::gettext('Description'),
	);
}

# Remove all markers and empty the list
sub clear {
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');

	# Remove the margins for the syntax markers
	foreach my $editor ( $self->main->editors ) {
		$editor->MarkerDeleteAll(Padre::Wx::MarkError);
		$editor->MarkerDeleteAll(Padre::Wx::MarkWarn);
	}

	# Remove all items from the tool
	$self->DeleteAllItems;

	return;
}

sub relocale {
	my $self   = shift;
	my @titles = $self->titles;
	foreach my $i ( 0 .. 2 ) {
		my $col = $self->GetColumn($i);
		$col->SetText( $titles[$i] );
		$self->SetColumn( $i, $col );
	}
	return;
}

sub refresh {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $length   = $document->text_length;

	if ( $document eq $self->{document} ) {
		# Shortcut if nothing has changed.
		# NOTE: Given the speed at which the timer fires a cheap
		# length check is better than an expensive MD5 check.
		if ( $length eq $self->{length} ) {
			return;
		}
	} else {
		# New file, don't keep the current list visible
		$self->clear;
	}
	$self->{document} = $document;
	$self->{length}   = $length;

	# Fire the background task discarding old results
	$self->task_reset;
	$self->task_request(
		task     => $document->task_syntax,
		document => $document,
	);
}

sub task_response {
	my $self = shift;
	my $task = shift;
	$self->{model} = $task->{model};
	$self->render;
}

sub render {
	my $self     = shift;
	my $model    = $self->{model} || [];
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $filename = $current->filename;
	my $lock     = $self->main->lock('UPDATE');

	# Flush old results
	$self->clear;

	# If there are no errors clear the synax checker pane
	unless ( Params::Util::_ARRAY($model) ) {
		my $i = $self->InsertStringImageItem( 0, '', 2 );
		$self->SetItemData( $i, 0 );
		$self->SetItem( $i, 1, Wx::gettext('Info') );

		# Relative-to-the-project filename.
		# Check that the document has been saved.
		if ( defined $filename ) {
			my $project_dir = $document->project_dir;
			if ( defined $project_dir ) {
				$project_dir = quotemeta $project_dir;
				$filename =~ s/^$project_dir[\\\/]?//;
			}
			$self->SetItem( $i, 2, sprintf( Wx::gettext('No errors or warnings found in %s.'), $filename ) );
		} else {
			$self->SetItem( $i, 2, Wx::gettext('No errors or warnings found.') );
		}
		return;
	}

	# Eliminate some warnings
	foreach my $hint ( @$model ) {
		$hint->{line} = 0  unless defined $hint->{line};
		$hint->{msg}  = '' unless defined $hint->{msg};
	}

	my @MARKER = ( Padre::Wx::MarkError(), Padre::Wx::MarkWarn() );
	my @LABEL  = ( Wx::gettext('Warning'), Wx::gettext('Error')  );

	my $i = 0;
	foreach my $hint ( sort { $a->{line} <=> $b->{line} } @$model ) {
		my $line     = $hint->{line} - 1;
		my $severity = $hint->{severity};
		$editor->MarkerAdd( $line, $MARKER[$severity] );
		my $item = $self->InsertStringImageItem( $i++, $line + 1, $severity );
		$self->SetItemData( $item, 0 );
		$self->SetItem( $item, 1, $LABEL[$severity] );
		$self->SetItem( $item, 2, $hint->{msg}      );
	}

	$self->set_column_widths($model->[-1]);

	return 1;
}

sub set_column_widths {
	my $self = shift;
	my $item = shift || { line => ' ' };

	my $width0_default = $self->GetCharWidth * length( Wx::gettext("Line") ) + 16;
	my $width0         = $self->GetCharWidth * length( $item->{line} x 2 ) + 14;

	my $ref_str = '';
	if ( length( Wx::gettext('Warning') ) > length( Wx::gettext('Error') ) ) {
		$ref_str = Wx::gettext('Warning');
	} else {
		$ref_str = Wx::gettext('Error');
	}

	my $width1 = $self->GetCharWidth * ( length($ref_str) + 2 );
	my $width2 = $self->GetSize->GetWidth - $width0 - $width1 - $self->GetCharWidth * 4;

	$self->SetColumnWidth( 0, ( $width0_default > $width0 ? $width0_default : $width0 ) );
	$self->SetColumnWidth( 1, $width1 );
	$self->SetColumnWidth( 2, $width2 );

	return;
}

# Selects the problemistic line :)
sub select_problem {
	my $self   = shift;
	my $line   = shift;
	my $editor = $self->current->editor or return;
	$editor->EnsureVisible($line);
	$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
	$editor->SetFocus;
}

# Selects the next problem in the editor.
# Wraps to the first one when at the end.
sub select_next_problem {
	my $self   = shift;
	my $editor = $self->current->editor or return;
	my $line   = $editor->LineFromPosition( $editor->GetCurrentPos );

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

		if ( $line > $line ) {

			# select the next problem
			$self->select_problem($line);

			# no need to wrap around...
			$first_line = undef;

			# and we're done here...
			last;
		}
	}

	# The next problem is simply the first (wrap around)
	$self->select_problem($first_line) if $first_line;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

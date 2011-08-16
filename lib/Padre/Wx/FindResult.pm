package Padre::Wx::FindResult;

=pod

=head1 NAME

Padre::Wx::FindResult - Find and list all occurrences

=head1 DESCRIPTION

C<Padre::Wx::FindResult> Displays a list of all the occurrences of term
in a file.   Clicking on an item in the list will go to the line in that editor.

=cut

use 5.008;
use strict;
use warnings;
use Params::Util qw{_INSTANCE};
use Padre::Wx;
use Wx::Event qw( EVT_BUTTON );


our $VERSION = '0.90';
our @ISA     = 'Wx::ListView';

use Class::XSAccessor {
	getters => {
		line_count => 'line_count',
	}
};

=pod

=head3 C<new>

Create the new B<Find results> panel.

=cut


sub new {
	my ( $class, $main, $lines, $editor ) = @_;

	#ensure the bottom aui is present.
	$main->show_output(1);

	# Create the underlying object
	my $self = $class->SUPER::new(
		Padre::Current->main->bottom,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL
	);

	$self->set_column_widths;
	$self->InsertColumn( $_, _get_title($_) ) for 0 .. 1;

	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self, $self,
		sub {
			$self->on_list_item_activated( $_[1], $main, $editor );
		},
	);
	Wx::Event::EVT_RIGHT_DOWN(
		$self, \&on_right_down,
	);

	$self->{line_count} = scalar(@$lines);
	$self->populate_list($lines);
	Padre::Current->main->bottom->show($self);

	return $self;
}

=pod

=head3 C<gettext_label>

Sets the label of the tab. Called automatically when the object is created.

=cut

sub gettext_label {
	my ($self) = @_;

	sprintf( Wx::gettext('Find Results (%s)'), $self->line_count );
}


=pod

=head3 C<set_column_widths>

   $self->set_column_widths

Works out the correct column widths for the list columns.

=cut

sub set_column_widths {
	my $self = shift;

	$self->SetColumnWidth( 0, Wx::wxLIST_AUTOSIZE );
	$self->SetColumnWidth( 1, Wx::wxLIST_AUTOSIZE );

	return;
}

=pod

=head3 C<on_list_item_activated>

On double click event go to the selected line in the editor

=cut

sub on_list_item_activated {
	my ( $self, $event, $main, $editor ) = @_;

	#If the user has closed the editor the search was originally performed on
	if ( !defined $main->editor_id($editor) ) {
		$self->DeleteAllItems;
		my $message_item->[0]->{line} = Wx::gettext('Related editor has been closed');
		$message_item->[0]->{lineNumber} = '*';
		$self->populate_list($message_item);
		return;
	}
	my $line = $event->GetItem->GetText;

	if (   not defined($line)
		or $line !~ /^\d+$/o
		or $editor->GetLineCount < $line )
	{
		return;
	}

	$self->select_line( $line - 1, $editor );

	return;
}

=pod

=head3 C<select_line>

   $self->select_line($lineNumber, $editor);

Sets the focus to the selected line.

=cut

sub select_line {
	my ( $self, $line, $editor ) = @_;

	return if not $editor;

	$editor->EnsureVisible($line);
	$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
	$editor->SetFocus;
}

=pod

=head3 C<_get_title>

   $self->_get_title;

Set the column headings to the list.

=cut

sub _get_title {
	my $c = shift;

	return Wx::gettext('Line')    if $c == 0;
	return Wx::gettext('Content') if $c == 1;

	die "invalid value '$c'";
}

=pod

=head3 C<relocale>

   $self->relocale;

Reset the column headings if locales are changed.

=cut

sub relocale {
	my $self = shift;

	foreach my $i ( 0 .. 1 ) {
		my $col = $self->GetColumn($i);
		$col->SetText( _get_title($i) );
		$self->SetColumn( $i, $col );
	}

	return;
}

=pod

=head3 C<on_right_down>

Called when the user presses a right click or a context menu key (on Win32).

=cut

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
					my $text = $self->GetItem( $selection, 1 )->GetText || '';
					$msg = "$text\n";

					# And copy it to clipboard
					if ( ( length $msg > 0 ) and Wx::wxTheClipboard->Open ) {
						Wx::wxTheClipboard->SetData( Wx::TextDataObject->new($msg) );
						Wx::wxTheClipboard->Close;
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

				my $text = $self->GetItem( $i, 0 )->GetText || '';
				$msg .= "$text\n";
			}

			# And copy it to clipboard
			if ( ( length $msg > 0 ) and Wx::wxTheClipboard->Open ) {
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

=pod

=head3 C<populate_list>

	my $entry->[0]->{lineNumber} = 10;
	$entry->[0]->{line} = ' this is at line 10';
	$self->populate_list($entry);

Populate the list with the line number and text.

=cut

# populates the list

sub populate_list {
	my $self  = shift;
	my $lines = shift;
	foreach my $line (@$lines) {
		my $item = $self->InsertStringItem( 0, $line->[0] );
		$self->SetItem( $item, 1, $line->[1] );
	}
}

sub view_close {
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

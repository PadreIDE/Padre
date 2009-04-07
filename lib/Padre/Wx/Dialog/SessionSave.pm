#
# This file is part of Padre, the Perl ide.
#

package Padre::Wx::Dialog::SessionSave;

use strict;
use warnings;

use Class::XSAccessor accessors => {
	_butdelete    => '_butdelete',      # delete button
	_butopen      => '_butopen',        # open button
	_currow       => '_currow',         # current list row number
	_curname      => '_curname',        # name of current session selected
	_list         => '_list',           # list on the left of the pane
	_sortcolumn   => '_sortcolumn',     # column used for list sorting
	_sortreverse  => '_sortreverse',    # list sorting is reversed
	_sizer        => '_sizer',          # the window sizer
};
use Wx qw{ :everything };

use base 'Wx::Frame';

our $VERSION = '0.33';


# -- constructor

sub new {
	my ( $class, $parent ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Save session as...'),
		wxDefaultPosition,
		wxDefaultSize,
		wxDEFAULT_FRAME_STYLE,
	);
	$self->SetIcon( Wx::GetWxPerlIcon() );

	# create dialog
	$self->_create;

	return $self;
}

# -- public methods

sub show {
	my $self = shift;
	$self->_refresh_list;
	$self->Show;
}

# -- gui handlers

#
# $self->_on_butclose_clicked;
#
# handler called when the close button has been clicked.
#
sub _on_butclose_clicked {
	my $self = shift;
	$self->Destroy;
}

#
# $self->_on_butdelete_clicked;
#
# handler called when the delete button has been clicked.
#
sub _on_butdelete_clicked {
	my $self    = shift;
    my $current = $self->_current_session;

    # remove session: files, then session itself
    Padre::DB->begin;
    Padre::DB::SessionFile->delete('where session = ?', $current->id);
    $current->delete;
    Padre::DB->commit;

    # update gui
    $self->_refresh_list;
    $self->_select_first_item;
	$self->_update_buttons_state;
}

#
# $self->_on_butopen_clicked;
#
# handler called when the open button has been clicked.
#
sub _on_butopen_clicked {
	my $self = shift;

    # close all open documents
    my $main = $self->GetParent;
	$main->open_session( $self->_current_session );
}

#
# $self->_on_list_col_click;
#
# handler called when a column has been clicked, to reorder the list.
#
sub _on_list_col_click {
	my ( $self, $event ) = @_;
	my $col = $event->GetColumn;

	my $prevcol  = $self->_sortcolumn  || 0;
	my $reversed = $self->_sortreverse || 0;
	$reversed = $col == $prevcol ? !$reversed : 0;
	$self->_sortcolumn($col);
	$self->_sortreverse($reversed);
	$self->_refresh_list( $col, $reversed );
}


#
# $self->_on_list_item_selected( $event );
#
# handler called when a list item has been selected. it will in turn update
# the buttons state.
#
# $event is a Wx::ListEvent.
#
sub _on_list_item_selected {
	my ( $self, $event ) = @_;

	my $name = $event->GetLabel;
	$self->_curname($name);                # storing selected session
	$self->_currow( $event->GetIndex );    # storing selected row

	# update buttons
	$self->_update_buttons_state;
}

# -- private methods

#
# $self->_create;
#
# create the dialog itself.
#
# no params, no return values.
#
sub _create {
	my $self = shift;

	# create sizer that will host all controls
	my $sizer = Wx::GridBagSizer->new(5,5);
	$sizer->AddGrowableCol(1);
	$self->SetSizer($sizer);
	$self->_sizer($sizer);

	$self->_create_fields;
	$self->_create_buttons;
}

#
# $dialog->_create_fields;
#
# create the combo box with the sessions. it will hold a list of
# available sessions (but still allowing user to add another value), and
# a description field.
#
# no params. no return values.
#
sub _create_fields {
	my $self  = shift;
	my $sizer = $self->_sizer;

	# session name
	my $lab1  = Wx::StaticText->new( $self, -1, Wx::gettext('Session name:') );
	my $combo = Wx::ComboBox->new  ( $self, -1, '' );
	$sizer->Add( $lab1,  Wx::GBPosition->new(0,0) );
	$sizer->Add( $combo, Wx::GBPosition->new(0,1), Wx::GBSpan->new(1,3), wxEXPAND );

	# session descritpion
	my $lab2  = Wx::StaticText->new( $self, -1, Wx::gettext('Description:') );
	my $text  = Wx::TextCtrl->new  ( $self, -1, '' );
	$sizer->Add( $lab2, Wx::GBPosition->new(1,0) );
	$sizer->Add( $text, Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,3), wxEXPAND );
}

#
# $dialog->_create_buttons;
#
# create the buttons pane.
#
# no params. no return values.
#
sub _create_buttons {
	my $self = shift;

	my $sizer = $self->_sizer;

	# the buttons
	my $bs  = Wx::Button->new( $self, -1, Wx::gettext('Save') );
	my $bc  = Wx::Button->new( $self, -1, Wx::gettext('Close') );
	Wx::Event::EVT_BUTTON( $self, $bs, \&_on_butsave_clicked );
	Wx::Event::EVT_BUTTON( $self, $bc, \&_on_butclose_clicked );
	$sizer->Add( $bs, Wx::GBPosition->new(2,2) );
	$sizer->Add( $bc, Wx::GBPosition->new(2,3) );

}

#
# my $session = $self->_current_session;
#
# return the padre::db::session object corresponding to currently selected line
# in the list. return undef if no object selected.
#
sub _current_session {
	my $self = shift;
    my ($current) = Padre::DB::Session->select(
        'where name = ?',
        $self->_curname );
    return $current;
}

#
# $dialog->_refresh_list($column, $reverse);
#
# refresh list of sessions. list is sorted according to $column (default to
# first column), and may be reversed (default to no).
#
sub _refresh_list {
	my ( $self, $column, $reverse ) = @_;
return; # FIXME
	# default sorting
	$column  ||= 0;
	$reverse ||= 0;
    my @fields = qw{ name description last_update }; # db fields of table session

	# get list of sessions, sorted.
    my $sort = "ORDER BY $fields[$column]";
    $sort   .= ' DESC' if $reverse;
    my @sessions = Padre::DB::Session->select( $sort );

	# clear list & fill it again
	my $list = $self->_list;
	$list->DeleteAllItems;
	foreach my $session ( reverse @sessions ) {
        my $name   = $session->name;
		my $descr  = $session->description;
		my $update = localtime( $session->last_update );

		# inserting the session in the list
        my $item = Wx::ListItem->new;
        $item->SetId(0);
        $item->SetColumn(0);
        $item->SetText($name);
		my $idx = $list->InsertItem( $item );
		$list->SetItem( $idx, 1, $descr );
		$list->SetItem( $idx, 2, $update );
	}

	# auto-resize columns
    my $flag = $list->GetItemCount
        ? wxLIST_AUTOSIZE
        : wxLIST_AUTOSIZE_USEHEADER;
    $list->SetColumnWidth( $_, $flag ) for 0 .. 2;

	# making sure the list can show all columns
	my $width = 15;    # taking vertical scrollbar into account
	$width += $list->GetColumnWidth($_) for 0 .. 2;
	$list->SetMinSize( [ $width, -1 ] );
}

#
# $self->_select_first_item;
#
# select first item in the list, or none if there are none. in that case,
# update the current row and name selection to undef.
#
sub _select_first_item {
    my ($self) = @_;

return; # FIXME
	# select first item in the list
	my $list = $self->_list;

    if ( $list->GetItemCount ) {
	    my $item = $list->GetItem(0);
	    $item->SetState(wxLIST_STATE_SELECTED);
	    $list->SetItem($item);
    } else {
        # remove current selection
        $self->_currow ( undef );
        $self->_curname( undef );
    }
}

#
# $self->_update_buttons_state;
#
# update state of delete and open buttons: they should not be clickable if no
# session is selected.
#
sub _update_buttons_state {
    my ($self) = @_;

    my $method = defined($self->_currow) ? 'Enable' : 'Disable';
    $self->_butdelete->$method;
    $self->_butopen->$method;
}


1;

__END__


=head1 NAME

Padre::Wx::Dialog::SessionSave - dialog to save a Padre session



=head1 DESCRIPTION

Padre supports sessions, and this dialog provides Padre with a way to
save a session.



=head1 PUBLIC API

=head2 Constructor

=over 4

=item * my $dialog = PWD::SS->new( $parent )

Create and return a new Wx dialog allowing to save a session. It needs a
C<$parent> window (usually padre's main window).


=back



=head2 Public methods

=over 4

=item * $dialog->show;

Request the dialog to be shown.


=back



=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.


=cut


# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

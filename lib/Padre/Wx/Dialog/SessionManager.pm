#
# This file is part of Padre, the Perl ide.
#

package Padre::Wx::Dialog::SessionManager;

use strict;
use warnings;

use Carp qw{ croak };
use Class::XSAccessor accessors => {
	_butdelete    => '_butdelete',      # delete button
	_butopen      => '_butopen',        # open button
	_currow       => '_currow',         # current list row number
	_curname      => '_curname',        # name of current session selected
	_vbox         => '_vbox',           # the window vbox sizer
	_list         => '_list',           # list on the left of the pane
	_manager      => '_manager',        # ref to plugin manager
	_plugin_names => '_plugin_names',   # mapping of short/full plugin names
	_sortcolumn   => '_sortcolumn',     # column used for list sorting
	_sortreverse  => '_sortreverse',    # list sorting is reversed
};

use base 'Wx::Frame';

our $VERSION = '0.33';


# -- constructor

sub new {
	my ( $class, $parent ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Session Manager'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
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

	# select first item in the list
	my $list = $self->_list;
	my $item = $list->GetItem(0);
    if ( defined $item ) {
	    $item->SetState(Wx::wxLIST_STATE_SELECTED);
	    $list->SetItem($item);
    }

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
	my $self = shift;
    my $name = $self->_curname;
    my ($current) = Padre::DB::Session->select('where name = ?', $name);

    # remove session files
    Padre::DB::SessionFile->delete('where session = ?', $current->id);

    # remove session itself
    $current->delete;

    $self->_refresh_list;
}

#
# $self->_on_button_clicked;
#
# handler called when the first button has been clicked.
#
sub _on_button_clicked {
	my $self = shift;

	# find method to call
	my $label  = $self->_button->GetLabel;
	my %method = (
		Wx::gettext('Disable')            => '_plugin_disable',
		Wx::gettext('Enable')             => '_plugin_enable',
		Wx::gettext('Show error message') => '_plugin_show_error_msg',
	);
	my $method = $method{$label};

	# call method
	$self->$method;
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
# create the dialog itself. it will have a list with all found sessions, and
# some buttons to manage them.
#
# no params, no return values.
#
sub _create {
	my $self = shift;

	# create vertical box that will host all controls
	my $vbox = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$self->SetSizer($vbox);
    #$self->SetMinSize( [ 640, 480 ] );
	$self->_vbox($vbox);

	$self->_create_list;
	$self->_create_buttons;
}

#
# $dialog->_create_list;
#
# create the sessions list. it will hold a list of available sessions, along
# with their description & last update.
#
# no params. no return values.
#
sub _create_list {
	my $self = shift;
    my $vbox = $self->_vbox;

    # title label
    my $label = Wx::StaticText->new( $self, -1,
        Wx::gettext('List of sessions') );
	$vbox->Add( $label, 0, Wx::wxALL, 1 );

	# create list
	my $list = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL,
	);
	$list->InsertColumn( 0, Wx::gettext('Name') );
	$list->InsertColumn( 1, Wx::gettext('Description') );
	$list->InsertColumn( 2, Wx::gettext('Last update') );
	$self->_list($list);

	# install event handler
	Wx::Event::EVT_LIST_ITEM_SELECTED( $self, $list, \&_on_list_item_selected );
	Wx::Event::EVT_LIST_COL_CLICK( $self, $list, \&_on_list_col_click );

	# pack the list
	$vbox->Add( $list, 1, Wx::wxALL | Wx::wxEXPAND, 1 );
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

    # the hbox
	my $hbox = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$self->_vbox->Add( $hbox, 0, Wx::wxALL | Wx::wxEXPAND, 1 );

	# the buttons
	my $bo  = Wx::Button->new( $self, -1, Wx::gettext('Open') );
	my $bd  = Wx::Button->new( $self, -1, Wx::gettext('Delete') );
	my $bc  = Wx::Button->new( $self, -1, Wx::gettext('Close') );
    $self->_butopen  ( $bo );
    $self->_butdelete( $bd );
	Wx::Event::EVT_BUTTON( $self, $bo, \&_on_butopen_clicked );
	Wx::Event::EVT_BUTTON( $self, $bd, \&_on_butdelete_clicked );
	Wx::Event::EVT_BUTTON( $self, $bc, \&_on_butclose_clicked );
	$hbox->Add( $bo,  0, Wx::wxALL, 1 );
	$hbox->Add( $bd,  0, Wx::wxALL, 1 );
	$hbox->AddStretchSpacer;
	$hbox->Add( $bc,  0, Wx::wxALL, 1 );
}

#
# my $session = $self->_current;
#
# return the padre::db::session object corresponding to currently selected line
# in the list. return undef if no object selected.
#
sub _current {
	my $self = shift;
    my ($current) = Padre::DB::Session->select(
        'where name = ?',
        $self->_curname );
    return $current;
}

#
# $self->_plugin_disable;
#
# disable plugin, and update gui.
#
sub _plugin_disable {
	my $self = shift;

	my $plugin = $self->_curplugin;
	my $parent = $self->GetParent;

	# disable plugin
	$parent->Freeze;
	Padre::DB::Plugin->update_enabled( $plugin->class => 0 );
	$self->_manager->_plugin_disable( $plugin->name );
	$parent->menu->refresh(1);
	$parent->Thaw;

	# update plugin manager dialog to reflect new state
	$self->_update_plugin_state;
}

#
# $self->_plugin_enable;
#
# enable plugin, and update gui.
#
sub _plugin_enable {
	my $self = shift;

	my $plugin = $self->_curplugin;
	my $parent = $self->GetParent;

	# enable plugin
	$parent->Freeze;
	Padre::DB::Plugin->update_enabled( $plugin->class => 1 );
	$self->_manager->_plugin_enable( $plugin->name );
	$parent->menu->refresh(1);
	$parent->Thaw;

	# update plugin manager dialog to reflect new state
	$self->_update_plugin_state;
}

#
# $self->_plugin_show_error_msg;
#
# show plugin error message, in an error dialog box.
#
sub _plugin_show_error_msg {
	my $self = shift;

	my $message = $self->_curplugin->errstr;
	my $title   = Wx::gettext('Error');
	Wx::MessageBox( $message, $title, Wx::wxOK | Wx::wxCENTER, $self );
}

#
# $dialog->_refresh_list($column, $reverse);
#
# refresh list of sessions. list is sorted according to $column (default to
# first column), and may be reversed (default to no).
#
sub _refresh_list {
	my ( $self, $column, $reverse ) = @_;

	# default sorting
	$column  ||= 0;
	$reverse ||= 0;
    my @fields = qw{ name description last_update }; # db fields of table session

	# get list of sessions, sorted.
    my $sort = "ORDER BY $fields[$column]";
    $sort   .= ' DESC' if $reverse;
    my @sessions = Padre::DB::Session->select( $sort );

	# clear plugin list & fill it again
	my $list = $self->_list;
	$list->DeleteAllItems;
	foreach my $session ( reverse @sessions ) {
        my $name   = $session->name;
		my $descr  = $session->description;
		my $update = $session->last_update;

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
	$list->SetColumnWidth( $_, Wx::wxLIST_AUTOSIZE ) for 0 .. 2;

	# making sure the list can show all columns
	my $width = 15;    # taking vertical scrollbar into account
	$width += $list->GetColumnWidth($_) for 0 .. 2;
	$list->SetMinSize( [ $width, -1 ] );
}

#
# $dialog->_update_plugin_state;
#
# update button caption & state, as well as status icon in the list,
# depending on the new plugin state.
#
sub _update_plugin_state {
	my $self   = shift;
	my $plugin = $self->_curplugin;
	my $list   = $self->_list;
	my $item   = $list->GetItem( $self->_currow, 2 );

	# updating buttons
	my $button   = $self->_button;
	my $butprefs = $self->_butprefs;

	if ( $plugin->error ) {

		# plugin is in error state
		$button->SetLabel( Wx::gettext('Show error message') );
		$butprefs->Disable;
		$item->SetText( Wx::gettext('error') );
		$item->SetImage(3);
		$list->SetItem($item);

	} elsif ( $plugin->incompatible ) {

		# plugin is incompatible
		$button->SetLabel( Wx::gettext('Show error message') );
		$butprefs->Disable;
		$item->SetText( Wx::gettext('incompatible') );
		$item->SetImage(5);
		$list->SetItem($item);

	} else {

		# plugin is working...

		if ( $plugin->enabled ) {

			# ... and enabled
			$button->SetLabel( Wx::gettext('Disable') );
			$button->Enable;
			$item->SetText( Wx::gettext('enabled') );
			$item->SetImage(1);
			$list->SetItem($item);

		} elsif ( $plugin->can_enable ) {

			# ... and disabled
			$button->SetLabel( Wx::gettext('Enable') );
			$button->Enable;
			$item->SetText( Wx::gettext('disabled') );
			$item->SetImage(2);
			$list->SetItem($item);

		} else {

			# ... disabled but cannot be enabled
			$button->Disable;
		}

		# updating preferences button
		if ( $plugin->object->can('plugin_preferences') ) {
			$self->_butprefs->Enable;
		} else {
			$self->_butprefs->Disable;
		}
	}

	# update the list item

	# force window to recompute layout. indeed, changes are that plugin
	# name has a different length, and thus should be recentered.
	$self->Layout;
}

1;

__END__


=head1 NAME

Padre::Wx::Dialog::SessionManager - Session manager dialog for Padre



=head1 DESCRIPTION

Padre supports sessions, that is, a bunch of files opened. But we need to
provide a way to manage those sessions: listing, removing them, etc. This
module implements this task as a dialog for Padre.



=head1 PUBLIC API

=head2 Constructor

=over 4

=item * my $dialog = PWD::SM->new( $parent )

Create and return a new Wx dialog listing all the sessions. It needs a
C<$parent> window (usually padre's main window).


=back



=head2 Public methods

=over 4

=item * $dialog->show;

Request the session manager dialog to be shown. It will be refreshed first with
a current list of sessions.


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

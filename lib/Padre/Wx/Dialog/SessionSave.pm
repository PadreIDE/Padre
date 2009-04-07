#
# This file is part of Padre, the Perl ide.
#

package Padre::Wx::Dialog::SessionSave;

use strict;
use warnings;

use Class::XSAccessor accessors => {
	_butdelete    => '_butdelete',      # delete button
	_butopen      => '_butopen',        # open button
	_combo        => '_combo',          # combo box holding the session names
	_currow       => '_currow',         # current list row number
	_curname      => '_curname',        # name of current session selected
	_list         => '_list',           # list on the left of the pane
	_names        => '_names',          # list of all session names
	_sortcolumn   => '_sortcolumn',     # column used for list sorting
	_sortreverse  => '_sortreverse',    # list sorting is reversed
	_sizer        => '_sizer',          # the window sizer
	_text         => '_text',           # text control holding the description
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
	$self->_refresh_combo;
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
# $self->_on_combo_item_selected( $event );
#
# handler called when a combo item has been selected. it will in turn update
# the description text.
#
# $event is a Wx::CommandEvent.
#
sub _on_combo_item_selected {
	my ( $self, $event ) = @_;

	my $name    = $self->_combo->GetValue;
	my $session = $self->_current_session;
	return unless $session;
	$self->_text->SetValue( $session->description );
}

#
# $self->_on_combo_text_changed( $event );
#
# handler called when user types in the combo box. it will update the
# description text, but only if the new session matches an existing one.
#
# $event is a Wx::CommandEvent.
#
sub _on_combo_text_changed {
	my ( $self, $event ) = @_;

	my $name    = $self->_combo->GetValue;
	my $session = $self->_current_session;
	return unless $session;
	$self->_text->SetValue( $session->description );
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
	$sizer->SetSizeHints($self);
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
	$self->_combo( $combo );
	Wx::Event::EVT_COMBOBOX( $self, $combo, \&_on_combo_item_selected );
	Wx::Event::EVT_TEXT    ( $self, $combo, \&_on_combo_text_changed  );

	# session descritpion
	my $lab2  = Wx::StaticText->new( $self, -1, Wx::gettext('Description:') );
	my $text  = Wx::TextCtrl->new  ( $self, -1, '' );
	$sizer->Add( $lab2, Wx::GBPosition->new(1,0) );
	$sizer->Add( $text, Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,3), wxEXPAND );
	$self->_text( $text );
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
# return the padre::db::session object corresponding to combo text.
# return undef if no object selected.
#
sub _current_session {
	my $self = shift;
	my ($current) = Padre::DB::Session->select(
		'where name = ?',
		$self->_combo->GetValue );
	return $current;
}

#
# $dialog->_refresh_combo;
#
# refresh combo box with list of sessions.
#
sub _refresh_combo {
	my ( $self, $column, $reverse ) = @_;

	# get list of sessions, sorted.
	my @names =
		map { $_->name }
		Padre::DB::Session->select( 'ORDER BY name' );
	$self->_names( \@names );

	# clear list & fill it again
	my $combo = $self->_combo;
	$combo->Clear;
	$combo->Append( $_ ) foreach @names;
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

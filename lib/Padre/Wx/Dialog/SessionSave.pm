package Padre::Wx::Dialog::SessionSave;

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.94';
our @ISA     = 'Wx::Dialog';

use Class::XSAccessor {
	accessors => {
		_butsave => '_butsave', # save button
		_combo   => '_combo',   # combo box holding the session names
		_names   => '_names',   # list of all session names
		_sizer   => '_sizer',   # the window sizer
		_text    => '_text',    # text control holding the description
	}
};

# -- constructor

sub new {
	my ( $class, $parent ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Save session as...'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);
	$self->SetIcon(Padre::Wx::Icon::PADRE);

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
# $self->_on_butsave_clicked;
#
# handler called when the save button has been clicked.
#
sub _on_butsave_clicked {
	my $self = shift;

	my $main    = $self->GetParent;
	my $session = $self->_current_session;

	# TO DO: This must be switched to use the main methods:

	if ( defined $session ) {

		# session exist, remove all files associated to it
		Padre::DB::SessionFile->delete(
			'where session = ?',
			$session->id
		);

		# Save Session description:
		Padre::DB->do(
			'UPDATE session SET description=? WHERE id=?',
			{}, $self->_text->GetValue, $session->id
		);
	} else {

		# session did not exist, create a new one
		$session = Padre::DB::Session->new(
			name        => $self->_combo->GetValue,
			description => $self->_text->GetValue,
			last_update => time,
		);
		$session->insert;
	}

	# capture session and save it
	my @session = $main->capture_session;
	$main->save_session( $session, @session );

	# close dialog
	$self->Destroy;
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

	my $name = $self->_combo->GetValue;
	my $method = $name ? 'Enable' : 'Disable';
	$self->_butsave->$method;
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
	my $box = Wx::BoxSizer->new(Wx::VERTICAL);
	my $sizer = Wx::GridBagSizer->new( 5, 5 );
	$sizer->AddGrowableCol(1);
	$box->Add( $sizer, 1, Wx::EXPAND | Wx::ALL, 5 );
	$self->_sizer($sizer);

	$self->_create_fields;
	$self->_create_buttons;
	$self->SetSizer($box);
	$box->SetSizeHints($self);
	$self->CenterOnParent;
	$self->_combo->SetFocus;

	# Update description/button status in case of preloaded values
	# Better re-use the existing functions than rewrite the same
	# code during component creation
	$self->_on_combo_text_changed;
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

	my $Current_Session;
	if ( defined( Padre->ide->{session} ) ) {
		my $CS = Padre::DB::Session->select(
			'name where id = ?',
			Padre->ide->{session}
		);

		# was $CS->[0]->{name};
		# but it crashed
		$Current_Session = $CS->[0]->[1];
	}
	$Current_Session ||= ''; # Empty value for combo box, better than undef


	# session name
	my $lab1 = Wx::StaticText->new( $self, -1, Wx::gettext('Session name:') );
	my $combo = Wx::ComboBox->new( $self, -1, $Current_Session );
	$sizer->Add( $lab1, Wx::GBPosition->new( 0, 0 ) );
	$sizer->Add( $combo, Wx::GBPosition->new( 0, 1 ), Wx::GBSpan->new( 1, 3 ), Wx::EXPAND );
	$self->_combo($combo);
	Wx::Event::EVT_COMBOBOX( $self, $combo, \&_on_combo_item_selected );
	Wx::Event::EVT_TEXT( $self, $combo, \&_on_combo_text_changed );

	# session descritpion
	my $lab2 = Wx::StaticText->new( $self, -1, Wx::gettext('Description:') );
	my $text = Wx::TextCtrl->new( $self, -1, '' );
	$sizer->Add( $lab2, Wx::GBPosition->new( 1, 0 ) );
	$sizer->Add( $text, Wx::GBPosition->new( 1, 1 ), Wx::GBSpan->new( 1, 3 ), Wx::EXPAND );
	$self->_text($text);
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
	my $bs = Wx::Button->new( $self, Wx::ID_OK,     Wx::gettext('Save') );
	my $bc = Wx::Button->new( $self, Wx::ID_CANCEL, Wx::gettext('Close') );
	Wx::Event::EVT_BUTTON( $self, $bs, \&_on_butsave_clicked );
	Wx::Event::EVT_BUTTON( $self, $bc, \&_on_butclose_clicked );
	$sizer->Add( $bs, Wx::GBPosition->new( 2, 2 ) );
	$sizer->Add( $bc, Wx::GBPosition->new( 2, 3 ) );

	$bs->SetDefault;

	# save button is disabled at first if there is nothing to save
	$bs->Disable;
	$self->_butsave($bs);
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
		$self->_combo->GetValue
	);
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
	my @names = map { $_->name } Padre::DB::Session->select('ORDER BY name');
	$self->_names( \@names );

	# clear list & fill it again
	my $combo        = $self->_combo;
	my $preselection = $combo->GetValue;
	$combo->Clear;
	$combo->Append($_) foreach @names;
	$combo->SetStringSelection($preselection);
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

=head3 C<new>

    my $dialog = PWD::SS->new( $parent )

Create and return a new Wx dialog allowing to save a session. It needs a
C<$parent> window (usually Padre's main window).

=head2 Public methods

=head3 C<show>

    $dialog->show;

Request the dialog to be shown.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.


=cut


# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

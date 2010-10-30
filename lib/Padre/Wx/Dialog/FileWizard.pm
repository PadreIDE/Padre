package Padre::Wx::Dialog::FileWizard;

use 5.008;
use strict;
use warnings;
use Padre::Constant         ();
use Padre::Config           ();
use Padre::Wx               ();
use Padre::Wx::Role::Main   ();
use Padre::Wx::Role::Dialog ();

our $VERSION = '0.73';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Padre::Wx::Role::Dialog
	Wx::Dialog
};

# Creates the dialog and returns the instance
sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('File Wizard'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Minimum dialog size
	$self->SetMinSize( [ 360, 340 ] );

	# Create sizer that will host all controls
	$self->{sizer} = Wx::BoxSizer->new(Wx::wxVERTICAL);

	# Create the controls and buttons
	$self->_create_controls;

	# Bind the control events
	$self->_bind_events;

	# Wrap everything in a vbox to add some padding
	$self->SetSizer($self->{sizer});
	$self->Fit;
	$self->CentreOnParent;

	return $self;
}

# Create dialog controls
sub _create_controls {
	my ( $self ) = @_;

	# Filter label
	my $filter_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Filter:') );

	# Filter text field
	$self->{filter} = Wx::TextCtrl->new( $self, -1, '' );

	# Filtered list
	$self->{list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
	);

	#
	#----- Dialog Layout -------
	#

	# Filter sizer
	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	$self->{ok_button} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		Wx::gettext('&OK'),
	);
	$self->{ok_button}->SetDefault;
	$self->{cancel_button} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext('&Cancel'),
	);

	my $buttons = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{ok_button},     0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$buttons->Add( $self->{cancel_button}, 0, Wx::wxALL | Wx::wxEXPAND, 5 );

	# Main vertical sizer
	$self->{sizer}->Add( $filter_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$self->{sizer}->Add( $self->{list}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );
	$self->{sizer}->AddSpacer(5);
	$self->{sizer}->Add( $buttons, 0, Wx::wxALL | Wx::wxEXPAND | Wx::wxALIGN_CENTER, 5 );
	$self->{sizer}->AddSpacer(5);

	return;
}

# A Private method to binds events to controls
sub _bind_events {
	my $self = shift;

	# Set focus when Keypad Down or page down keys are pressed
	Wx::Event::EVT_CHAR(
		$self->{filter},
		sub {
			$self->_on_char( $_[1] );
		}
	);

	# Update filter search results on each text change
	Wx::Event::EVT_TEXT(
		$self,
		$self->{filter},
		sub {
			shift->_update_list;
		}
	);

	# Close button
	Wx::Event::EVT_BUTTON( $self, Wx::wxID_OK, \&_on_ok_button );

	return;
}

# Private method to handle on character pressed event
sub _on_char {
	my $self  = shift;
	my $event = shift;
	my $code  = $event->GetKeyCode;

	$self->{list}->SetFocus
		if ( $code == Wx::WXK_DOWN )
		or ( $code == Wx::WXK_NUMPAD_PAGEDOWN )
		or ( $code == Wx::WXK_PAGEDOWN );

	$event->Skip(1);

	return;
}

# Private method to handle the selection of an item
sub _on_ok_button {
	my $self  = shift;
	my $event = shift;

##TODO implement

	return;
}

# Private method to update the key bindings list view
sub _update_list {
	my $self   = shift;
	my $filter = quotemeta $self->{filter}->GetValue;

	# Clear list
	my $list = $self->{list};
	$list->Clear;

	return;
}

# Shows the key binding dialog
sub show {
	my $self = shift;

	# Set focus on the filter text field
	$self->{filter}->SetFocus;

	# Update the preferences list
	$self->_update_list;

	# If it is not shown, show the dialog
	$self->ShowModal;

	return;
}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::FileWizard - a dialog to filter and open file wizards

=head1 DESCRIPTION

This dialog lets the user search for an file wizard and the open it if needed

=head1 PUBLIC API

=head2 C<new>

  my $file_wizard = Padre::Wx::Dialog::FileWizard->new($main);

Returns a new C<Padre::Wx::Dialog::FileWizard> instance

=head2 C<show>

  $file_wizard->show($main);

Shows the dialog. Returns C<undef>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

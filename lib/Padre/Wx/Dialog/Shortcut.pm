package Padre::Wx::Dialog::Shortcut;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();
use Padre::Locale         ();

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

=pod

=head1 NAME

Padre::Wx::Dialog::Shortcut - A Dialog

=cut

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('A Dialog'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION | Wx::wxCLOSE_BOX | Wx::wxSYSTEM_MENU
	);

	$self->{action_label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Action: %s"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{ctrl_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("CTRL"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $label_3 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("+"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{alt_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("ALT"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $label_2 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("+"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{shift_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("SHIFT"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $label_1 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("+"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{key_box} = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxCB_DROPDOWN,
	);
	$self->{ok} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		"",
	);
	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		"",
	);
	Wx::Event::EVT_CHECKBOX( $self, $self->{shift_checkbox}->GetId, \&foo );
	$self->SetTitle( Wx::gettext("Shortcut") );
	$self->{key_box}->SetSelection(-1);
	my $sizer_1 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_2 = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$self->{button_sizer} = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_8 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizer_2->Add( $self->{action_label},   0, Wx::wxEXPAND,                                           0 );
	$sizer_2->Add( $line_1,                 0, Wx::wxTOP | Wx::wxBOTTOM | Wx::wxEXPAND,                5 );
	$sizer_8->Add( $self->{ctrl_checkbox},  0, Wx::wxALIGN_CENTER_VERTICAL,                            0 );
	$sizer_8->Add( $label_3,                0, Wx::wxLEFT | Wx::wxRIGHT | Wx::wxALIGN_CENTER_VERTICAL, 8 );
	$sizer_8->Add( $self->{alt_checkbox},   0, Wx::wxALIGN_CENTER_VERTICAL,                            0 );
	$sizer_8->Add( $label_2,                0, Wx::wxLEFT | Wx::wxRIGHT | Wx::wxALIGN_CENTER_VERTICAL, 8 );
	$sizer_8->Add( $self->{shift_checkbox}, 0, Wx::wxALIGN_CENTER_VERTICAL,                            0 );
	$sizer_8->Add( $label_1,                0, Wx::wxLEFT | Wx::wxRIGHT | Wx::wxALIGN_CENTER_VERTICAL, 8 );
	$sizer_8->Add( $self->{key_box},        0, Wx::wxALIGN_CENTER_VERTICAL,                            0 );
	$sizer_2->Add( $sizer_8,                1, Wx::wxEXPAND,                                           0 );
	my $line_2 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$sizer_2->Add( $line_2, 0, Wx::wxTOP | Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$self->{button_sizer}->Add( $self->{ok},     1, 0,          0 );
	$self->{button_sizer}->Add( $self->{cancel}, 1, Wx::wxLEFT, 5 );
	$sizer_2->Add( $self->{button_sizer}, 1, Wx::wxALIGN_RIGHT,        5 );
	$sizer_1->Add( $sizer_2,              1, Wx::wxALL | Wx::wxEXPAND, 5 );
	$self->SetSizer($sizer_1);
	$sizer_1->Fit($self);

	#	my ($self, $event) = @_;
	#	warn "Event handler (foo) not implemented";
	#	$event->Skip;

	return $self;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

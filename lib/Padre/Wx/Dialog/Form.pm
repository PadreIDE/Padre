package Padre::Wx::Dialog::Form;

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

Padre::Wx::Dialog::Form - A Dialog

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

	my $label_1 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Label One"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $text_ctrl_1 = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $label_2 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Second Label"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $combo_box_1 = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxCB_DROPDOWN,
	);
	my $label_3 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Whatever"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $choice_1 = Wx::Choice->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
	);
	my $static_line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
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
	$self->SetTitle( Wx::gettext("Padre") );
	$combo_box_1->SetSelection(-1);
	$choice_1->SetSelection(0);
	$self->{ok}->SetDefault;
	my $sizer_7 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_8 = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$self->{button_sizer} = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$self->{form_sizer}   = Wx::GridSizer->new(
		3,
		2,
		5,
		5,
	);
	$self->{form_sizer}->Add( $label_1,     0, Wx::wxALIGN_CENTER_VERTICAL, 0 );
	$self->{form_sizer}->Add( $text_ctrl_1, 0, 0,                           0 );
	$self->{form_sizer}->Add( $label_2,     0, Wx::wxALIGN_CENTER_VERTICAL, 0 );
	$self->{form_sizer}->Add( $combo_box_1, 0, 0,                           0 );
	$self->{form_sizer}->Add( $label_3,     0, Wx::wxALIGN_CENTER_VERTICAL, 0 );
	$self->{form_sizer}->Add( $choice_1,    0, 0,                           0 );
	$sizer_8->Add( $self->{form_sizer}, 1, Wx::wxEXPAND, 0 );
	$sizer_8->Add( $static_line_1, 0, Wx::wxTOP | Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$self->{button_sizer}->Add( $self->{ok},     1, 0,          0 );
	$self->{button_sizer}->Add( $self->{cancel}, 1, Wx::wxLEFT, 5 );
	$sizer_8->Add( $self->{button_sizer}, 0, Wx::wxALIGN_RIGHT,        5 );
	$sizer_7->Add( $sizer_8,              1, Wx::wxALL | Wx::wxEXPAND, 5 );
	$self->SetSizer($sizer_7);
	$sizer_7->Fit($self);

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

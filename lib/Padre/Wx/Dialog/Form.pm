package Padre::Wx::Dialog::Form;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();
use Padre::Locale         ();

our $VERSION = '0.94';
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
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::CAPTION | Wx::CLOSE_BOX | Wx::SYSTEM_MENU
	);

	my $label_1 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Label One"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $text_ctrl_1 = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $label_2 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Second Label"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $combo_box_1 = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
		Wx::CB_DROPDOWN,
	);
	my $label_3 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Whatever"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $choice_1 = Wx::Choice->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
	);
	my $static_line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{ok} = Wx::Button->new(
		$self,
		Wx::ID_OK,
		"",
	);
	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		"",
	);
	$self->SetTitle( Wx::gettext("Padre") );
	$combo_box_1->SetSelection(-1);
	$choice_1->SetSelection(0);
	$self->{ok}->SetDefault;
	my $sizer_7 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	my $sizer_8 = Wx::BoxSizer->new(Wx::VERTICAL);
	$self->{button_sizer} = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->{form_sizer}   = Wx::GridSizer->new(
		3,
		2,
		5,
		5,
	);
	$self->{form_sizer}->Add( $label_1,     0, Wx::ALIGN_CENTER_VERTICAL, 0 );
	$self->{form_sizer}->Add( $text_ctrl_1, 0, 0,                         0 );
	$self->{form_sizer}->Add( $label_2,     0, Wx::ALIGN_CENTER_VERTICAL, 0 );
	$self->{form_sizer}->Add( $combo_box_1, 0, 0,                         0 );
	$self->{form_sizer}->Add( $label_3,     0, Wx::ALIGN_CENTER_VERTICAL, 0 );
	$self->{form_sizer}->Add( $choice_1,    0, 0,                         0 );
	$sizer_8->Add( $self->{form_sizer}, 1, Wx::EXPAND, 0 );
	$sizer_8->Add( $static_line_1, 0, Wx::TOP | Wx::BOTTOM | Wx::EXPAND, 5 );
	$self->{button_sizer}->Add( $self->{ok},     1, 0,        0 );
	$self->{button_sizer}->Add( $self->{cancel}, 1, Wx::LEFT, 5 );
	$sizer_8->Add( $self->{button_sizer}, 0, Wx::ALIGN_RIGHT,      5 );
	$sizer_7->Add( $sizer_8,              1, Wx::ALL | Wx::EXPAND, 5 );
	$self->SetSizer($sizer_7);
	$sizer_7->Fit($self);

	return $self;
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

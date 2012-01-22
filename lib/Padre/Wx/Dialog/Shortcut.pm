package Padre::Wx::Dialog::Shortcut;

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
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::CAPTION | Wx::CLOSE_BOX | Wx::SYSTEM_MENU
	);

	$self->{action_label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Action: %s"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{ctrl_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("CTRL"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $label_3 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("+"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{alt_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("ALT"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $label_2 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("+"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{shift_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("SHIFT"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	my $label_1 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("+"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{key_box} = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
		Wx::CB_DROPDOWN,
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
	Wx::Event::EVT_CHECKBOX( $self, $self->{shift_checkbox}->GetId, \&foo );
	$self->SetTitle( Wx::gettext("Shortcut") );
	$self->{key_box}->SetSelection(-1);
	my $sizer_1 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	my $sizer_2 = Wx::BoxSizer->new(Wx::VERTICAL);
	$self->{button_sizer} = Wx::BoxSizer->new(Wx::HORIZONTAL);
	my $sizer_8 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$sizer_2->Add( $self->{action_label},   0, Wx::EXPAND,                                       0 );
	$sizer_2->Add( $line_1,                 0, Wx::TOP | Wx::BOTTOM | Wx::EXPAND,                5 );
	$sizer_8->Add( $self->{ctrl_checkbox},  0, Wx::ALIGN_CENTER_VERTICAL,                        0 );
	$sizer_8->Add( $label_3,                0, Wx::LEFT | Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 8 );
	$sizer_8->Add( $self->{alt_checkbox},   0, Wx::ALIGN_CENTER_VERTICAL,                        0 );
	$sizer_8->Add( $label_2,                0, Wx::LEFT | Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 8 );
	$sizer_8->Add( $self->{shift_checkbox}, 0, Wx::ALIGN_CENTER_VERTICAL,                        0 );
	$sizer_8->Add( $label_1,                0, Wx::LEFT | Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 8 );
	$sizer_8->Add( $self->{key_box},        0, Wx::ALIGN_CENTER_VERTICAL,                        0 );
	$sizer_2->Add( $sizer_8,                1, Wx::EXPAND,                                       0 );
	my $line_2 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$sizer_2->Add( $line_2, 0, Wx::TOP | Wx::BOTTOM | Wx::EXPAND, 5 );
	$self->{button_sizer}->Add( $self->{ok},     1, 0,        0 );
	$self->{button_sizer}->Add( $self->{cancel}, 1, Wx::LEFT, 5 );
	$sizer_2->Add( $self->{button_sizer}, 1, Wx::ALIGN_RIGHT,      5 );
	$sizer_1->Add( $sizer_2,              1, Wx::ALL | Wx::EXPAND, 5 );
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

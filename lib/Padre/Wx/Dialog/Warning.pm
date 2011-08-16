package Padre::Wx::Dialog::Warning;

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

Padre::Wx::Dialog::Warning - A Dialog

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

	$self->{warning_label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("See http://padre.perlide.org/ for update information"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxALIGN_CENTRE,
	);
	$self->{warning_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("Do not show this again"),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	my $line_1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{ok_button} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		"",
	);
	$self->SetTitle( Wx::gettext("Warning") );
	my $sizer_4 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_5 = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizer_6 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizer_5->Add( $self->{warning_label},    0, 0,                                       0 );
	$sizer_5->Add( $self->{warning_checkbox}, 0, Wx::wxTOP | Wx::wxEXPAND,                5 );
	$sizer_5->Add( $line_1,                   0, Wx::wxTOP | Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$sizer_6->Add( $self->{ok_button},        0, 0,                                       0 );
	$sizer_5->Add( $sizer_6,                  1, Wx::wxALIGN_CENTER_HORIZONTAL,           5 );
	$sizer_4->Add( $sizer_5,                  1, Wx::wxALL | Wx::wxEXPAND,                5 );
	$self->SetSizer($sizer_4);
	$sizer_4->Fit($self);

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

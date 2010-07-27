package Padre::Wx::FBP::WhereFrom;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.67';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new(
		$parent,
		-1,
		'',
		Wx::wxDefaultPosition,
		[ -1, -1 ],
		Wx::wxDEFAULT_DIALOG_STYLE,
	);

	my $label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Where did you hear about Padre?'),
	);

	$self->{from} = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
	);

	my $line = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLI_HORIZONTAL,
	);

	$self->{ok} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		Wx::gettext('OK'),
	);

	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext('Skip question without giving feedback'),
	);

	my $question = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$question->Add( $label,        0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 5 );
	$question->Add( $self->{from}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 5 );

	my $buttons = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$buttons->Add( $self->{ok}, 0, Wx::wxALL, 5 );
	$buttons->Add( 0, 0, 1, Wx::wxEXPAND, 5 );
	$buttons->Add( $self->{cancel}, 0, Wx::wxALL, 5 );

	my $vsizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$vsizer->Add( $question, 1, Wx::wxALIGN_RIGHT,                       0 );
	$vsizer->Add( $line,     0, Wx::wxEXPAND | Wx::wxLEFT | Wx::wxRIGHT, 5 );
	$vsizer->Add( $buttons,  1, Wx::wxALIGN_RIGHT | Wx::wxEXPAND,        0 );

	my $hsizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$hsizer->Add( $vsizer, 1, Wx::wxEXPAND, 5 );

	$self->SetSizer($hsizer);
	$self->Layout;
	$hsizer->Fit($self);

	return $self;
}

1;


# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

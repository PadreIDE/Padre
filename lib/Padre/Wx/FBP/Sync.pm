package Padre::Wx::FBP::Sync;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.01';
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

	$self->{m_staticText12} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Server'),
	);

	$self->{m_comboBox2} = Wx::ComboBox->new(
		$self,
		-1,
		"http://sync.perlide.org/",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[ ],
	);

	$self->{m_staticText13} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Status'),
	);

	$self->{m_staticText14} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Logged out'),
	);

	my $line1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLI_HORIZONTAL,
	);

	$self->{m_staticText2} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Username'),
	);

	$self->{m_textCtrl1} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	$self->{m_staticText3} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Password'),
	);

	$self->{m_textCtrl2} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PASSWORD,
	);

	$self->{m_button3} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext('Login'),
	);

	$self->{m_staticText5} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Username'),
	);

	$self->{m_textCtrl4} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	$self->{m_staticText6} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Password'),
	);

	$self->{m_textCtrl5} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	$self->{m_staticText7} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Confirm'),
	);

	$self->{m_textCtrl6} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	$self->{m_staticText8} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Email'),
	);

	$self->{m_textCtrl7} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	$self->{m_staticText9} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Confirm'),
	);

	$self->{m_textCtrl8} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	$self->{m_button4} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext('Register'),
	);

	my $line = Wx::StaticLine->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLI_HORIZONTAL,
	);

	$self->{m_button5} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext('Upload'),
	);
	$self->{m_button5}->Disable;

	$self->{m_button6} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext('Download'),
	);
	$self->{m_button6}->Disable;

	$self->{m_button7} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext('Delete'),
	);
	$self->{m_button7}->Disable;

	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext('Close'),
	);

	my $fgSizer3 = Wx::FlexGridSizer->new( 2, 2, 0, 0 );
	$fgSizer3->SetFlexibleDirection( Wx::wxBOTH );
	$fgSizer3->SetNonFlexibleGrowMode( Wx::wxFLEX_GROWMODE_SPECIFIED );
	$fgSizer3->Add( $self->{m_staticText12}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer3->Add( $self->{m_comboBox2}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer3->Add( $self->{m_staticText13}, 0, Wx::wxALL, 3 );
	$fgSizer3->Add( $self->{m_staticText14}, 1, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL | Wx::wxEXPAND, 3 );

	my $fgSizer1 = Wx::FlexGridSizer->new( 3, 2, 0, 0 );
	$fgSizer1->SetFlexibleDirection( Wx::wxHORIZONTAL );
	$fgSizer1->SetNonFlexibleGrowMode( Wx::wxFLEX_GROWMODE_SPECIFIED );
	$fgSizer1->Add( $self->{m_staticText2}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer1->Add( $self->{m_textCtrl1}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer1->Add( $self->{m_staticText3}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer1->Add( $self->{m_textCtrl2}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer1->Add( 0, 0, 1, Wx::wxEXPAND, 5 );
	$fgSizer1->Add( $self->{m_button3}, 0, Wx::wxALIGN_RIGHT | Wx::wxALL, 3 );

	my $sbSizer1 = Wx::StaticBoxSizer->new(
		Wx::gettext('Authentication'),
		Wx::wxVERTICAL,
	);
	$sbSizer1->Add( $fgSizer1, 0, Wx::wxEXPAND, 5 );

	my $fgSizer2 = Wx::FlexGridSizer->new( 6, 2, 0, 0 );
	$fgSizer2->SetFlexibleDirection( Wx::wxHORIZONTAL );
	$fgSizer2->SetNonFlexibleGrowMode( Wx::wxFLEX_GROWMODE_SPECIFIED );
	$fgSizer2->Add( $self->{m_staticText5}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer2->Add( $self->{m_textCtrl4}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer2->Add( $self->{m_staticText6}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer2->Add( $self->{m_textCtrl5}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer2->Add( $self->{m_staticText7}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer2->Add( $self->{m_textCtrl6}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer2->Add( $self->{m_staticText8}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer2->Add( $self->{m_textCtrl7}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer2->Add( $self->{m_staticText9}, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 3 );
	$fgSizer2->Add( $self->{m_textCtrl8}, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$fgSizer2->Add( 0, 0, 1, Wx::wxEXPAND, 5 );
	$fgSizer2->Add( $self->{m_button4}, 0, Wx::wxALIGN_RIGHT | Wx::wxALL, 3 );

	my $sbSizer2 = Wx::StaticBoxSizer->new(
		Wx::gettext('Registration'),
		Wx::wxVERTICAL,
	);
	$sbSizer2->Add( $fgSizer2, 1, Wx::wxEXPAND, 5 );

	my $bSizer7 = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	$bSizer7->Add( $sbSizer1, 1, Wx::wxEXPAND, 5 );
	$bSizer7->Add( 10, 0, 0, Wx::wxEXPAND, 5 );
	$bSizer7->Add( $sbSizer2, 1, Wx::wxEXPAND, 5 );

	my $buttons = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	$buttons->Add( $self->{m_button5}, 0, Wx::wxALL, 3 );
	$buttons->Add( $self->{m_button6}, 0, Wx::wxALL, 3 );
	$buttons->Add( $self->{m_button7}, 0, Wx::wxALL, 3 );
	$buttons->Add( 50, 0, 1, Wx::wxEXPAND, 3 );
	$buttons->Add( $self->{cancel}, 0, Wx::wxALL, 3 );

	my $vsizer = Wx::BoxSizer->new( Wx::wxVERTICAL );
	$vsizer->Add( $fgSizer3, 0, Wx::wxEXPAND, 5 );
	$vsizer->Add( $line1, 0, Wx::wxBOTTOM | Wx::wxEXPAND | Wx::wxTOP, 5 );
	$vsizer->Add( $bSizer7, 1, Wx::wxEXPAND, 5 );
	$vsizer->Add( $line, 0, Wx::wxBOTTOM | Wx::wxEXPAND | Wx::wxTOP, 5 );
	$vsizer->Add( $buttons, 0, Wx::wxALIGN_RIGHT | Wx::wxEXPAND, 0 );

	my $hsizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	$hsizer->Add( $vsizer, 1, Wx::wxALL | Wx::wxEXPAND, 5 );

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

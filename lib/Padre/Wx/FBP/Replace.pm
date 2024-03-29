package Padre::Wx::FBP::Replace;

## no critic

# This module was generated by Padre::Plugin::FormBuilder::Perl.
# To change this module edit the original .fbp file and regenerate.
# DO NOT MODIFY THIS FILE BY HAND!

use 5.008005;
use utf8;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Role::Main ();
use Padre::Wx::ComboBox::FindTerm ();
use Padre::Wx::ComboBox::History ();

our $VERSION = '1.02';
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
		Wx::gettext("Replace"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_DIALOG_STYLE,
	);

	Wx::Event::EVT_CLOSE(
		$self,
		sub {
			shift->on_close(@_);
		},
	);

	my $m_staticText2 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Search &Term:"),
	);

	$self->{find_term} = Padre::Wx::ComboBox::FindTerm->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"search",
		],
	);

	Wx::Event::EVT_COMBOBOX(
		$self,
		$self->{find_term},
		sub {
			shift->refresh(@_);
		},
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{find_term},
		sub {
			shift->refresh(@_);
		},
	);

	my $m_staticline2 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LI_HORIZONTAL,
	);

	my $m_staticText3 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Replace &With:"),
	);

	$self->{replace_term} = Padre::Wx::ComboBox::History->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"replace",
		],
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{replace_term},
		sub {
			shift->refresh(@_);
		},
	);

	my $m_staticline3 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LI_HORIZONTAL,
	);

	$self->{find_case} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("&Case Sensitive"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	$self->{find_regex} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("Regular E&xpression"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_CHECKBOX(
		$self,
		$self->{find_regex},
		sub {
			shift->refresh(@_);
		},
	);

	my $m_staticline1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LI_HORIZONTAL,
	);

	$self->{find_next} = Wx::Button->new(
		$self,
		Wx::ID_OK,
		Wx::gettext("&Find Next"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{find_next},
		sub {
			shift->find_next_clicked(@_);
		},
	);

	$self->{replace} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("&Replace"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{replace}->SetDefault;

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{replace},
		sub {
			shift->replace_clicked(@_);
		},
	);

	$self->{replace_all} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("Replace &All"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{replace_all},
		sub {
			shift->replace_all_clicked(@_);
		},
	);

	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext("Cancel"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{cancel},
		sub {
			shift->on_close(@_);
		},
	);

	my $fgSizer2 = Wx::FlexGridSizer->new( 2, 2, 0, 10 );
	$fgSizer2->AddGrowableCol(1);
	$fgSizer2->SetFlexibleDirection(Wx::BOTH);
	$fgSizer2->SetNonFlexibleGrowMode(Wx::FLEX_GROWMODE_SPECIFIED);
	$fgSizer2->Add( $self->{find_case}, 1, Wx::ALL, 5 );

	my $buttons = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$buttons->Add( $self->{find_next}, 0, Wx::ALL, 5 );
	$buttons->Add( $self->{replace}, 0, Wx::ALL, 5 );
	$buttons->Add( $self->{replace_all}, 0, Wx::ALL, 5 );
	$buttons->Add( 30, 0, 1, Wx::EXPAND, 5 );
	$buttons->Add( $self->{cancel}, 0, Wx::ALL, 5 );

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $m_staticText2, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );
	$vsizer->Add( $self->{find_term}, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL | Wx::EXPAND, 5 );
	$vsizer->Add( $m_staticline2, 0, Wx::ALL | Wx::EXPAND, 5 );
	$vsizer->Add( $m_staticText3, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );
	$vsizer->Add( $self->{replace_term}, 0, Wx::ALL | Wx::EXPAND, 5 );
	$vsizer->Add( $m_staticline3, 0, Wx::EXPAND | Wx::ALL, 5 );
	$vsizer->Add( $fgSizer2, 1, Wx::BOTTOM | Wx::EXPAND, 5 );
	$vsizer->Add( $self->{find_regex}, 0, Wx::ALL, 5 );
	$vsizer->Add( $m_staticline1, 0, Wx::ALL | Wx::EXPAND, 5 );
	$vsizer->Add( $buttons, 0, Wx::EXPAND, 5 );

	my $hsizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$hsizer->Add( $vsizer, 1, Wx::ALL | Wx::EXPAND, 5 );

	$self->SetSizerAndFit($hsizer);
	$self->Layout;

	return $self;
}

sub find_term {
	$_[0]->{find_term};
}

sub replace_term {
	$_[0]->{replace_term};
}

sub find_case {
	$_[0]->{find_case};
}

sub find_regex {
	$_[0]->{find_regex};
}

sub find_next {
	$_[0]->{find_next};
}

sub replace {
	$_[0]->{replace};
}

sub replace_all {
	$_[0]->{replace_all};
}

sub on_close {
	$_[0]->main->error('Handler method on_close for event Padre::Wx::FBP::Replace.OnClose not implemented');
}

sub refresh {
	$_[0]->main->error('Handler method refresh for event find_term.OnCombobox not implemented');
}

sub find_next_clicked {
	$_[0]->main->error('Handler method find_next_clicked for event find_next.OnButtonClick not implemented');
}

sub replace_clicked {
	$_[0]->main->error('Handler method replace_clicked for event replace.OnButtonClick not implemented');
}

sub replace_all_clicked {
	$_[0]->main->error('Handler method replace_all_clicked for event replace_all.OnButtonClick not implemented');
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


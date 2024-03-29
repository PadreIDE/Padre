package Padre::Wx::FBP::Patch;

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
		Wx::gettext("Patch"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_DIALOG_STYLE | Wx::RESIZE_BORDER,
	);

	$self->{file1} = Wx::Choice->new(
		$self,
		-1,
		Wx::DefaultPosition,
		[ 200, -1 ],
		[],
	);
	$self->{file1}->SetSelection(0);

	$self->{action} = Wx::RadioBox->new(
		$self,
		-1,
		Wx::gettext("Action"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"Patch",
			"Diff",
		],
		1,
		Wx::RA_SPECIFY_COLS,
	);
	$self->{action}->SetSelection(0);

	Wx::Event::EVT_RADIOBOX(
		$self,
		$self->{action},
		sub {
			shift->on_action(@_);
		},
	);

	$self->{against} = Wx::RadioBox->new(
		$self,
		-1,
		Wx::gettext("Against"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"File-2",
			"SVN",
		],
		2,
		Wx::RA_SPECIFY_COLS,
	);
	$self->{against}->SetSelection(0);
	$self->{against}->Disable;

	Wx::Event::EVT_RADIOBOX(
		$self,
		$self->{against},
		sub {
			shift->on_against(@_);
		},
	);

	$self->{file2} = Wx::Choice->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
	);
	$self->{file2}->SetSelection(0);
	$self->{file2}->SetMinSize( [ 200, -1 ] );

	$self->{process} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("Process"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{process},
		sub {
			shift->process_clicked(@_);
		},
	);

	my $close_button = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext("Close"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$close_button->SetDefault;

	$self->{m_staticline5} = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LI_HORIZONTAL,
	);

	my $file_1 = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self,
			-1,
			Wx::gettext("File-1"),
		),
		Wx::VERTICAL,
	);
	$file_1->Add( $self->{file1}, 0, Wx::ALL, 5 );

	my $sbSizer2 = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self,
			-1,
			Wx::gettext("Options"),
		),
		Wx::HORIZONTAL,
	);
	$sbSizer2->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$sbSizer2->Add( $self->{action}, 0, Wx::ALL, 5 );
	$sbSizer2->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$sbSizer2->Add( $self->{against}, 0, Wx::ALL, 5 );

	my $file_2 = Wx::StaticBoxSizer->new(
		Wx::StaticBox->new(
			$self,
			-1,
			Wx::gettext("File-2"),
		),
		Wx::VERTICAL,
	);
	$file_2->Add( $self->{file2}, 1, Wx::ALL, 5 );

	my $buttons = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$buttons->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$buttons->Add( $self->{process}, 0, Wx::ALL, 5 );
	$buttons->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$buttons->Add( $close_button, 0, Wx::ALL, 5 );

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $file_1, 0, Wx::EXPAND, 5 );
	$vsizer->Add( $sbSizer2, 1, Wx::EXPAND, 5 );
	$vsizer->Add( $file_2, 0, Wx::EXPAND, 5 );
	$vsizer->Add( $buttons, 0, Wx::EXPAND, 3 );
	$vsizer->Add( $self->{m_staticline5}, 0, Wx::EXPAND | Wx::ALL, 5 );

	my $sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$sizer->Add( $vsizer, 0, Wx::ALL, 1 );

	$self->SetSizerAndFit($sizer);
	$self->Layout;

	return $self;
}

sub file1 {
	$_[0]->{file1};
}

sub action {
	$_[0]->{action};
}

sub against {
	$_[0]->{against};
}

sub file2 {
	$_[0]->{file2};
}

sub process {
	$_[0]->{process};
}

sub on_action {
	$_[0]->main->error('Handler method on_action for event action.OnRadioBox not implemented');
}

sub on_against {
	$_[0]->main->error('Handler method on_against for event against.OnRadioBox not implemented');
}

sub process_clicked {
	$_[0]->main->error('Handler method process_clicked for event process.OnButtonClick not implemented');
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


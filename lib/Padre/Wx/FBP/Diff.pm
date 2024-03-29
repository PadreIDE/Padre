package Padre::Wx::FBP::Diff;

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
		Wx::gettext("Diff"),
		Wx::DefaultPosition,
		[ 431, 345 ],
		Wx::DEFAULT_DIALOG_STYLE | Wx::RESIZE_BORDER,
	);

	$self->{prev_diff} = Wx::BitmapButton->new(
		$self,
		-1,
		Wx::NullBitmap,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::BU_AUTODRAW,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{prev_diff},
		sub {
			shift->on_prev_diff_click(@_);
		},
	);

	$self->{next_diff} = Wx::BitmapButton->new(
		$self,
		-1,
		Wx::NullBitmap,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::BU_AUTODRAW,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{next_diff},
		sub {
			shift->on_next_diff_click(@_);
		},
	);

	$self->{left_side_label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Left side"),
	);

	$self->{left_editor} = Wx::ScintillaTextCtrl->new(
		$self,
		-1,
	);

	$self->{right_side_label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Right side"),
	);

	$self->{right_editor} = Wx::ScintillaTextCtrl->new(
		$self,
		-1,
	);

	$self->{close} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("Close"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{close},
		sub {
			shift->on_close_click(@_);
		},
	);

	my $navigation_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$navigation_sizer->Add( $self->{prev_diff}, 0, Wx::ALL, 1 );
	$navigation_sizer->Add( $self->{next_diff}, 0, Wx::ALL, 1 );

	my $left_sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$left_sizer->Add( $self->{left_side_label}, 0, Wx::ALIGN_CENTER_HORIZONTAL | Wx::ALL, 5 );
	$left_sizer->Add( $self->{left_editor}, 1, Wx::ALL | Wx::EXPAND, 0 );

	my $right_sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$right_sizer->Add( $self->{right_side_label}, 0, Wx::ALIGN_CENTER | Wx::ALL, 5 );
	$right_sizer->Add( $self->{right_editor}, 1, Wx::ALL | Wx::EXPAND, 0 );

	my $editor_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$editor_sizer->Add( $left_sizer, 1, Wx::EXPAND, 5 );
	$editor_sizer->Add( $right_sizer, 1, Wx::EXPAND, 5 );

	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$button_sizer->Add( $self->{close}, 0, Wx::ALL, 2 );

	my $main_sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$main_sizer->Add( $navigation_sizer, 0, Wx::ALIGN_RIGHT, 5 );
	$main_sizer->Add( $editor_sizer, 1, Wx::EXPAND, 5 );
	$main_sizer->Add( $button_sizer, 0, Wx::EXPAND, 5 );

	$self->SetSizer($main_sizer);
	$self->Layout;

	return $self;
}

sub on_prev_diff_click {
	$_[0]->main->error('Handler method on_prev_diff_click for event prev_diff.OnButtonClick not implemented');
}

sub on_next_diff_click {
	$_[0]->main->error('Handler method on_next_diff_click for event next_diff.OnButtonClick not implemented');
}

sub on_close_click {
	$_[0]->main->error('Handler method on_close_click for event close.OnButtonClick not implemented');
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


package Padre::Wx::Dialog::Diff;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.91';
our @ISA     = (
	'Padre::Wx::Role::Main',
	'Wx::PlPopupTransientWindow',
);

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	my $panel = Wx::Panel->new($self);

	$self->{prev_diff_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('Previous'),
	);
	$self->{prev_diff_button}->SetToolTip( Wx::gettext('Previous difference') );
	$self->{next_diff_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('Next'),
	);
	$self->{next_diff_button}->SetToolTip( Wx::gettext('Next difference') );

	$self->{revert_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('Revert'),
	);
	$self->{close_button} = Wx::Button->new(
		$panel, Wx::ID_CANCEL, Wx::gettext('Close'),
	);

	$self->{status_label} = Wx::TextCtrl->new(
		$panel,
		-1,
		'',
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_READONLY,
	);

	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( $self->{prev_diff_button}, 0, 0, 0 );
	$button_sizer->Add( $self->{next_diff_button}, 0, 0, 0 );
	$button_sizer->Add( $self->{revert_button},    0, 0, 0 );
	$button_sizer->AddSpacer(10);
	$button_sizer->Add( $self->{close_button}, 0, 0, 0 );

	$self->{original_text} = Wx::TextCtrl->new(
		$panel,
		-1,
		'',
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_READONLY | Wx::wxTE_MULTILINE,
	);

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $button_sizer,          0, Wx::ALL | Wx::EXPAND, 0 );
	$vsizer->Add( $self->{status_label},  0, Wx::ALL | Wx::EXPAND, 0 );
	$vsizer->Add( $self->{original_text}, 1, Wx::ALL | Wx::EXPAND, 0 );

	# Previous difference button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{prev_diff_button},
		\&on_prev_diff_button,
	);

	# Next difference button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{next_diff_button},
		\&on_next_diff_button,
	);


	# Revert button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{revert_button},
		\&on_revert_button,
	);

	# Close button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{close_button},
		sub {
			$_[0]->Hide;
		}
	);

	$panel->SetSizer($vsizer);
	$panel->Fit;
	$self->Fit;

	return $self;
}

sub on_prev_diff_button {
	$_[0]->main->diff->select_previous_difference;
}

sub on_next_diff_button {
	$_[0]->main->diff->select_next_difference;
}

sub on_revert_button {
	my $self  = shift;
	my $event = shift;

	#TODO  implement revert functionality
}

sub show {

	my $self          = shift;
	my $editor        = shift;
	my $message       = shift;
	my $original_text = shift;
	my $pt            = shift;

	$self->Move($pt);
	$self->{status_label}->SetValue($message);
	if ($original_text) {
		$self->{original_text}->Show(1);
		$self->{original_text}->SetValue($original_text);
	} else {
		$self->{original_text}->Show(0);
	}

	# Hide when the editor loses focus
	my $popup = $self;
	Wx::Event::EVT_KILL_FOCUS(
		$editor,
		sub {
			$popup->Hide;
		}
	);

	my $panel = $self->{original_text}->GetParent;
	$panel->Layout;
	$panel->Fit;
	$self->Fit;

	$self->Show(1);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

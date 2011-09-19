package Padre::Wx::Dialog::Diff;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.91';
our @ISA     = 'Wx::PlPopupTransientWindow';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	my $panel = Wx::Panel->new($self);

	$self->{prev_diff_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('&Previous'),
	);
	$self->{prev_diff_button}->SetToolTip( Wx::gettext('Previous difference') );
	$self->{next_diff_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('&Next'),
	);
	$self->{next_diff_button}->SetToolTip( Wx::gettext('Next difference') );

	$self->{revert_button} = Wx::Button->new(
		$panel, -1, Wx::gettext('&Revert'),
	);
	$self->{close_button} = Wx::Button->new(
		$panel, Wx::ID_CANCEL, Wx::gettext('&Close'),
	);

	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$button_sizer->Add( $self->{prev_diff_button}, 0, 0,               0 );
	$button_sizer->Add( $self->{next_diff_button}, 0, 0,               0 );
	$button_sizer->Add( $self->{revert_button},    0, 0,               0 );
	$button_sizer->AddSpacer(10);
	$button_sizer->Add( $self->{close_button},     0, 0, 0 );

	$self->{text_ctrl} = Wx::TextCtrl->new(
		$panel, -1, '', Wx::wxDefaultPosition, [ -1, 100 ],
		Wx::wxTE_MULTILINE
	);

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $button_sizer,      0, Wx::ALL | Wx::EXPAND, 3 );
	$vsizer->Add( $self->{text_ctrl}, 1, Wx::ALL | Wx::EXPAND, 3 );

	# Close button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{revert_button},
		sub {

			#TODO  implement revert functionality
		}
	);

	# Close button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{close_button},
		sub {
			$_[0]->Hide;
		}
	);

	# Previous difference button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{prev_diff_button},
		sub {

			#TODO implement previous diff button
		}
	);

	# Next difference button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{next_diff_button},
		sub {

			#TODO implement next diff button
		}
	);

	$panel->SetSizer($vsizer);
	$panel->Fit; $self->Fit;

	return $self;
}

sub show {

	my $self    = shift;
	my $message = shift;
	my $pt      = shift;

	$self->Move($pt);
	$self->{text_ctrl}->SetValue($message); $self->Show(1);
}

sub ProcessLeftDown {
	my ( $self, $event ) = @_;
	print "Process Left $event\n";

	#$event->Skip;
	return 0;
}

sub OnDismiss {
	my ( $self, $event ) = @_;
	print "OnDismiss\n";

	#$event->Skip;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

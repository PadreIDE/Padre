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

	#$self->SetBackgroundColour(Wx::WHITE);
	my $panel = Wx::Panel->new($self);
	
	my $button_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->{prev_diff} = Wx::Button->new(
		$panel, -1, Wx::gettext('&Previous Difference'),
	);
	$self->{next_diff} = Wx::Button->new(
		$panel, -1, Wx::gettext('&Next Difference'),
	);
	$self->{revert} = Wx::Button->new(
		$panel, -1, Wx::gettext('&Revert'),
	);
	$self->{close_button} = Wx::Button->new(
		$panel, Wx::ID_CANCEL, Wx::gettext('&Close'),
	);

	$button_sizer->Add( $self->{prev_diff}, 0, 0, 0 );
	$button_sizer->Add( $self->{next_diff}, 0, 0, 0 );
	$button_sizer->Add( $self->{revert}, 0, 0, 0);
	$button_sizer->Add( $self->{close_button}, 0, Wx::ALIGN_RIGHT, 5 );

	$self->{text_ctrl} = Wx::TextCtrl->new($panel, -1, '', Wx::wxDefaultPosition, [-1, 100],
            Wx::wxTE_MULTILINE);

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $button_sizer, 0, Wx::ALL | Wx::EXPAND, 3 );
	$vsizer->Add( $self->{text_ctrl},   1, Wx::ALL | Wx::EXPAND, 3 );

	# Close button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{close_button},
		sub {
			$_[0]->Hide;
		}
	);

	$panel->SetSizer($vsizer);
	$panel->Fit;	$self->Fit;

	return $self;
}

sub show {

	my $self    = shift;
	my $message = shift;
	my $pt      = shift;

	$self->Move($pt);
	$self->{text_ctrl}->SetValue($message); $self->Show(1);
}

sub ProcessLeftDown {	my ( $self, $event ) = @_;
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

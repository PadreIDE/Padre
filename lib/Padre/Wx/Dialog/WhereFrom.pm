package Padre::Wx::Dialog::WhereFrom;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task     ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();

our $VERSION = '0.66';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::Main
	Wx::Dialog
};

use constant SERVER => 'http://perlide.org/popularity/v1/wherefrom.html';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('New installation survey'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);
	$self->SetMinSize( [ 350, 100 ] );

	# Create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	# Create the controls
	$self->_create_controls($sizer);

	# Ok button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_ok},
		sub {
			$_[0]->button_ok( $_[1] );
		},
	);

	# Cancel or Skip feedback button
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->button_cancel( $_[1] );
		},
	);

	# Wrap everything in a vbox to add some padding
	$self->SetSizer($sizer);
	$self->Fit;
	$self->CentreOnParent;

	$self->{from}->SetFocus;
	$self->Show(1);

	return $self;
}

sub _create_controls {
	my $self  = shift;
	my $sizer = shift;

	# "Where did you hear..." label
	my $from_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Where did you hear about Padre?')
	);

	my $choices = [
		'Google',
		Wx::gettext('Other search engine'),
		'FOSDEM',
		'CeBit',
		Wx::gettext('Other event'),
		Wx::gettext('Friend'),
		Wx::gettext('Reinstalling/installing on other computer'),
		Wx::gettext('Other (Please fill in here)'),
	];

	$self->{from} = Wx::ComboBox->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		$choices
	);

	# OK button
	$self->{button_ok} = Wx::Button->new(
		$self, Wx::wxID_OK, Wx::gettext("OK"),
	);
	$self->{button_ok}->SetDefault;

	# Cancel button
	$self->{button_cancel} = Wx::Button->new(
		$self, Wx::wxID_CANCEL,
		Wx::gettext("Skip question without giving feedback"),
	);

	# where from...? sizer
	my $from_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$from_sizer->Add( $from_label,, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$from_sizer->AddSpacer(5);
	$from_sizer->Add( $self->{from}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Button sizer
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_ok},     0, 0,          0 );
	$button_sizer->Add( $self->{button_cancel}, 0, Wx::wxLEFT, 5 );
	$button_sizer->AddSpacer(5);

	# Main vertical sizer
	my $vsizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$vsizer->Add( $from_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->AddSpacer(5);
	$vsizer->Add( $button_sizer, 0, Wx::wxALIGN_RIGHT, 5 );
	$vsizer->AddSpacer(5);

	# Wrap with a horizontal sizer to get left/right padding
	$sizer->Add( $vsizer, 1, Wx::wxALL | Wx::wxEXPAND, 5 );

	return;
}





######################################################################
# Event Handlers

sub button_cancel {
	my $self   = shift;
	my $event  = shift;
	my $config = $self->config;
	$self->Destroy;
	return if $config->feedback_done;

	# Don't ask again
	$config->set( feedback_done => 1 );
	$config->write;

	return;
}

sub button_ok {
	my $self   = shift;
	my $event  = shift;
	my $from   = $self->{from}->GetValue;
	my $config = $self->config;
	$self->Destroy;
	return if $config->feedback_done;

	# Fire and forget the HTTP request to the server
	$self->task_request(
		task  => 'Padre::Task::LWP',
		url   => SERVER,
		query => { from => $from },
	);

	# Don't ask again
	$config->set( feedback_done => 1 );
	$config->write;

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

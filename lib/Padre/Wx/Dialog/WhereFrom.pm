package Padre::Wx::Dialog::WhereFrom;

use 5.008;
use strict;
use warnings;
use Padre::Wx               ();
use Padre::Task::HTTPClient ();

our $VERSION = '0.64';

our @ISA = 'Wx::Dialog';

sub new {
	my ( $class, $main ) = @_;

	my $config = $main->config;
	return if $config->feedback_done;

	# Create the Wx dialog
	my $dialog = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('New installation survey'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Minimum dialog size
	$dialog->SetMinSize( [ 350, 100 ] );

	# Create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	# Create the controls
	$dialog->_create_controls($sizer);

	# Bind the control events
	$dialog->_bind_events;

	# Wrap everything in a vbox to add some padding
	$dialog->SetSizer($sizer);
	$dialog->Fit;
	$dialog->CentreOnParent;

	$dialog->{wherefrom}->SetFocus;
	$dialog->Show(1);

	return $dialog;
}

sub _create_controls {
	my ( $dialog, $sizer ) = @_;

	# "Where did you hear..." label
	my $wherefrom_label = Wx::StaticText->new(
		$dialog,
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

	$dialog->{wherefrom} = Wx::ComboBox->new(
		$dialog,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		$choices
	);

	# OK button
	$dialog->{button_ok} = Wx::Button->new(
		$dialog, Wx::wxID_OK, Wx::gettext("OK"),
	);
	$dialog->{button_ok}->SetDefault;

	# Cancel button
	$dialog->{button_cancel} = Wx::Button->new(
		$dialog, Wx::wxID_CANCEL,
		Wx::gettext("Skip question without giving feedback"),
	);

	# where from...? sizer
	my $wherefrom_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$wherefrom_sizer->Add( $wherefrom_label,, 0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$wherefrom_sizer->AddSpacer(5);
	$wherefrom_sizer->Add( $dialog->{wherefrom}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Button sizer
	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $dialog->{button_ok},     0, 0,          0 );
	$button_sizer->Add( $dialog->{button_cancel}, 0, Wx::wxLEFT, 5 );
	$button_sizer->AddSpacer(5);

	# Main vertical sizer
	my $vsizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$vsizer->Add( $wherefrom_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 3 );
	$vsizer->AddSpacer(5);
	$vsizer->Add( $button_sizer, 0, Wx::wxALIGN_RIGHT, 5 );
	$vsizer->AddSpacer(5);

	# Wrap with a horizontal sizer to get left/right padding
	$sizer->Add( $vsizer, 1, Wx::wxALL | Wx::wxEXPAND, 5 );

	return;
}


sub _bind_events {
	my $dialog = shift;

	# Ok button
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{button_ok},
		\&WhereFrom_ok_clicked
	);

	# Cancel or Skip feedback button
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{button_cancel},
		\&WhereFrom_cancel_clicked
	);

	return;
}

sub WhereFrom_cancel_clicked {
	my ( $dialog, $event ) = @_;

	my $config = Padre->ide->config;

	if ( !$config->feedback_done ) {
		$config->set( 'feedback_done', 1 );
		$config->write;
	}

	$dialog->Destroy;

	return;
}

sub WhereFrom_ok_clicked {
	my ( $dialog, $event ) = @_;

	my $config = Padre->ide->config;

	my $window = $dialog->GetParent;
	$dialog->Destroy;

	if ( !$config->feedback_done ) {

		my $url  = 'http://perlide.org/popularity/v1/wherefrom.html';
		my $args = { from => $dialog->{wherefrom}->GetValue };
		my $http = Padre::Task::HTTPClient->new(
			URL   => $url,
			query => $args,
		)->run;

		$config->set( 'feedback_done', 1 );
		$config->write;

	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Dialog::WhereFrom;

use 5.008;
use strict;
use warnings;
use Padre::Wx               ();
use Padre::Task::HTTPClient ();

our $VERSION = '0.58';

our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

sub new {
	my ( $class, $main ) = @_;

	my $config = Padre->ide->config;
	#return if $config->feedback_done;

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
	$dialog->SetMinSize( [ 200, 300 ] );

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

	$dialog->{combo}->SetFocus;
	$dialog->Show(1);

	return $dialog;
}

sub _create_controls {
	my $dialog = shift;

	# "Where did you hear..." label
	my $label = Wx::StaticText->new( $dialog, -1, Wx::gettext('Where did you hear about Padre?') );

	my $options = [   
		'Google',
		Wx::gettext('Other searchengine'),
		'FOSDEM',
		'CeBit',
		Wx::gettext('Other event'),
		Wx::gettext('Friend'),
		Wx::gettext('Reinstalling/Installing on other computer'),
		Wx::gettext('Other (Please fill in here)'),
	];
	
	$dialog->{combo} = Wx::ComboBox->new( $dialog, -1, '' );
	
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
	
	
}


sub _bind_events {
	my $dialog = shift;
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{button_ok},     \&WhereFrom_ok_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{button_cancel}, \&WhereFrom_cancel_clicked );
}

sub WhereFrom_cancel_clicked {
	my ( $dialog, $event ) = @_;

	my $config = Padre->ide->config;

	if ( !$config->feedback_done ) {
		$config->set( 'feedback_done', 1 );
		$config->write;
	}

	$dialog->Destroy;
}

sub WhereFrom_ok_clicked {
	my ( $dialog, $event ) = @_;

	my $config = Padre->ide->config;

	my $window = $dialog->GetParent;
	my $data   = $dialog->get_data;
	$dialog->Destroy;

	if ( !$config->feedback_done ) {

		my $url  = 'http://padre.perlide.org/wherefrom.cgi';
		my $args = { from => $data->{_referer_} };
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

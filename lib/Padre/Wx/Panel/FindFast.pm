package Padre::Wx::Panel::FindFast;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::FindFast ();

our $VERSION = '0.93';
our @ISA     = 'Padre::Wx::FBP::FindFast';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Immediately hide the panel to prevent display glitching
	$self->Hide;

	# Create a private pane in AUI
	$self->main->aui->AddPane(
		$self,
		Padre::Wx->aui_pane_info(
			Name           => 'footer',
			PaneBorder     => 0,
			Resizable      => 1,
			CaptionVisible => 0,
			Layer          => 1,
			PaneBorder     => 0,
		)->Bottom->Hide,
	);

	return $self;
}





######################################################################
# Event Handlers

sub on_cancel {
	my $self = shift;
	$self->hide;
	$self->
}





######################################################################
# Main Methods

sub show {
	my $self = shift;
	my $aui  = $self->main->aui;

	# Reset the content of the panel
	$self->{find_term}->SetValue('');
	$self->{find_term}->SetFocus;

	# Show the AUI pane
	$aui->GetPane('footer')->Show;
	$aui->Update;

	return 1;
}

sub hide {
	my $self = shift;
	my $aui  = $self->main->aui;

	# Hide the AUI pane
	$aui->GetPane('footer')->Hide;
	$aui->Update;

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

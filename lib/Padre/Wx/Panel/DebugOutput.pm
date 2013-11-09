package Padre::Wx::Panel::DebugOutput;

use 5.010;
use strict;
use warnings;

use utf8;
use Padre::Wx::Role::View;
use Padre::Wx::FBP::DebugOutput ();

our $VERSION = '1.00';

our @ISA = qw{
	Padre::Wx::Role::View
	Padre::Wx::FBP::DebugOutput
};

use constant {
	RED        => Wx::Colour->new('red'),
	DARK_GREEN => Wx::Colour->new( 0x00, 0x90, 0x00 ),
	BLUE       => Wx::Colour->new('blue'),
	GRAY       => Wx::Colour->new('gray'),
	DARK_GRAY  => Wx::Colour->new( 0x7f, 0x7f, 0x7f ),
	BLACK      => Wx::Colour->new('black'),
};

#######
# new
#######
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	# 	# Create the panel
	my $self = $class->SUPER::new($panel);

	return $self;
}

###############
# Make Padre::Wx::Role::View happy
###############

sub view_panel {
	'bottom';
}

sub view_label {
	Wx::gettext('Debug Output');
}

sub view_close {
	$_[0]->main->show_debugoutput(0);
}

sub view_icon {
	Padre::Wx::Icon::find('actions/morpho3');
}

sub view_start {
	return;
}

sub view_stop {
	return;
}

###############
# Make Padre::Wx::Role::View happy end
###############

#######
# Method debug_output
#######
sub debug_output {
	my $self   = shift;
	my $output = shift;

	$self->{output}->SetForegroundColour(RED);
	$self->{output}->ChangeValue($output);

	# auto focus to panel debug output
	$self->main->debugoutput->SetFocus;

	return;
}
#######
# Method debug_output_black
#######
sub debug_output_black {
	my $self   = shift;
	my $output = shift;

	$self->{output}->SetForegroundColour(BLACK);
	$self->{output}->ChangeValue($output);

	# auto focus to panel debug output
	$self->main->debugoutput->SetFocus;

	return;
}
#######
# Method debug_output_blue
#######
sub debug_output_blue {
	my $self   = shift;
	my $output = shift;

	$self->{output}->SetForegroundColour(BLUE);
	$self->{output}->ChangeValue($output);

	# auto focus to panel debug output
	$self->main->debugoutput->SetFocus;

	return;
}

#######
# Method debug_output_dark_gray
#######
sub debug_output_dark_gray {
	my $self   = shift;
	my $output = shift;

	$self->{output}->SetForegroundColour(DARK_GRAY);
	$self->{output}->ChangeValue($output);

	# auto focus to panel debug output
	$self->main->debugoutput->SetFocus;

	return;
}

########
# debug_status
########
sub debug_status {
	my $self   = shift;
	my $status = shift;
	$self->{status}->SetLabel($status);
	return;
}

########
# debug launch options
########
sub debug_launch_options {
	my $self   = shift;
	my $options = shift || 'none';
	$self->{dl_options}->SetLabel($options);
	return;
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

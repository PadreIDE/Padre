package Padre::Wx::Menu::Run;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.41';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Script Execution
	$self->{run_document} = $self->Append(
		-1,
		Wx::gettext("Run Script\tF5")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{run_document},
		sub {
			$_[0]->run_document;
		},
	);

	$self->{run_document_debug} = $self->Append(
		-1,
		Wx::gettext("Run Script (debug info)\tShift-F5")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{run_document_debug},
		sub {
			$_[0]->run_document(1); # Enable debug info
		},
	);

	$self->{run_command} = $self->Append(
		-1,
		Wx::gettext("Run Command\tCtrl-F5")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{run_command},
		sub {
			$_[0]->on_run_command;
		},
	);

	$self->{run_tests} = $self->Append(
		-1,
		Wx::gettext("Run Tests")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{run_tests},
		sub {
			$_[0]->on_run_tests;
		},
	);
	$self->AppendSeparator;

	$self->{stop} = $self->Append(
		-1,
		Wx::gettext("Stop\tF6")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{stop},
		sub {
			if ( $_[0]->{command} ) {
				$_[0]->{command}->TerminateProcess;
			}
			delete $_[0]->{command};
			return;
		},
	);

	# Initialise enabled
	$self->enable;

	return $self;
}

sub refresh {
	my $self     = shift;
	my $document = _CURRENT(@_)->document;

	# Disable if not document,
	# otherwise match run_command state
	$self->{run_document}->Enable(
		  $document
		? $self->{run_command}->IsEnabled
		: 0
	);
	$self->{run_document_debug}->Enable(
		  $document
		? $self->{run_command}->IsEnabled
		: 0
	);
	$self->{run_tests}->Enable(
		  $document
		? $self->{run_command}->IsEnabled
		: 0
	);

	return 1;
}

#####################################################################
# Custom Methods

sub enable {
	my $self = shift;
	$self->{run_document}->Enable(1);
	$self->{run_document_debug}->Enable(1);
	$self->{run_command}->Enable(1);
	$self->{stop}->Enable(0);
	return;
}

sub disable {
	my $self = shift;
	$self->{run_document}->Enable(0);
	$self->{run_document_debug}->Enable(0);
	$self->{run_command}->Enable(0);
	$self->{stop}->Enable(1);
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

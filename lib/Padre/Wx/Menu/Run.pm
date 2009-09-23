package Padre::Wx::Menu::Run;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.46';
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
	$self->{run_document} = $self->add_menu_item(
		$self,
		name       => 'run.run_document',
		label      => Wx::gettext('Run Script'),
		shortcut   => 'F5',
		menu_event => sub {
			$_[0]->run_document;
			$_[0]->refresh_toolbar( $_[0]->current );
		},
	);

	$self->{run_document_debug} = $self->add_menu_item(
		$self,
		name       => 'run.run_document_debug',
		label      => Wx::gettext('Run Script (debug info)'),
		shortcut   => 'Shift-F5',
		menu_event => sub {
			$_[0]->run_document(1); # Enable debug info
		},
	);

	$self->{run_command} = $self->add_menu_item(
		$self,
		name       => 'run.run_command',
		label      => Wx::gettext('Run Command'),
		shortcut   => 'Ctrl-F5',
		menu_event => sub {
			$_[0]->on_run_command;
		},
	);

	$self->{run_tests} = $self->add_menu_item(
		$self,
		name       => 'run.run_tests',
		label      => Wx::gettext('Run Tests'),
		menu_event => sub {
			$_[0]->on_run_tests;
		},
	);

	$self->{run_this_test} = $self->add_menu_item(
		$self,
		name       => 'run.run_this_test',
		label      => Wx::gettext('Run This Test'),
		menu_event => sub {
			$_[0]->on_run_this_test;
		},
	);

	$self->AppendSeparator;

	$self->{stop} = $self->add_menu_item(
		$self,
		name       => 'run.stop',
		label      => Wx::gettext('Stop execution'),
		shortcut   => 'F6',
		menu_event => sub {
			if ( $_[0]->{command} ) {
				if (Padre::Constant::WIN32) {
					$_[0]->{command}->KillProcess;
				} else {
					$_[0]->{command}->TerminateProcess;
				}
			}
			delete $_[0]->{command};
			$_[0]->refresh_toolbar( $_[0]->current );
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
	$self->{run_this_test}->Enable(
		  $document && defined( $document->filename ) && $document->filename =~ /\.t$/
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
	$self->{main}->refresh_toolbar( _CURRENT );
	return;
}

sub disable {
	my $self = shift;
	$self->{run_document}->Enable(0);
	$self->{run_document_debug}->Enable(0);
	$self->{run_command}->Enable(0);
	$self->{stop}->Enable(1);
	$self->{main}->refresh_toolbar( _CURRENT );
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

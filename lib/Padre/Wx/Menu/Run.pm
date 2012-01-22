package Padre::Wx::Menu::Run;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ();

our $VERSION = '0.94';
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
	$self->{run_document} = $self->add_menu_action(
		'run.run_document',
	);

	$self->{run_document_debug} = $self->add_menu_action(
		'run.run_document_debug',
	);

	$self->{run_command} = $self->add_menu_action(
		'run.run_command',
	);

	$self->AppendSeparator;

	$self->{run_tests} = $self->add_menu_action(
		'run.run_tests',
	);

	$self->{run_tdd_tests} = $self->add_menu_action(
		'run.run_tdd_tests',
	);

	$self->{run_this_test} = $self->add_menu_action(
		'run.run_this_test',
	);

	$self->AppendSeparator;

	$self->{stop} = $self->add_menu_action(
		'run.stop',
	);

	return $self;
}

sub title {
	Wx::gettext('&Run');
}

sub refresh {
	my $self     = shift;
	my $document = Padre::Current::_CURRENT(@_)->document;

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
	$self->{run_tdd_tests}->Enable(
		  $document && defined( $document->filename )
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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

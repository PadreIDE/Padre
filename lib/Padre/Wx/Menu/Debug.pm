package Padre::Wx::Menu::Debug;

# Fully encapsulated Debug menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ();

our $VERSION = '0.90';
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

	$self->{step_in} = $self->add_menu_action(
		'debug.step_in',
	);

	$self->{step_over} = $self->add_menu_action(
		'debug.step_over',
	);

	$self->{step_out} = $self->add_menu_action(
		'debug.step_out',
	);

	$self->{run} = $self->add_menu_action(
		'debug.run',
	);

	$self->AppendSeparator;

	$self->{jump_to} = $self->add_menu_action(
		'debug.jump_to',
	);

	$self->AppendSeparator;

	$self->{set_breakpoint} = $self->add_menu_action(
		'debug.set_breakpoint',
	);

	$self->{remove_breakpoint} = $self->add_menu_action(
		'debug.remove_breakpoint',
	);

	$self->{list_breakpoints} = $self->add_menu_action(
		'debug.list_breakpoints',
	);

	$self->AppendSeparator;

	$self->{show_stack_trace} = $self->add_menu_action(
		'debug.show_stack_trace',
	);

	$self->{display_value} = $self->add_menu_action(
		'debug.display_value',
	);

	$self->AppendSeparator;

	$self->{show_value} = $self->add_menu_action(
		'debug.show_value',
	);

	$self->{evaluate_expression} = $self->add_menu_action(
		'debug.evaluate_expression',
	);

	$self->AppendSeparator;

	$self->{quit} = $self->add_menu_action(
		'debug.quit',
	);

	return $self;
}

sub title {
	Wx::gettext('&Debug');
}

sub refresh {
	my $self     = shift;
	my $document = Padre::Current::_CURRENT(@_)->document;
	my $hasdoc   = $document ? 1 : 0;

	$self->{step_in}->Enable($hasdoc);
	$self->{step_over}->Enable($hasdoc);
	$self->{step_out}->Enable($hasdoc);
	$self->{run}->Enable($hasdoc);
	$self->{jump_to}->Enable($hasdoc);
	$self->{set_breakpoint}->Enable($hasdoc);
	$self->{remove_breakpoint}->Enable($hasdoc);
	$self->{list_breakpoints}->Enable($hasdoc);
	$self->{show_stack_trace}->Enable($hasdoc);
	$self->{display_value}->Enable($hasdoc);
	$self->{show_value}->Enable($hasdoc);
	$self->{evaluate_expression}->Enable($hasdoc);

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

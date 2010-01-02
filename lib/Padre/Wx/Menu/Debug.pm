package Padre::Wx::Menu::Debug;

# Fully encapsulated Debug menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.53';
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

	$self->{debug_step_in} = $self->add_menu_action(
		$self,
		'debug.step_in',
	);

	$self->{debug_step_over} = $self->add_menu_action(
		$self,
		'debug.step_over',
	);

	$self->{debug_step_out} = $self->add_menu_action(
		$self,
		'debug.step_out',
	);

	$self->{debug_run} = $self->add_menu_action(
		$self,
		'debug.run',
	);

	#	$self->{debug_run_to_cursor} = $self->add_menu_action(
	#		$self,
	#		'debug.run_to_cursor',
	#	);

	$self->AppendSeparator;

	$self->{debug_jump_to} = $self->add_menu_action(
		$self,
		'debug.jump_to',
	);

	$self->AppendSeparator;

	$self->{debug_set_breakpoint} = $self->add_menu_action(
		$self,
		'debug.set_breakpoint',
	);

	$self->{debug_remove_breakpoint} = $self->add_menu_action(
		$self,
		'debug.remove_breakpoint',
	);

	$self->{debug_list_breakpoints} = $self->add_menu_action(
		$self,
		'debug.list_breakpoints',
	);

	$self->AppendSeparator;

	$self->{debug_show_stack_trace} = $self->add_menu_action(
		$self,
		'debug.show_stack_trace',
	);

	$self->{debug_display_value} = $self->add_menu_action(
		$self,
		'debug.display_value',
	);

	$self->AppendSeparator;

	$self->{debug_show_value} = $self->add_menu_action(
		$self,
		'debug.show_value',
	);

	$self->{debug_evaluate_expression} = $self->add_menu_action(
		$self,
		'debug.evaluate_expression',
	);

	$self->AppendSeparator;

	$self->{debug_quit} = $self->add_menu_action(
		$self,
		'debug.quit',
	);

	return $self;
}

sub title {
	my $self = shift;

	return Wx::gettext('&Debug');
}

sub refresh {
	my $self     = shift;
	my $document = _CURRENT(@_)->document;

	return 1;
}

1;


# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

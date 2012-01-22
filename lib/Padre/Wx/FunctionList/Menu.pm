package Padre::Wx::FunctionList::Menu;

# Menu that shows up when user right-clicks with the mouse

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::Role::Main ();
use Padre::Wx::Menu       ();
use Padre::Feature        ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Padre::Wx::Menu
};

sub new {
	my $class     = shift;
	my $functions = shift;

	# Create the empty menu
	my $self = $class->SUPER::new();
	$self->{main} = $functions->main;

	# Preferences

	$self->append_config_options(
		$self => 'main_functions_order',
	);

	# $self->AppendSeparator;
	# $self->append_config_options(
		# $self => 'main_functions_panel',
	# );

	return $self;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Menu::Refactor;

# Fully encapsulated Refactor menu

use 5.008;
use strict;
use warnings;
use List::Util    ();
use File::Spec    ();
use File::HomeDir ();
use Params::Util qw{_INSTANCE};
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Locale   ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.47';
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

	# Cache the configuration
	$self->{config} = Padre->ide->config;


	# Perl-Specific Refactoring
	$self->{rename_variable} = $self->add_menu_action(
		$self,
		'perl.rename_variable',
	);

	$self->{extract_subroutine} = $self->add_menu_action(
		$self,
		'perl.extract_subroutine',
	);

	$self->{introduce_temporary} = $self->add_menu_action(
		$self,
		'perl.introduce_temporary',
	);


	return $self;
}

sub refresh {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $config  = $current->config;
	my $perl    = !!( _INSTANCE( $current->document, 'Padre::Document::Perl' ) );

	$self->{rename_variable}->Enable($perl);
	$self->{introduce_temporary}->Enable($perl);
	$self->{extract_subroutine}->Enable($perl);

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

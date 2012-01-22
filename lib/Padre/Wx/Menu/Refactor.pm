package Padre::Wx::Menu::Refactor;

# Fully encapsulated Refactor menu

use 5.008;
use strict;
use warnings;
use List::Util      ();
use File::Spec      ();
use File::HomeDir   ();
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Locale   ();
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

	# Cache the configuration
	$self->{config} = Padre->ide->config;

	# Perl-Specific Refactoring
	$self->{rename_variable} = $self->add_menu_action(
		$self,
		'perl.rename_variable',
	);

	# Create the variable-style submenu
	my $style = Wx::Menu->new;
	$self->{variable_style_menu} = $self->Append(
		-1,
		Wx::gettext('&Change variable style'),
		$style,
	);

	$self->add_menu_action(
		$style,
		'perl.variable_to_camel_case',
	);

	$self->add_menu_action(
		$style,
		'perl.variable_to_camel_case_ucfirst',
	);

	$self->add_menu_action(
		$style,
		'perl.variable_from_camel_case',
	);

	$self->add_menu_action(
		$style,
		'perl.variable_from_camel_case_ucfirst',
	);

	$self->{extract_subroutine} = $self->add_menu_action(
		'perl.extract_subroutine',
	);

	$self->{introduce_temporary} = $self->add_menu_action(
		'perl.introduce_temporary',
	);

	$self->AppendSeparator;

	$self->{endify_pod} = $self->add_menu_action(
		'perl.endify_pod',
	);

	return $self;
}

sub title {
	Wx::gettext('Ref&actor');
}

sub refresh {
	my $self     = shift;
	my $current  = Padre::Current::_CURRENT(@_);
	my $document = $current->document;

	$self->{rename_variable}->Enable( $document->can('rename_variable')                  ? 1 : 0 );
	$self->{introduce_temporary}->Enable( $document->can('introduce_temporary_variable') ? 1 : 0 );
	$self->{extract_subroutine}->Enable( $document->can('extract_subroutine')            ? 1 : 0 );
	$self->{endify_pod}->Enable( $document->isa('Padre::Document::Perl')                 ? 1 : 0 );
	$self->{variable_style_menu}->Enable( $document->isa('Padre::Document::Perl')        ? 1 : 0 );

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

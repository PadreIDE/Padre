package Padre::Wx::Menu::Perl;

# Fully encapsulated Perl menu

use 5.008;
use strict;
use warnings;
use List::Util      ();
use File::Spec      ();
use File::HomeDir   ();
use Params::Util    ();
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

	# Perl-Specific Searches
	$self->{beginner_check} = $self->add_menu_action(
		'perl.beginner_check',
	);

	$self->{perl_deparse} = $self->add_menu_action(
		'perl.deparse',
	);

	$self->AppendSeparator;

	$self->{find_brace} = $self->add_menu_action(
		'perl.find_brace',
	);

	$self->{find_variable} = $self->add_menu_action(
		'perl.find_variable',
	);

	$self->{find_method} = $self->add_menu_action(
		'perl.find_method',
	);

	$self->{create_tagsfile} = $self->add_menu_action(
		'perl.create_tagsfile',
	);


	$self->AppendSeparator;

	$self->add_menu_action(
		'perl.vertically_align_selected',
	);

	$self->add_menu_action(
		'perl.newline_keep_column',
	);

	# $self->AppendSeparator;

	# Move of stacktrace to Run
	#	# Make it easier to access stack traces
	#	$self->{run_stacktrace} = $self->AppendCheckItem( -1,
	#		Wx::gettext("Run Scripts with Stack Trace")
	#	);
	#	Wx::Event::EVT_MENU( $main, $self->{run_stacktrace},
	#		sub {
	#			# Update the saved config setting
	#			my $config = Padre->ide->config;
	#			$config->set( run_stacktrace => $_[1]->IsChecked ? 1 : 0 );
	#			$self->refresh;
	#		}
	#	);

	return $self;
}

sub title {
	Wx::gettext('&Perl');
}

sub refresh {
	my $self    = shift;
	my $current = Padre::Current::_CURRENT(@_);
	my $config  = $current->config;
	my $perl    = !!Params::Util::_INSTANCE(
		$current->document,
		'Padre::Document::Perl',
	);

	# Disable document-specific entries if we are in a Perl project
	# but not in a Perl document.
	$self->{find_brace}->Enable($perl);
	$self->{find_variable}->Enable($perl);
	$self->{find_variable}->Enable($perl);

	#	$self->{rename_variable}->Enable($perl);
	#	$self->{introduce_temporary}->Enable($perl);
	#	$self->{extract_subroutine}->Enable($perl);
	$self->{beginner_check}->Enable($perl);

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

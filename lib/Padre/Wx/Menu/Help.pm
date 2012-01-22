package Padre::Wx::Menu::Help;

# Fully encapsulated help menu

use 5.008;
use strict;
use warnings;
use utf8;
use Padre::Constant ();
use Padre::Current  ();
use Padre::Locale   ();
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);
	$self->{main} = $main;

	# Add the POD-based help launchers
	$self->add_menu_action('help.help');

	$self->add_menu_action(
		'help.context_help',
	);

	$self->add_menu_action(
		'help.search',
	);

	$self->{current} = $self->add_menu_action(
		'help.current',
	);

	# Live Support
	$self->AppendSeparator;

	$self->{live} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("&Live Support"),
		$self->{live}
	);

	$self->add_menu_action(
		$self->{live},
		'help.live_support',
	);

	$self->{live}->AppendSeparator;

	$self->add_menu_action(
		$self->{live},
		'help.perl_help',
	);

	if (Padre::Constant::WIN32) {
		$self->add_menu_action(
			$self->{live},
			'help.win32_questions',
		);
	}

	$self->AppendSeparator;

	# Add interesting and helpful websites
	$self->add_menu_action(
		'help.visit_perl_websites',
	);

	$self->AppendSeparator;

	# Add Padre website tools
	$self->add_menu_action(
		'help.report_a_bug',
	);

	$self->add_menu_action(
		'help.view_all_open_bugs',
	);

	$self->add_menu_action(
		'help.translate_padre',
	);

	$self->AppendSeparator;

	# Add the About
	$self->add_menu_action(
		'help.about',
	);
	
	# Add the About2
	$self->add_menu_action(
		'help.about2',
	);
	
	return $self;
}

sub title {
	Wx::gettext('&Help');
}

sub refresh {
	my $self    = shift;
	my $current = Padre::Current::_CURRENT(@_);
	my $hasdoc  = $current->document ? 1 : 0;

	# Don't show "Current Document" unless there is one
	$self->{current}->Enable($hasdoc);

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

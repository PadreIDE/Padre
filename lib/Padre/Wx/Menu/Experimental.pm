package Padre::Wx::Menu::Experimental;

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.25';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Disable experimental mode
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1,
			Wx::gettext('Disable Experimental Mode')
		),
		sub {
			Padre->ide->config->{experimental} = 0;
			$_[0]->menu->refresh($_[0]->current);
			return;
		},
	);

	$self->AppendSeparator;

	# Force-refresh the menu
	Wx::Event::EVT_MENU( $main,
		$self->Append( -1, Wx::gettext('Refresh Menu') ),
		sub {
			$_[0]->menu->refresh($_[0]->current);
			return;
		},
	);

	# Force-refresh the menu
	$self->{refresh_counter} = 0;
	$self->{refresh_count}   = $self->Append( -1,
		Wx::gettext('Refresh Counter: ')
		. $self->{refresh_counter}
	);
	Wx::Event::EVT_MENU( $main,
		$self->{refresh_count},
		sub {
			return;
		},
	);

	$self->AppendSeparator;

	# Recent projects
	$self->{recent_projects} = Wx::Menu->new;
	$self->Append( -1,
		Wx::gettext("Recent Projects") . '...',
		$self->{recent_projects},
	);

	return $self;
}

# Update the checkstate for several menu items
sub refresh {
	my $self   = shift;

	# Update the refresh counter
	$self->{refresh_counter}++;
	$self->{refresh_count}->SetText( 
		Wx::gettext('Refresh Counter: ') . $self->{refresh_counter}
	);

	return;
}

1;
# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

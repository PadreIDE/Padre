package Padre::Wx::Menu::Search;

# Fully encapsulated Search menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ();

our $VERSION = '0.86';
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

	# Search
	$self->{find} = $self->add_menu_action(
		$self,
		'search.find',
	);

	$self->{find_next} = $self->add_menu_action(
		$self,
		'search.find_next',
	);

	$self->{find_previous} = $self->add_menu_action(
		$self,
		'search.find_previous',
	);

	$self->AppendSeparator;

	# Search and Replace
	$self->{replace} = $self->add_menu_action(
		$self,
		'search.replace',
	);

	$self->AppendSeparator;

	# Recursive Search
	$self->add_menu_action(
		$self,
		'search.find_in_files',
	);

	$self->add_menu_action(
		$self,
		'search.replace_in_files',
	);

	$self->AppendSeparator;

	$self->add_menu_action(
		$self,
		'search.open_resource',
	);

	$self->add_menu_action(
		$self,
		'search.quick_menu_access',
	);

	return $self;
}

sub title {
	Wx::gettext('&Search');
}

sub refresh {
	my $self = shift;
	my $doc = Padre::Current->editor ? 1 : 0;

	$self->{find}->Enable($doc);
	$self->{find_next}->Enable($doc);
	$self->{find_previous}->Enable($doc);
	$self->{replace}->Enable($doc);

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

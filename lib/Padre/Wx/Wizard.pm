package Padre::Wx::Wizard;

use 5.008;
use strict;
use warnings;
use Padre::Config   ();
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.75';

# Generate faster accessors
use Class::XSAccessor {
	getters => {
		name     => 'name',
		label    => 'label',
		category => 'category',
		comment  => 'comment',
	},
};





#####################################################################
# Functions

# This sub calls all the other files which actually create the actions
sub create {
	my $main = shift;
}



#####################################################################
# Constructor

sub new {
	my $class   = shift;
	my $ide     = Padre->ide;
	my $wizards = $ide->wizards;
	my $self    = bless { id => -1, @_ }, $class;
	my $name    = $self->{name};

	# Save the wizard
	$wizards->{$name} = $self;

	return $self;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

__END__

=pod

=head1 NAME

Padre::Wx::Wizard - Padre Action Object

=head1 SYNOPSIS

  my $wizard = Padre::Wx::Wizard->new(
	name        => 'perl5.script',
	label       => Wx::gettext('Script'),
	category    => Wx::gettext('Perl 5'),
	comment     => Wx::gettext('Opens the Perl 5 script wizard'),
  );

=head1 DESCRIPTION

This is the base class for the Padre Wizard API.

=head1 METHODS

=head2 new

A default constructor for wizard objects.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

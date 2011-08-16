package Padre::Wx::Wizard;

use 5.008;
use strict;
use warnings;
use Padre::Config   ();
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.90';

# Generate faster accessors
use Class::XSAccessor {
	getters => {
		name     => 'name',
		label    => 'label',
		category => 'category',
		comment  => 'comment',
		class    => 'class',
	},
};

=pod

=head1 NAME

Padre::Wx::Wizard - Padre Wizard Object

=head1 SYNOPSIS

  my $wizard = Padre::Wx::Wizard->new(
	name        => 'perl5.script',
	label       => Wx::gettext('Script'),
	category    => Wx::gettext('Perl 5'),
	comment     => Wx::gettext('Opens the Perl 5 script wizard'),
	class       => 'Padre::Wx::Dialog::Wizard::Perl5Script',
  );

=head1 DESCRIPTION

This is the base class for the Padre Wizard API.

=head1 PUBLIC API

=head2 METHODS

=head3 C<new>

A default constructor for wizard objects.

=cut

sub new {
	my $class   = shift;
	my $wizards = Padre->ide->wizards;
	my $self    = bless { id => -1, @_ }, $class;

	# Save the wizard
	$wizards->{ $self->{name} } = $self;

	return $self;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

__END__

=pod

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

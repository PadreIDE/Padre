package Padre::Wx::App;

=pod

=head1 NAME

Padre::Wx::App - Padre main Wx application abstraction

=head1 DESCRIPTION

For architectural clarity, L<Padre> maintains two separate collections
of resources, a Wx object tree representing the literal GUI elements,
and a second tree of objects representing the abstract concepts, such
as configuration, projects, and so on.

Theoretically, this should allow Padre to run automated processes of
various types without having to bootstrap a process up into an entire
30+ megabyte Wx-capable instance.

B<Padre::Wx::App> is a L<Wx::App> subclass that represents the Wx
application as a whole, and acts as the root of the object tree for
the GUI elements.

From the main L<Padre> object, it can be accessed via the C<wx> method.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp ();
use Params::Util qw{ _INSTANCE };
use Padre::Wx ();

our $VERSION = '0.45';
our @ISA     = 'Wx::App';





#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $ide   = shift;
	unless ( _INSTANCE( $ide, 'Padre' ) ) {
		Carp::croak("Did not provide the ide object to Padre::App->new");
	}

	# Create the Wx object
	my $self = $class->SUPER::new;

	# Save a link back to the parent ide
	$self->{ide} = $ide;

	# Immediately populate the main window
	require Padre::Wx::Main;
	$self->{main} = Padre::Wx::Main->new($ide);

	return $self;
}

=pod

=head2 ide

The C<ide> accessor provides a link back to the parent L<Padre> ide object.

=head2 main

The C<main> accessor returns the L<Padre::Wx::Main> object for the
application.

=cut

use Class::XSAccessor getters => {
	ide  => 'ide',
	main => 'main',
};

=pod

=head2 config

The C<config> accessor returns the L<Padre::Config> for the application.

=cut

sub config {
	$_[0]->ide->config;
}





#####################################################################
# Wx Methods

sub OnInit {1}

1;

=pod

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

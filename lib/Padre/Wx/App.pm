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
use Padre::Wx ();

our $VERSION = '0.94';
our @ISA     = 'Wx::App';





#####################################################################
# Constructor and Accessors

sub create {
	my $class = shift;
	my $self  = $class->new;

	# Check we only set up the application once
	if ( $self->{ide} ) {
		die "Cannot instantiate $class multiple times";
	}

	# Save a link back to the IDE object
	$self->{ide} = shift;

	# Immediately build the main window
	require Padre::Wx::Main;
	$self->{main} = Padre::Wx::Main->new( $self->{ide} );

	# Create the action queue
	require Padre::Wx::ActionQueue;
	$self->{queue} = Padre::Wx::ActionQueue->new($self);

	return $self;
}

# Compulsory Wx methods
sub OnInit {
	my $self = shift;

	# Bootstrap some Wx internals
	Wx::Log::SetActiveTarget( Wx::LogStderr->new );

	# Create the PlThreadEvent receiver
	require Padre::Wx::Frame::Null;
	$self->{conduit} = Padre::Wx::Frame::Null->new;
	$self->{conduit}->conduit_init;

	# Return true to continue
	return 1;
}

# Clean up in reverse order
sub OnExit {
	my $self = shift;

	# Action queue
	if ( defined $self->{queue} ) {
		delete $self->{queue};
	}

	# Main window
	if ( defined $self->{main} ) {
		delete $self->{main};
	}

	# PlThreadEvent conduit
	if ( defined $self->{conduit} ) {
		$self->{conduit}->Destroy;
		delete $self->{conduit};
	}

	# IDE object
	if ( defined $self->{ide} ) {
		delete $self->{ide};
	}

	return 1;
}

=pod

=head2 C<ide>

The C<ide> accessor provides a link back to the parent L<Padre> IDE object.

=cut

sub ide {
	$_[0]->{ide};
}

=pod

=head2 C<main>

The C<main> accessor returns the L<Padre::Wx::Main> object for the
application.

=cut

sub main {
	$_[0]->{main};
}

=pod

=head2 C<config>

The C<config> accessor returns the L<Padre::Config> for the application.

=cut

sub config {
	$_[0]->{ide}->config;
}

=pod

=head2 C<queue>

The C<queue> accessor returns the L<Padre::Wx::ActionQueue> for the application.

=cut

sub queue {
	$_[0]->{queue};
}

=pod

=head2 C<conduit>

The C<conduit> accessor returns the L<Padre::Wx::Role::Conduit> for the
application.

=cut

sub conduit {
	$_[0]->{conduit};
}

1;

=pod

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

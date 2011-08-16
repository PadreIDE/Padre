package Padre::Wx::Role::Main;

=pod

=head1 NAME

Padre::Wx::Role::Main - Convenience methods for children of the main window

=head1 DESCRIPTION

This role implements the fairly common method pattern for Wx elements that
are children of L<Padre::Wx::Main>.

It provides accessors for easy access to the most commonly needed elements,
and shortcut integration with the L<Padre::Current> context system.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util   ();
use Padre::Current ();

our $VERSION = '0.90';

=pod

=head2 C<ide>

    my $ide = $object->ide;

Get the L<Padre> IDE instance that this object is a child of.

=cut

sub ide {
	shift->main->ide;
}

=pod

=head2 C<config>

    my $config = $object->config;

Get the L<Padre::Config> for the current user. Provided mainly as a
convenience because it is needed so often.

Please note that this method does NOT integrate with the L<Padre::Current>
context system. Any project-specific configuration of overrides of default
behaviour will not be present in this configuration object.

For a project-aware configuration, use the following instead.

  $self->current->config;

=cut

sub config {
	shift->main->config;
}

=pod

=head2 C<main>

    my $main = $object->main;

Get the L<Padre::Wx::Main> main window that this object is a child of.

=cut

sub main {
	my $main = shift->GetParent;
	while ( not Params::Util::_INSTANCE( $main, 'Padre::Wx::Main' ) ) {
		$main = $main->GetParent or return Padre::Current->main;
	}
	return $main;
}

=pod

=head2 C<aui>

    my $aui = $object->aui;

Convenient access to the Wx Advanced User Interface (AUI) Manager object.

=cut

sub aui {
	shift->main->aui;
}

=pod

=head2 current

    my $current = $object->current;

Get a new C<Padre::Current> context object, for access to other parts of
the current context.

=cut

sub current {
	Padre::Current->new( main => shift->main );
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

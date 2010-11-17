package Padre::Wx::Dialog::WizardPage;

use 5.008;
use strict;
use warnings;

use Padre::Wx ();

our $VERSION = '0.75';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Panel
};

sub new {
	my ( $class, $wizard ) = @_;

	# Creates the panel
	my $self = $class->SUPER::new($wizard);

	# Store the wizard for later usage
	$self->{wizard} = $wizard;

	# The back and next wizards
	$self->{back_wizard} = undef;
	$self->{next_wizard} = undef;

	# status text starts empty
	$self->{status} = '';

	# Add the controls
	$self->add_controls;

	# Add the events
	$self->add_events;

	return $self;
}

=pod
	Returns the wizard page name
=cut

sub get_name {
	return "Wizard Name";
}

=pod
	Returns the wizard page title
=cut

sub get_title {
	return "Wizard Title";
}

=pod
	Adds the controls
=cut

sub add_controls { }

=pod
	Adds the control events
=cut

sub add_events { }

=pod
	Called when the wizard page is going to be shown
=cut

sub show { }

=pod
	Convenience method to set status on the wizard's header
	Called C<refresh> to do the actual update
=cut

sub status {
	$_[0]->{status} = $_[1];
}


sub back_wizard {
	$_[0]->{back_wizard} = $_[1];
}

sub next_wizard {
	$_[0]->{next_wizard} = $_[1];
}

sub refresh {
	$_[0]->{wizard}->refresh;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog::WizardPage - a wizard page

=head1 DESCRIPTION

This prepares the required page UI that the wizard will include in its UI and has the page
flow information for the next and previous pages.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

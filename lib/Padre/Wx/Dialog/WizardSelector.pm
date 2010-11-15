package Padre::Wx::Dialog::WizardSelector;

use 5.008;
use strict;
use warnings;

use Padre::Wx             ();

our $VERSION = '0.75';
our @ISA     = qw{
	Wx::Dialog
};

# Creates the wizard dialog and returns the instance
sub new {
	my ( $class, $parent ) = @_;

	# Create the Wx wizard dialog
	my $self = $class->SUPER::new( $parent, -1, Wx::gettext('Wizard Selector (WARNING: Experimental)') );

	# Minimum dialog size
	$self->SetMinSize( [ 360, 340 ] );

	# Create the controls
	$self->_create_controls;

	# Bind the control events
	$self->_bind_events;

	return $self;
}

# Create dialog controls
sub _create_controls {
	my $self = shift;

	return;
}

# A Private method to binds events to controls
sub _bind_events {
	my $self = shift;


	return;
}

# Shows the wizard dialog
sub show {
	my $self = shift;

	$self->ShowModal;

	return;
}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::WizardSelector - a dialog to filter, select and open wizards

=head1 DESCRIPTION

This dialog lets the user search for a wizard and the open it if needed

=head1 PUBLIC API

=head2 C<new>

  my $wizard_selector = Padre::Wx::Dialog::WizardSelector->new($main);

Returns a new C<Padre::Wx::Dialog::WizardSelector> instance

=head2 C<show>

  $wizard_selector->show($main);

Shows the dialog. Returns C<undef>.

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

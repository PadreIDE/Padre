package Padre::Wx::Dialog::WizardPage;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Panel
};

# Generate faster accessors
use Class::XSAccessor {
	getters => {
		wizard => 'wizard',
	},
	accessors => {
		name        => 'name',
		title       => 'title',
		back_wizard => 'back_wizard',
		next_wizard => 'next_wizard',
		status      => 'status',
	},
};

=pod

=head1 NAME

Padre::Wx::Dialog::WizardPage - a wizard page base class

=head1 DESCRIPTION

This prepares the required page UI that the wizard will include in its UI and
has the page flow information for the next and previous pages.

=pod

=head1 PUBLIC API

=head2 METHODS

=head3 C<new>

Constructs a wizard page and calls C<init>, C<add_controls>, and C<add_events>
Note: Please do NOT override this. use C<init> instead

=cut

sub new {
	my ( $class, $wizard ) = @_;

	# Creates the panel
	my $self = $class->SUPER::new($wizard);

	# Store the wizard for later usage
	$self->{wizard} = $wizard;

	# The dummy wizard page name and title
	$self->name('Dummy Wizard Name');
	$self->title('Dummy Wizard Title');

	# status text starts empty
	$self->status('');

	# Initialize
	$self->init;

	# Add the controls
	$self->add_controls;

	# Add the events
	$self->add_events;

	return $self;
}

=pod

=head3 C<init>

	Initializes the page. All initialization code should reside here.
	Note: You may need to override this method
=cut

sub init { }

=pod

=head3 C<add_controls>

	Adds the controls
	Note: You may need to override this method
=cut

sub add_controls { }

=pod

=head3 C<add_events>

	Adds the control events
	Note: You may need to override this method
=cut

sub add_events { }

=pod

=head3 C<show>

	Called when the wizard page is going to be shown
	Note: You may need to override this method

=cut

sub show { }

=pod

=head3 C<refresh>

	Convenience method to set refresh the wizard

=cut

sub refresh {
	$_[0]->wizard->refresh;
}

1;

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

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Dialog::Preferences2;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::Preferences2 ();

our $VERSION = '0.85';
our @ISA     = 'Padre::Wx::FBP::Preferences2';





######################################################################
# Constructor and Accessors





#####################################################################
# Load and Save

sub load {
	my $self   = shift;
	my $config = shift;

	# Iterate over the configuration entries and apply the
	# configuration state to the dialog.
	foreach my $name ( $config->settings ) {
		next unless $self->can($name);

		# Get the Wx element for this option
		my $value  = $config->$name();
		my $widget = $self->$name();

		# Apply this one setting to this one widget
		if ( $widget->isa('Wx::Checkbox') ) {
			$widget->SetValue( $value ? 1 : 0 );
		} else {
			next;
		}
	}

	return 1;
}

sub save {
	my $self   = shift;
	my $config = shift;

	die "CODE INCOMPLETE";
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


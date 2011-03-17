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
		my $setting = $config->meta($name);
		my $value   = $config->$name();
		my $ctrl    = $self->$name();

		# Apply this one setting to this one widget
		if ( $ctrl->isa('Wx::CheckBox') ) {
			$ctrl->SetValue($value);

		} elsif ( $ctrl->isa('Wx::TextCtrl') ) {
			$ctrl->SetValue($value);

		} elsif ( $ctrl->isa('Wx::SpinCtrl') ) {
			$ctrl->SetValue($value);

		} elsif ( $ctrl->isa('Wx::Choice') ) {
			my $options = $setting->options;
			if ($options) {
				$ctrl->Clear;
				foreach my $option ( sort keys %$options ) {

					# NOTE: Probably wrong
					my $i = $ctrl->Append($option);
					next unless $option eq $value;
					$ctrl->SetSelection($i);
				}
			}


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

sub diff {
	my $self   = shift;
	my $config = shift;
	my %diff   = ();

	# Iterate over the configuration entries and apply the
	# configuration state to the dialog.
	foreach my $name ( $config->settings ) {
		next unless $self->can($name);

		# Get the Wx element for this option
		my $setting = $config->meta($name);
		my $current = $config->$name();
		my $ctrl    = $self->$name();

		# Extract the value from the control
		my $value = undef;
		if ( $ctrl->isa('Wx::CheckBox') ) {
			$value = $ctrl->GetValue ? 1 : 0;

		} elsif ( $ctrl->isa('Wx::TextCtrl') ) {
			$value = $ctrl->GetValue;

		} elsif ( $ctrl->isa('Wx::SpinCtrl') ) {
			$value = $ctrl->GetValue;

		} elsif ( $ctrl->isa('Wx::Choice') ) {
			my $options = $setting->options;
			if ($options) {
				my @k = sort keys %$options;
				my $i = $ctrl->GetSelection;
				$value = $k[$i];
			}
		} else {
			# To be completed
		}

		# Skip if null
		next unless defined $value;
		next if $value eq $current;
		$diff{$name} = $value;
	}

	return \%diff;
}





######################################################################
# Event Handlers

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


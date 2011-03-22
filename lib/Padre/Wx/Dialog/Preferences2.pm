package Padre::Wx::Dialog::Preferences2;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::Preferences2 ();

our $VERSION = '0.85';
our @ISA     = 'Padre::Wx::FBP::Preferences2';





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

					# NOTE: This assumes that the list will
					# not be sorted in Wx via a style flag.
					$ctrl->Append( $option, $option );
					next unless $option eq $value;
					$ctrl->SetSelection( $ctrl->GetCount - 1 );
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

	# Apply the changes to the configuration, if any
	my $diff    = $self->diff($config) or return;
	my $current = $self->current;
	foreach my $name ( sort keys %$diff ) {
		$config->apply( $name, $diff->{$name}, $current );
	}

	# Save the config file
	$config->write;

	return;
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

		# Don't capture options that are not shown,
		# as this may result in falsely clearing them.
		next unless $ctrl->IsEnabled;

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

	return unless %diff;
	return \%diff;
}





######################################################################
# Event Handlers

sub advanced {
	my $self = shift;

	# Cancel the preferences dialog since it is not needed
	$self->EndModal(Wx::wxID_CANCEL);

	# Show the advanced settings dialog instead
	require Padre::Wx::Dialog::Advanced;
	my $advanced = Padre::Wx::Dialog::Advanced->new( $self->main );
	my $ret      = $advanced->show;

	return;
}

sub guess {
	my $self     = shift;
	my $document = Padre::Current->document or return;
	my $indent   = $document->guess_indentation_style;

	$self->editor_indent_tab->SetValue( $indent->{use_tabs} );
	$self->editor_indent_tab_width->SetValue( $indent->{tabwidth} );
	$self->editor_indent_width->SetValue( $indent->{indentwidth} );

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


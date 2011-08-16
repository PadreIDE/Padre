package Padre::Wx::Role::Config;

# This role provides function for dialogs that load display elements from,
# or save from display elements to, the Padre configuration.

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.90';

sub config_load {
	my $self   = shift;
	my $config = shift;

	# Iterate over the specified config elements
	foreach my $name (@_) {
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

		} elsif ( $ctrl->isa('Wx::ColourPickerCtrl') ) {
			$ctrl->SetColour( Padre::Wx::color($value) );

		} elsif ( $ctrl->isa('Wx::FontPickerCtrl') ) {
			my $font = Wx::Font->new(Wx::wxNullFont);
			local $@;
			eval { $font->SetNativeFontInfoUserDesc($value); };
			$font = Wx::Font->new(Wx::wxNullFont) if $@;

			# SetSelectedFont(wxNullFont) doesn't work on
			# Linux, so we only do it if the font is valid
			$ctrl->SetSelectedFont($font) if $font->IsOk;

		} elsif ( $ctrl->isa('Wx::Choice') ) {
			my $options = $setting->options;
			if ($options) {
				$ctrl->Clear;

				# NOTE: This assumes that the list will not be
				# sorted in Wx via a style flag and that the
				# order of the fields should be that of the key
				# and not of the translated label.
				# Doing sort in Wx will probably break this.
				foreach my $option ( sort keys %$options ) {
					my $label = $options->{$option};
					$ctrl->Append(
						Wx::gettext($label),
						$option,
					);
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

sub config_save {
	my $self    = shift;
	my $config  = shift;
	my $current = $self->current;

	# Find the changes we need to save, if any
	my $diff = $self->config_diff( $config, @_ ) or return;

	# Lock most of Padre so any apply handlers run quickly
	my $lock = $self->main->lock( 'UPDATE', 'REFRESH', 'DB' );

	# Apply the changes to the configuration
	foreach my $name ( sort keys %$diff ) {
		$config->apply( $name, $diff->{$name}, $current );
	}

	# Save the config file
	$config->write;

	return;
}

sub config_diff {
	my $self   = shift;
	my $config = shift;
	my %diff   = ();

	foreach my $name (@_) {
		next unless $self->can($name);

		# Get the Wx element for this option
		my $setting = $config->meta($name);
		my $old     = $config->$name();
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

		} elsif ( $ctrl->isa('Wx::ColourPickerCtrl') ) {
			$value = $ctrl->GetColour->GetAsString(Wx::wxC2S_HTML_SYNTAX);
			$value =~ s/^#// if defined $value;

		} elsif ( $ctrl->isa('Wx::FontPickerCtrl') ) {
			$value = $ctrl->GetSelectedFont->GetNativeFontInfoUserDesc;

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
		next if $value eq $old;
		$diff{$name} = $value;
	}

	return unless %diff;
	return \%diff;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


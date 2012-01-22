package Padre::Wx::Role::Config;

# This role provides function for dialogs that load display elements from,
# or save from display elements to, the Padre configuration.

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.94';

sub config_load {
	my $self   = shift;
	my $config = shift;

	foreach my $name (@_) {
		my $meta  = $config->meta($name);
		my $value = $config->$name();
		$self->config_set( $meta => $value );
	}

	return 1;
}

sub config_set {
	my $self  = shift;
	my $meta  = shift;
	my $value = shift;
	my $name  = $meta->name;

	# Ignore config elements we don't have
	unless ( $self->can($name) ) {
		return undef;
	}

	# Apply to the relevant element
	my $ctrl = $self->$name();
	if ( $ctrl->can('config_set') ) {
		# Allow specialised widgets to load their own setting
		$ctrl->config_set( $meta, $value );

	} elsif ( $ctrl->isa('Wx::CheckBox') ) {
		$ctrl->SetValue($value);

	} elsif ( $ctrl->isa('Wx::TextCtrl') ) {
		$ctrl->SetValue($value);

	} elsif ( $ctrl->isa('Wx::SpinCtrl') ) {
		$ctrl->SetValue($value);

	} elsif ( $ctrl->isa('Wx::FilePickerCtrl') ) {
		$ctrl->SetPath($value);

	} elsif ( $ctrl->isa('Wx::DirPickerCtrl') ) {
		$ctrl->SetPath($value);

	} elsif ( $ctrl->isa('Wx::ColourPickerCtrl') ) {
		$ctrl->SetColour( 
			Padre::Wx::color($value)
		);

	} elsif ( $ctrl->isa('Wx::FontPickerCtrl') ) {
		my $font = Padre::Wx::native_font($value);
		$ctrl->SetSelectedFont($font) if $font->IsOk;

	} elsif ( $ctrl->isa('Wx::Choice') ) {
		my $options = $meta->options;
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
		return 0;
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
	my $lock = $self->main->lock( qw{ UPDATE REFRESH AUI CONFIG DB } );

	# Apply the changes to the configuration
	foreach my $name ( sort keys %$diff ) {
		$config->apply( $name, $diff->{$name}, $current );
	}

	return;
}

sub config_diff {
	my $self   = shift;
	my $config = shift;
	my %diff   = ();

	foreach my $name (@_) {
		my $meta = $config->meta($name);

		# Can we get a value from the control
		my $new = $self->config_get($meta);
		next unless defined $new;

		# Change the setting if different
		unless ( $new eq $config->$name() ) {
			$diff{$name} = $new;
		}
	}

	return unless %diff;
	return \%diff;
}

sub config_get {
	my $self = shift;
	my $meta = shift;
	my $name = $meta->name;

	# Ignore config elements we don't have
	unless ( $self->can($name) ) {
		return undef;
	}

	# Ignore controls that are disabled
	my $ctrl = $self->$name();
	unless ( $ctrl->IsEnabled ) {
		return undef;
	}

	# Extract the value from the control
	my $value = undef;
	if ( $ctrl->isa('Wx::CheckBox') ) {
		$value = $ctrl->GetValue ? 1 : 0;

	} elsif ( $ctrl->isa('Wx::TextCtrl') ) {
		$value = $ctrl->GetValue;

	} elsif ( $ctrl->isa('Wx::SpinCtrl') ) {
		$value = $ctrl->GetValue;

	} elsif ( $ctrl->isa('Wx::FilePickerCtrl') ) {
		$value = $ctrl->GetPath;

	} elsif ( $ctrl->isa('Wx::DirPickerCtrl') ) {
		$value = $ctrl->GetPath;

	} elsif ( $ctrl->isa('Wx::ColourPickerCtrl') ) {
		$value = $ctrl->GetColour->GetAsString(Wx::C2S_HTML_SYNTAX);
		$value =~ s/^#// if defined $value;

	} elsif ( $ctrl->isa('Wx::FontPickerCtrl') ) {
		$value = $ctrl->GetSelectedFont->GetNativeFontInfoUserDesc;

	} elsif ( $ctrl->isa('Wx::Choice') ) {
		my $options = $meta->options;
		if ($options) {
			my @k = sort keys %$options;
			my $i = $ctrl->GetSelection;
			$value = $k[$i];
		}
	}
	unless ( defined $value ) {
		return undef;
	}

	# For various strictly formatted configuration values,
	# attempt to determine a clean version.
	my $type = $meta->type;
	if ( $type == Padre::Constant::POSINT ) {
		$value =~ s/[^0-9]//g;
		$value =~ s/^0+//;
		if ( Params::Util::_POSINT($value) ) {
			return $value;
		}

		# Fall back to the setting default
		return $meta->default;

	} else {
		# Implement cleaning for many more data types

	}

	return $value;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


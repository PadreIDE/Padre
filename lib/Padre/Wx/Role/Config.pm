package Padre::Wx::Role::Config;

=pod

=head1 NAME

Padre::Wx::Role::Config - Role for Wx forms that control preference data

=head1 DESCRIPTION

B<Padre::Wx::Role::Config> is a role for dialogs and form panels that
enables the load and saving of configuration data in a standard manner.

It was originally created to power the main Preferences dialog, but can be
reused by any dialog of panel that wants to load preference entries and
allow them to be changed.

To use this role, create a dialog or panel which has public getter methods
for the preference form elements. The public getter method must exactly
match the name of the preference method you wish to load.

For example, the following demonstrates a text box that can load and save
the identify of the Padre user.

    # In your constructor, create the text control
    $self->{identity_name} = Wx::TextCtrl->new(
        $self,
	-1,
	"",
	Wx::DefaultPosition,
	Wx::DefaultSize,
    );
    
    # Later in the module, create a public getter for the control
    sub identity_name {
        $_[0]->{identity_name};
    }

Once your public form controls have been set up, the preference information
is loaded from configuration by the C<config_load> method and then the
C<config_save> method is used to apply the changes to the active Padre
instance and save the changes to configuration.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.93';

=pod

=head2 config_load

    $dialog->config_load(
        Padre::Current->config,
        qw{
            identity_name
            identity_nick
            identity_email
        }
    );

The C<config_load> method loads preference information from configuration
into the public form controls for the current object.

The first parameter to C<config_load> should be a valid L<Padre::Config>
object to load from (usually the main or current configuration object).

After the configuration object you should provide a list of preferences
names that should be loaded.

Returns the number of configuration form controls that were successfully
loaded, which should match the number of names you passed in.

=cut

sub config_load {
	my $self   = shift;
	my $config = shift;
	my $loaded = 0;

	foreach my $name (@_) {
		my $meta  = $config->meta($name);
		my $value = $config->$name();
		$self->config_set( $meta => $value ) or next;
		$loaded++;
	}

	return $loaded;
}

=pod

=head2 config_save

    $dialog->config_save(
        Padre::Current->config,
        qw{
            identity_name
            identity_nick
            identity_email
        }
    );

The C<config_save> method saves preference information from public form
controls into configuration, applying the changes to the current Padre
instance as it does so.

The first parameter to C<config_load> should be a valid L<Padre::Config>
object to load from (usually the main or current configuration object).

After the configuration object you should provide a list of preferences
names that should be loaded.

The changes are applied inside of a complete L<Padre::Lock> of all possible
subsystems and GUI lock modes to ensure that changes apply as a single fast
visual change, and will not cause weird flickering of the user interface.

Returns the number of changes that were made to configuration, which may be
zero if all config fields match the current values. No lock will be taken
in the case where the number of config changes to make is zero.

=cut

sub config_save {
	my $self    = shift;
	my $config  = shift;
	my $current = $self->current;

	# Find the changes we need to save, if any
	my $diff = $self->config_diff( $config, @_ ) or return 0;

	# Lock most of Padre so any apply handlers run quickly
	my $lock = $self->main->lock(qw{ UPDATE REFRESH AUI CONFIG DB });

	# Apply the changes to the configuration
	foreach my $name ( sort keys %$diff ) {
		$config->apply( $name, $diff->{$name}, $current );
	}

	return scalar keys %$diff;
}

=pod

=head2 config_diff

    $dialog->config_diff(
        Padre::Current->config,
        qw{
            identity_name
            identity_nick
            identity_email
        }
    );

The C<config_diff> method calculates changes to preference information from
the public form controls, but does not save or apply them.

The first parameter to C<config_load> should be a valid L<Padre::Config>
object to load from (usually the main or current configuration object).

After the configuration object you should provide a list of preferences
names that should be loaded.

Since the C<config_diff> method is used by C<config_save> to find the list
of changes to make, overloading C<config_diff> with custom functionality
will also result in this custom behaviour being used when saving the changes
for real.

Returns a reference to a C<HASH> containing a set of name/value pairs of
the new values to be applied to configuration, or C<undef> if there are no
changes to configuration.

=cut

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

	return undef unless %diff;
	return \%diff;
}

=pod

=head2 config_get

    $dialog->config_get(
        Padre::Current->config->meta('identity_name')
    );

The C<config_get> method fetches a single configuration value form a the
public dialog control.

It takes a single parameter, which should be the L<Padre::Config::Setting>
metadata object for the configuration preference to fetch.

Successfully getting a value is by no means certain, there can be a number
of different reasons why no value may be returned. These include:

=over

=item The lack of a public getter method for the form control

=item The form control being disabled (i.e. not $control->IsEnabled)

=item The form control returning C<undef> (which native Wx controls won't)

=item The form control being incompatible with the config data type

=back

Returns a simple defined scalar value suitable for being passed
L<Padre::Config/set> on success, or C<undef> if no value can be found.

=cut

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

=pod

=head2 config_set

    $dialog->config_set(
        Padre::Current->config->meta('identity_name'),
        'My Name',
    );

The C<config_set> method applies a simple scalar value to a form control.

It takes two parameters, a L<Padre::Config::Setting> metadata object for
the configuration preference to load, and a value to load into the form
control.

Returns true if the value was loaded into the form control, false if the
form control was unknown or not compatible with the preference, or
C<undef> if the form control does not exist at all in the dialog.

=cut

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
		$ctrl->SetColour( Padre::Wx::color($value) );

	} elsif ( $ctrl->isa('Wx::FontPickerCtrl') ) {
		my $font = Padre::Wx::native_font($value);
		return 0 unless $font->IsOk;
		$ctrl->SetSelectedFont($font);

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

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

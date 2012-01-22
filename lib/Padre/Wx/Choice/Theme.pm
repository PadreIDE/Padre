package Padre::Wx::Choice::Theme;

# Theme selection choice box

use 5.008;
use strict;
use warnings;
use Padre::Locale         ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();
use Padre::Wx::Theme      ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Choice
};

# Provide a custom config_load hook so that Padre::Wx::Role::Config will let
# let us load our own data instead of doing it for us.

sub config_set {
	my $self    = shift;
	my $setting = shift;
	my $value   = shift;

	# Instead of using the vanilla options provided by configuration,
	# use the elevated ones provided by the theme engine.
	my $locale  = Padre::Locale::rfc4646();
	my $options = Padre::Wx::Theme->labels($locale);
	if ($options) {
		$self->Clear;

		# NOTE: This assumes that the list will not be
		# sorted in Wx via a style flag and that the
		# order of the fields should be that of the key
		# and not of the translated label.
		# Doing sort in Wx will probably break this.
		foreach my $option ( sort keys %$options ) {
			# Don't localise the label as Padre::Wx::Theme will do
			# the localisation for us in this special case.
			my $label = $options->{$option};
			$self->Append( $label => $option );
			next unless $option eq $value;
			$self->SetSelection( $self->GetCount - 1 );
		}
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

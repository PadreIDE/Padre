package Padre::Wx::Role::Form;

use 5.008005;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.94';

sub form {
	my $self = shift;

	# The list of fields to read
	my @names = @_;
	unless (@names) {
		@names =
			grep { $_->isa('Wx::Control') and not $_->isa('Wx::Button') } sort keys %$self;
	}

	# Read the values from the named controls
	my %hash = ();
	foreach my $name (@names) {
		my $control = $self->{$name};
		if ( $control->can('GetValue') ) {
			$hash{$name} = $control->GetValue;
		} elsif ( $control->can('GetPath') ) {
			$hash{$name} = $control->GetPath;
		} elsif ( $control->isa('Wx::Choice') ) {
			$hash{$name} = $control->GetSelection;
		} elsif ( $control->isa('Wx::ColourPickerControl') ) {
			$hash{$name} = $control->GetColour->GetAsString(Wx::C2S_HTML_SYNTAX);
		} elsif ( $control->isa('Wx::FontPickerControl') ) {
			$hash{$name} = $control->GetSelectedFont->GetNativeFontInfoUserDesc;
		} else {
			die "Unknown or unsupported control class " . ref($control);
		}
	}

	return \%hash;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Menu;

# Implements additional functionality to support richer menus

use strict;
use warnings;
use Padre::Wx ();

use Class::Adapter::Builder
	ISA      => 'Wx::Menu',
	NEW      => 'Wx::Menu',
	AUTOLOAD => 'PUBLIC';

our $VERSION = '0.41';

use Class::XSAccessor getters => {
	wx => 'OBJECT',
};

# Default implementation of refresh

sub refresh {1}

# Overrides and then calls XS wx Menu::Append.
# Adds any hotkeys to global registry of bound keys

sub Append {
	my $self   = shift;
	my $string = $_[1];
	my $item   = $self->wx->Append(@_);
	my ($underlined) = ( $string =~ m/(\&\w)/ );
	my ($accel)      = ( $string =~ m/(Ctrl-.+|Alt-.+)/ );
	if ( $underlined or $accel ) {
		$self->{main}->{accel_keys} ||= {};
		if ($underlined) {
			$underlined =~ s/&(\w)/$1/;
			$self->{main}->{accel_keys}->{underlined}->{$underlined} = $item;
		}
		if ($accel) {
			my ( $mod, $mod2, $key ) = ( $accel =~ m/(Ctrl|Alt)(-Shift)?\-(.)/ );
			$mod .= $mod2 if ($mod2);
			$self->{main}->{accel_keys}->{hotkeys}->{ uc($mod) }->{ ord( uc($key) ) } = $item;
		}
	}
	return $item;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

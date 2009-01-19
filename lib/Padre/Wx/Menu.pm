package Padre::Wx::Menu;

# Implements additional functionality to support richer menus

use strict;
use warnings;
use Padre::Wx ();

use Data::Dumper;

use Class::Adapter::Builder
	ISA      => 'Wx::Menu',
	NEW      => 'Wx::Menu',
	AUTOLOAD => 'PUBLIC';

our $VERSION = '0.25';

use Class::XSAccessor
	getters => {
		wx => 'OBJECT',
	};

# Default implementation of refresh

sub refresh { 1 }

# over-rides and then calls XS wx Menu::Append
# adds any hotkeys to global registry of bound keys

sub Append {
    my ($self, @args) = (shift, @_);
    my $item = $self->wx->Append( @_ );
    my $string = $args[1];
    my ($underlined) = ( $string =~ m/(\&\w)/ );
    my ($accel) = ( $string =~ m/(Ctrl-.+|Alt-.+)/ );
    if ($underlined or $accel) {
	$self->{main}{accel_keys} ||= {};
	if ($underlined) {
	    $underlined =~ s/&(\w)/$1/;
	    $self->{main}{accel_keys}{underlined}{$underlined} = $item;
	}
	if ($accel) {
	    my ($mod, $mod2, $key) = ( $accel =~ m/(Ctrl|Alt)(-Shift)?\-(.)/);#
	    $mod .= $mod2 if ($mod2);
	    $self->{main}{accel_keys}{hotkeys}{uc($mod)}{ord(uc($key))} = $item;
	}
    }
    return $item;
}



1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

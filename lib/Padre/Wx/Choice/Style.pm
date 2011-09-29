package Padre::Wx::Choice::Style;

# Since styles contain their localised names internally, the normal
# auto-translating mechanism won't work properly.
#
# This class provides a custom dropbox that will load the localised
# style names correctly instead of using the wrong names.

use 5.008;
use strict;
use warnings;
use Padre::Wx        ();
use Padre::Wx::Style ();

our $VERSION = '0.91';
our @ISA     = 'Wx::Choice';

sub config_load {
	my $self    = shift;
	my $setting = shift;
	my $value   = shift;

}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

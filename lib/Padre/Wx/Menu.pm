package Padre::Wx::Menu;

# Implements additional functionality to support richer menus

use strict;
use warnings;
use Padre::Wx ();

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

1;
# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

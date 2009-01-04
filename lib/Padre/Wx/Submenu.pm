package Padre::Wx::Submenu;

# Implements additional functionality to support richer submenus

use strict;

use Class::Adapter::Builder
	ISA      => 'Wx::Menu',
	NEW      => 'Wx::Menu',
	AUTOLOAD => 'PUBLIC';

our $VERSION = '0.23';

use Class::XSAccessor
	getters => {
		wx => 'OBJECT',
	};

# Default implementation of refresh
sub refresh { 1 }

1;

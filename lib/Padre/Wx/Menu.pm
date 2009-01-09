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

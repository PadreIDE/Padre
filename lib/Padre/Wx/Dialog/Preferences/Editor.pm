package Padre::Wx::Dialog::Preferences::Editor;

use 5.008;
use strict;
use warnings;

use Padre::Wx::Editor;

our $VERSION = '0.44';
our @ISA     = 'Padre::Wx::Editor';

sub main {
	my $window = shift;
	while ( $window and not $window->isa('Padre::Wx::Main') ) {
		$window = $window->GetParent;
	}
	return $window;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

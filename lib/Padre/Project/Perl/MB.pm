package Padre::Project::Perl::MB;

# Perl project driven by Module::Build

use 5.008005;
use strict;
use warnings;
use Padre::Project::Perl ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Project::Perl';

use Class::XSAccessor {
	getters => {
		build_pl => 'build_pl',
	}
};

1;

__END__

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

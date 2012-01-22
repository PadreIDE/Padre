package Padre::Project::Temp;

# Project-specific private temporary directory.
# This mechanism will allow us to pull off some really neat tricks,
# like executing unsaved files and syntax-checking changed files
# before they are saved.

use 5.008005;
use strict;
use warnings;
use File::Temp ();

our $VERSION = '0.94';

use Class::XSAccessor {
	getters => {
		root => 'root',
	}
};





######################################################################
# Constructor

sub new {
	bless { root => File::Temp::tempdir( CLEANUP => 1 ) }, $_[0];
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

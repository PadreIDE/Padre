package Padre::Util::Win32;

=pod

=head1 NAME

Padre::Util::Win32 - Padre Win32 Utility Functions

=head1 DESCRIPTION

The Padre::Util::Win32 package is a internal storage area for miscellaneous
functions that aren't really Padre-specific that we want to throw
somewhere convenient so they won't clog up task-specific packages.

All functions are exportable and documented for maintenance purposes,
but except for in the L<Padre> core distribution you are discouraged in the
strongest possible terms from using these functions, as they may be
moved, removed or changed at any time without notice.

=head1 FUNCTIONS

=cut

use 5.008;
use strict;
use warnings;
use Win32::API;

our $VERSION   = '0.46';
our @ISA       = 'Exporter';
our @EXPORT_OK = qw{ };

1;

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

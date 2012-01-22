package Padre::PPI::Transform;

=pod

=head1 NAME

Padre::PPI::Transform - PPI::Transform integration with Padre

=head1 DESCRIPTION

B<Padre::PPI::Transform> is a clear subclass of L<PPI::Transform> which
adds C<apply> integration with L<PPI::Document> objects.

It otherwise adds no significant functionality.

You should inherit transform objects from this class instead of directly
from L<PPI::Transform> to ensure that this L<PPI::Document> support is
fully initialised.

=cut

use 5.008;
use strict;
use warnings;
use PPI::Transform ();

our $VERSION = '0.94';
our @ISA     = 'PPI::Transform';

__PACKAGE__->register_apply_handler(
	'Padre::Document::Perl',
	sub {
		my $padre = shift;
		my $ppi   = $padre->ppi_get;
		return $ppi;
	},
	sub {
		my $padre = shift;
		my $ppi   = shift;
		$padre->ppi_set($ppi);
		return 1;
	},
);

1;

=pod

=head1 SEE ALSO

L<PPI::Transform>

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

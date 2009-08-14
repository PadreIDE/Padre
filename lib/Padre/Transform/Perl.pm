package Padre::Transform::Perl;

# Base class for Perl document transforms

use 5.008;
use strict;
use warnings;
use Padre::Transform ();

our $VERSION = '0.43';
our @ISA     = 'Padre::Transform';

sub apply {
	my $self = shift;
	my $document = _INSTANCE( shift, 'Padre::Document::Perl' );
	unless ($document) {
		die('Did not provide a Padre::Document::Perl object to apply');
	}

	# Parse out the PPI document
	my $ppi = $document->ppi_get;
	my $rv  = $self->document($ppi);
	if ($rv) {
		$document->ppi_set;
	}

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

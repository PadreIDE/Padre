package Padre::Documents;

use 5.008;
use strict;
use warnings;
use Padre::Current ();

our $VERSION = '0.22';

=head1 NAME

Padre::Documents

=head1 SYNOPSIS

Currently there are only class methods in this class.

=head1 METHODS

=cut

sub by_id {
	my $class   = shift;
	my $pageid  = shift;

	# TODO maybe report some error?
	return if not defined $pageid or $pageid =~ /\D/;

	if ( $pageid == -1 ) {
		# No page selected
		return;
	}

	my $notebook = Padre::Current->_notebook;
	return if $pageid >= $notebook->GetPageCount;

	my $page = $notebook->GetPage( $pageid );

	return $page->{Document};
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

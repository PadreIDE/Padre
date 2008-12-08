package Padre::Documents;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.20';

=head1 NAME

Padre::Documents

=head1 SYNOPSIS

Currently there are only class methods in this class.

=head1 METHODS

=cut

sub current {
	$_[0]->by_id( $_[0]->_notebook->GetSelection );
}

sub by_id {
	my $class   = shift;
	my $pageid  = shift;

	# TODO maybe report some error?
	return if not defined $pageid or $pageid =~ /\D/;

	if ( $pageid == -1 ) {
		# No page selected
		return;
	}

	return if $pageid >= $class->_notebook->GetPageCount;

	my $page = $class->_notebook->GetPage( $pageid );

	return $page->{Document};
}


sub _notebook {
	Padre->ide->wx->main_window->nb;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

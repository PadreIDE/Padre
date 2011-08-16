package Padre::Wx::TreeCtrl;

# A general use TreeCtrl that adds a variety of convenience methods

use 5.008;
use strict;
use warnings;
use Padre::Wx                       ();
use Padre::Wx::TreeCtrl::ScrollLock ();

our $VERSION = '0.90';
our @ISA     = 'Wx::TreeCtrl';





######################################################################
# ScrollLock Integration

sub scroll_lock {
	Padre::Wx::TreeCtrl::ScrollLock->new( $_[0] );
}





######################################################################
# Expanded Wx-like Methods

# Iterate through the children to find one with specific text.
# Return undef if no child with that text exists.
sub GetChildByText {
	my $self = shift;
	my $item = shift;
	my $text = shift;

	# Start with the first child
	my ( $child, $cookie ) = $self->GetFirstChild($item);

	while ($cookie) {

		# Is the current child the one we want?
		if ( $self->GetItemText($child) eq $text ) {
			return $child;
		}

		# Get the next child if there is one
		( $child, $cookie ) = $self->GetNextChild( $item, $cookie );
	}

	# Either no children, or no more children
	return undef;
}

# Fetch a list of all Perl data elements for all nodes
# in depth-first top-to-bottom order.
sub GetChildrenPlData {
	my $self  = shift;
	my @queue = $self->GetRootItem;
	my @data  = ();
	while (@queue) {
		my $item = shift @queue;
		push @data, $self->GetPlData($item);

		# Processing children last to first and unshifting onto the
		# queue, lets us achieve depth-first top-down within the need
		# for intermediate storage or grepping.
		my $child = $self->GetLastChild($item);
		while ( $child->IsOk ) {
			unshift @queue, $child;
			$child = $self->GetPrevSibling($child);
		}
	}

	return \@data;
}

# Fetch a list of the Perl data elements for expanded nodes
# in depth-first top to bottom order.
sub GetExpandedPlData {
	my $self  = shift;
	my @queue = $self->GetRootItem;
	my @data  = ();
	while (@queue) {
		my $item = shift @queue;
		push @data, $self->GetPlData($item);

		# Processing children last to first and unshifting onto the
		# queue, lets us achieve depth-first top-down within the need
		# for intermediate storage or grepping.
		my $child = $self->GetLastChild($item);
		while ( $child->IsOk ) {
			if ( $self->IsExpanded($child) ) {
				unshift @queue, $child;
			}
			$child = $self->GetPrevSibling($child);
		}
	}

	return \@data;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

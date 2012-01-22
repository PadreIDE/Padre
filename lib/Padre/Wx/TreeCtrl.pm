package Padre::Wx::TreeCtrl;

=pod

=head1 NAME

Padre::Wx::TreeCtrl - A Wx::TreeCtrl with various extra convenience methods

=head1 DESCRIPTION

B<Padre::Wx::TreeCtrl> is a direct subclass of L<Wx::TreeCtrl> with a
handful of additional methods that make life easier when writing GUI
components for Padre that use trees.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::ScrollLock ();

our $VERSION = '0.94';
our @ISA     = 'Wx::TreeCtrl';





######################################################################
# ScrollLock Integration

=pod

=head2 lock_scroll

  SCOPE: {
      my $lock = $tree->lock_scroll;
  
      # Apply changes to the tree
  }

When making changes to L<Wx::TreeCtrl> objects, many changes to the tree
structure also include an implicit movement of the scroll position to
focus on the node that was changed.

When generating changes to trees that are not the immediate focus of the
user this can be extremely flickery and disconcerting, especially when
generating entire large trees.

The C<lock_scroll> method creates a guard object which combines an update
lock with a record of the scroll position of the tree.

When the object is destroyed, the scroll position of the tree is returned
to the original position immediately before the update lock is released.

The effect is that the tree has changed silently, with the scroll position
remaining unchanged.

=cut

sub lock_scroll {
	Padre::Wx::ScrollLock->new( $_[0] );
}





######################################################################
# Expanded Wx-like Methods

=pod

=head2 GetChildByText

  my $item = $tree->GetChildByText("Foo");

The C<GetChildByText> method is a convenience method for searching through
a tree to find a specific item based on the item text of the child.

It returns the item ID of the first node containing the search text or
C<undef> if no element in the tree contains the search text.

=cut

sub GetChildByText {
	my $self = shift;
	my $item = shift;
	my $text = shift;

	# Start with the first child
	my ( $child, $cookie ) = $self->GetFirstChild($item);

	while ( $child->IsOk ) {

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

=pod

=head2 GetChildrenPlData

  my @data = $tree->GetChildrenPlData;

The C<GetChildrenPlData> method fetches a list of Perl data elements
(via C<GetPlData>) for B<all> nodes in the tree.

The list is returned based on a depth-first top-down node order.

=cut

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

=pod

=head2 GetExpandedPlData

  my @data = $tree->GetExpandedPlData;

The C<GetExpandedPlData> method is a variation of the C<GetChildrenPlData>
method. It returns a list of Perl data elements in depth-first top-down node
order, but only for nodes which are expanded (via C<IsExpanded>).

=cut

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

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

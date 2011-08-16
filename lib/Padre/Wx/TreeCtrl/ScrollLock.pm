package Padre::Wx::TreeCtrl::ScrollLock;

=pod

=head1 NAME

Padre::Wx::TreeCtrl::ScrollLock - Scroll-free transactions for tree controls

=head1 SYNOPSIS

  SCOPE: {
      my $lock = $padre_wx_treectrl->scroll_lock;
  
      # Change the tree here
  }
  
  # The tree will unlock before here

=head1 DESCRIPTION

Ny default a Wx TreeCtrl object will auto-scroll to the location of an
expand event or similar actions, as if it had been triggered by a human.

For trees which are supposed to expanding or moving around on their own,
this looks quite bizarre.

This class provides an implementation of a "scroll lock" for short-lived
sections of fully self-contained code that will be updating the structure
of a tree control.

When created, the lock will create a Wx update locker for speed and flicker
free changes to the tree. It will additionally remember the current scroll
position of the tree.

When destroyed, the lock will move the scroll position back to the original
location if it has been changed in the process of an operation and then
release the update lock.

The result is that all operations on the tree should occur with the
tree appearing to stay fixed in place.

Note that the lock MUST be short-lived, as it does not integrate with
the rest of Padre's locking system. You should already have all the data
needed to change the tree prepared and ready to go before you create the
tree lock.

=cut

use 5.008;
use strict;
use warnings;
use Params::Util ();
use Padre::Wx    ();

our $VERSION = '0.90';

sub new {
	my $class = shift;
	my $tree  = shift;
	unless ( Params::Util::_INSTANCE( $tree, 'Wx::TreeCtrl' ) ) {
		die "Did not provide a Wx::TreeCtrl to lock";
	}

	# Create the object and record the scroll position
	return bless {
		tree    => $tree,
		scrolly => $tree->GetScrollPos(Wx::wxVERTICAL),
		locker  => Wx::WindowUpdateLocker->new($tree),
	}, $class;
}

sub DESTROY {

	# Return the scroll position to the previous position
	### NOTE: This just sets it to the top for now.
	$_[0]->{tree}->SetScrollPos(
		Wx::wxVERTICAL,
		$_[0]->{scrolly},
		0,
	);

	# We don't need to explicitly release the Wx lock, it will be
	# deleted (and thus have it's own DESTROY logic fire) during
	# hash cleanup after this method completes.
}

1;

=pod

=head1 TODO

Find a way to prevent scrolling in native Wx and remove this class
entirely. This whole exercise feels like a bit of a waste of time,
because it emulates a more simple behaviour out of complex behaviour
just because we can't disable the complex behaviour.

=head1 COPYRIGHT

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::ScrollLock;

=pod

=head1 NAME

Padre::Wx::ScrollLock - Lock objects to prevent unintended scrolling

=head1 SYNOPSIS

  SCOPE: {
      my $lock = $padre_wx_treectrl->lock_scroll;
  
      # Change the tree here
  }
  
  # The tree will unlock before here

=head1 DESCRIPTION

By default several Wx objects will auto-scroll to the location of an
expand event or similar actions, as if it had been triggered by a human.

This class provides an implementation of a "scroll lock" for short-lived
sections of fully self-contained code that will be updating the structure
or content of a tree control or other scrolling object.

When created, the lock will create a Wx update locker for speed and flicker
free changes to the object. It will also remember the current scroll
position of the object.

When destroyed, the lock will move the scroll position back to the original
location if it has been changed in the process of an operation and then
release the update lock.

The result is that all operations on the object should occur with the
tree appearing to stay fixed in place.

Note that the lock MUST be short-lived, as it does not integrate with
the rest of Padre's locking system. You should already have all the data
needed to change the object prepared and ready to go before you create the
lock.

=cut

use 5.008;
use strict;
use warnings;
use Params::Util ();
use Padre::Wx    ();

our $VERSION = '0.94';

sub new {
	my $class  = shift;
	my $object = shift;
	unless ( Params::Util::_INSTANCE( $object, 'Wx::Window' ) ) {
		die "Did not provide a Wx::Window to lock";
	}
	unless ( $object->can('SetScrollPos') ) {
		die "Did not provide a Wx::Window with a SetScrollPos method";
	}

	# Create the object and record the scroll position
	return bless {
		object  => $object,
		scrolly => $object->GetScrollPos(Wx::VERTICAL),
		locker  => Wx::WindowUpdateLocker->new($object),
	}, $class;
}

sub cancel {
	$_[0]->{cancel} = 1;
}

sub apply {
	$_[0]->{object}->SetScrollPos(
		Wx::VERTICAL,
		$_[0]->{scrolly},
		0,
	);
}

sub DESTROY {

	# Return the scroll position to the previous position
	### NOTE: This just sets it to the top for now.
	unless ( $_[0]->{cancel} ) {
		$_[0]->apply;
	}

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

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::TaskQueue;

# A stripped down and heavily modified version of Thread::Queue,
# more amenable to the needs of Padre.

use 5.008005;
use strict;
use warnings;
use threads;
use threads::shared 1.33;

# use Padre::Logger;
# use constant DEBUG => 0;

our $VERSION  = '0.90';
our @CARP_NOT = ("threads::shared");

sub new {

	# TRACE( $_[0] ) if DEBUG;
	my @queue : shared = ();
	return bless \@queue, $_[0];
}

sub enqueue {

	# TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	lock($self);

	push @$self, map { shared_clone($_) } @_;

	return cond_signal(@$self);
}

sub pending {

	# TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	lock($self);
	return scalar @$self;
}

# Dequeue returns all queue elements, and blocks on an empty queue
sub dequeue {

	# TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	lock($self);

	# Wait for there to be anything in the queue
	# TRACE('About to cond_wait...') if DEBUG;
	while ( not @$self ) {
		cond_wait(@$self);
	}

	# Return multiple items
	# TRACE('Fetching all items') if DEBUG;
	my @items = ();
	push @items, shift(@$self) while @$self;

	# TRACE('Returning all items') if DEBUG;
	return @items;
}

# Pull a single queue element, and block on an empty queue
sub dequeue1 {

	# TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	lock($self);

	# Wait for there to be anything in the queue
	# TRACE('About to cond_wait...') if DEBUG;
	while ( not @$self ) {
		cond_wait(@$self);
	}

	# Return the first element only
	return shift @$self;
}

# Return items from the head of a queue with no blocking
sub dequeue_nb {

	# TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	lock($self);

	# Return multiple items
	my @items = ();
	push @items, shift @$self while @$self;
	return @items;
}

# Return a single item from the head of the queue with no blocking
sub dequeue1_nb {

	# TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	lock($self);

	# Return the first element only
	return shift @$self;
}

1;


# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


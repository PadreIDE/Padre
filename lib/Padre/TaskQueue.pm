package Padre::TaskQueue;

# A stripped down and heavily modified version of Thread::Queue,
# more amenable to the needs of Padre.

use 5.008005;
use strict;
use warnings;
use threads;
use threads::shared 1.33;

our $VERSION  = '0.94';
our @CARP_NOT = 'threads::shared';

sub new {
	my @queue : shared = ();
	bless \@queue, $_[0];
}

sub enqueue {
	my $self = shift;
	lock($self);

	push @$self, map { shared_clone($_) } @_;

	return cond_signal(@$self);
}

sub pending {
	my $self = shift;
	lock($self);

	return scalar @$self;
}

# Dequeue returns all queue elements, and blocks on an empty queue
sub dequeue {
	my $self = shift;
	lock($self);

	# Wait for there to be anything in the queue
	while ( not @$self ) {
		cond_wait(@$self);
	}

	# Return multiple items
	my @items = ();
	push @items, shift(@$self) while @$self;

	return @items;
}

# Pull a single queue element, and block on an empty queue
sub dequeue1 {
	my $self = shift;
	lock($self);

	# Wait for there to be anything in the queue
	while ( not @$self ) {
		cond_wait(@$self);
	}

	return shift @$self;
}

# Return items from the head of a queue with no blocking
sub dequeue_nb {
	my $self = shift;
	lock($self);

	# Return multiple items
	my @items = ();
	push @items, shift @$self while @$self;

	return @items;
}

# Return a single item from the head of the queue with no blocking
sub dequeue1_nb {
	my $self = shift;
	lock($self);

	return shift @$self;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

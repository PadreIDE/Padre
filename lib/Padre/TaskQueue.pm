package Padre::TaskQueue;

# A stripped down and heavily modified version of Thread::Queue,
# more amenable to the needs of Padre.

use 5.008005;
use strict;
use warnings;
use threads::shared 1.33 ();

our $VERSION  = '2.11';
our @CARP_NOT = ( "threads::shared" );

sub new {
    my @queue :shared = ();
    return bless \@queue, $_[0];
}

sub enqueue {
    my $self = shift;
    threads::shared::lock $self;

    push @$self, map {
    	threads::shared::shared_clone($_)
    } @_;

    return threads::shared::cond_signal(@$self);
}

sub pending {
    my $self = shift;
    threads::shared::lock(@$self);
    return scalar @$self;
}

# Dequeue returns all queue elements, and blocks on an empty queue
sub dequeue {
    my $self = shift;
    threads::shared::lock(@$self);

    # Wait for requisite number of items
    threads::shared::cond_wait @$self until @$self;

    # Return multiple items
    my @items = ();
    push @items, shift @$self while @$self;
    return @items;
}

# Return items from the head of a queue with no blocking
sub dequeue_nb {
    my $self = shift;
    threads::shared::lock(@$self);

    # Return multiple items
    my @items = ();
    push @items, shift @$self while @$self;
    return @items;
}

1;

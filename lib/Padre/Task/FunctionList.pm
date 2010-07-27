package Padre::Task::FunctionList;

# Function list refresh task, done mainly as a full-feature proof of concept.

use 5.008005;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.67';
our @ISA     = 'Padre::Task';





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text = delete $self->{text};

	# Get the function list
	my @functions = $self->find($text);

	# Sort it appropriately
	if ( $self->{order} eq 'alphabetical' ) {

		# Alphabetical (aka 'abc')
		@functions = sort { lc($a) cmp lc($b) } @functions;
	} elsif ( $self->{order} eq 'alphabetical_private_last' ) {

		# ~ comes after \w
		tr/_/~/ foreach @functions;
		@functions = sort { lc($a) cmp lc($b) } @functions;
		tr/~/_/ foreach @functions;
	}

	$self->{list} = \@functions;
	return 1;
}





######################################################################
# Padre::Task::FunctionList Methods

# Show an empty function list by default
sub find {
	return ();
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

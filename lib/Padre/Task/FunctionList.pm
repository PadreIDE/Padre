package Padre::Task::FunctionList;

# Function list refresh task, done mainly as a full-feature proof of concept.

use 5.008005;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my @functions = $self->find( delete $self->{text} );

	# Sort it appropriately
	my $order = $self->{order} || '';
	if ( $order eq 'alphabetical' ) {

		# Alphabetical (aka 'abc')
		# Ignore case and leading non-word characters
		my @expected = ();
		my @unknown  = ();
		foreach my $function (@functions) {
			if ( $function =~ /^([^a-zA-Z0-9]*)(.*)$/ ) {
				push @expected, [ $function, $1, lc($2) ];
			} else {
				push @unknown, $function;
			}
		}
		@expected = map { $_->[0] } sort {
			       $a->[2] cmp $b->[2]
				|| length( $a->[1] ) <=> length( $b->[1] )
				|| $a->[1] cmp $b->[1]
				|| $a->[0] cmp $b->[0]
		} @expected;
		@unknown =
			sort { lc($a) cmp lc($b) || $a cmp $b } @unknown;
		@functions = ( @expected, @unknown );

	} elsif ( $order eq 'alphabetical_private_last' ) {

		# As above, but with private functions last
		my @expected = ();
		my @unknown  = ();
		foreach my $function (@functions) {
			if ( $function =~ /^([^a-zA-Z0-9]*)(.*)$/ ) {
				push @expected, [ $function, $1, lc($2) ];
			} else {
				push @unknown, $function;
			}
		}
		@expected = map { $_->[0] } sort {
			       length( $a->[1] ) <=> length( $b->[1] )
				|| $a->[1] cmp $b->[1]
				|| $a->[2] cmp $b->[2]
				|| $a->[0] cmp $b->[0]
		} @expected;
		@unknown =
			sort { lc($a) cmp lc($b) || $a cmp $b } @unknown;
		@functions = ( @expected, @unknown );

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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

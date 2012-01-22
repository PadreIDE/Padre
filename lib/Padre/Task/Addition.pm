package Padre::Task::Addition;

use 5.008005;
use strict;
use warnings;
use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

sub new {
	shift->SUPER::new(
		prepare => 0,
		run     => 0,
		finish  => 0,
		@_,
	);
}

sub prepare {
	$_[0]->{prepare}++;
	return 1;
}

sub run {
	my $self = shift;
	$self->{run}++;
	$self->{z} = $self->{x} + $self->{y};
	return 1;
}

sub finish {
	$_[0]->{finish}++;
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Style;

# A single sequence of styling method calls to be applied to an object

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

sub new {
	my $class = shift;
	my $self  = bless [ ], $class;
	return $self;
}

sub add {
	my $self = shift;
	push @$self, @_;
	return 1;
}

sub list {
	my $self = shift;
	return @$self;
}

sub include {
	my $self = shift;
	my $style = shift;
	push @$self, $style->list;
	return 1;
}

sub apply {
	my $self   = shift;
	my $object = shift;
	my $i      = 0;
	while ( my $method = $self->[ $i++ ] ) {
		my $params = $self->[ $i++ ];
		$object->$method(@$params);
	}
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

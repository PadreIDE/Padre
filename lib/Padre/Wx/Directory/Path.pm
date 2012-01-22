package Padre::Wx::Directory::Path;

use 5.008;
use strict;
use warnings;
use File::Spec::Unix ();

our $VERSION = '0.94';

use constant {
	FILE      => 0,
	DIRECTORY => 1,
};





######################################################################
# Constructors

sub file {
	my $class = shift;
	return bless [
		FILE,
		File::Spec::Unix->catfile(@_),
		@_,
	], $class;
}

sub directory {
	my $class = shift;
	return bless [
		DIRECTORY,
		File::Spec::Unix->catfile( @_ ? @_ : ('') ),
		@_,
	], $class;
}





######################################################################
# Main Methods

sub type {
	$_[0]->[0];
}

sub image {
	$_[0]->[0] ? 'folder' : 'package';
}

sub name {
	$_[0]->[-1];
}

sub unix {
	$_[0]->[1];
}

sub path {
	@{ $_[0] }[ 2 .. $#{ $_[0] } ];
}

sub dirs {
	@{ $_[0] }[ 2 .. $#{ $_[0] } - 1 ];
}

sub depth {
	$#{ $_[0] } - 1;
}

sub is_file {
	( $_[0]->[0] == FILE ) ? 1 : 0;
}

sub is_directory {
	( $_[0]->[0] == DIRECTORY ) ? 1 : 0;
}

# Is this path the immediate parent of another path
sub is_parent {
	my $self = shift;
	my $path = shift;

	# If it is our child, it will be one element longer than us
	unless ( @$path == @$self + 1 ) {
		return 0;
	}

	# All the elements of our path will be identical in it
	foreach my $i ( 2 .. $#$self ) {
		return 0 unless $self->[$i] eq $path->[$i];
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

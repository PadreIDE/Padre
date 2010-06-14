package Padre::Wx::Directory::Path;

use 5.008;
use strict;
use warnings;
use File::Spec ();

our $VERSION = '0.64';

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
		File::Spec->catfile(@_),
		@_,
	], $class;
}

sub directory {
	my $class = shift;
	return bless [
		DIRECTORY,
		File::Spec->catfile(@_),
		@_,
	], $class;
}





######################################################################
# Main Methods

sub type {
	$_[0]->[0];
}

sub spec {
	$_[0]->[1];
}

sub path {
	@{$_[0]}[2 .. $#{$_[0]}]
}

sub is_file {
	($_[0]->[0] == FILE) ? 1 : 0;
}

sub is_directory {
	($_[0]->[0] == DIRECTORY) ? 1 : 0;
}

1;

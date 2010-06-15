package Padre::Wx::Directory::Task;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;
use Padre::Wx::Directory::Path ();

our $VERSION = '0.64';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;
	my @files = ();

	# Recursively scan for files
	local *DIR;
	while ( @queue ) {
		my $path = shift @queue;
		my $dir  = File::Spec->catdir( $root, $path->spec );
		opendir DIR, $dir or die "opendir($dir): $!";
		my @buffer = readdir DIR;
		closedir DIR;


	}

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

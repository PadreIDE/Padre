package Padre::Project::Perl;

# This is not usable yet

use 5.008;
use strict;
use warnings;
use File::Spec     ();
use Padre::Project ();

our $VERSION = '0.56';
our @ISA     = 'Padre::Project';





######################################################################
# Configuration and Intuition

sub headline {
	my $self = shift;
	$self->{headline} or
	$self->{headline} = $self->_headline;
}
		
sub _headline {
	my $self = shift;
	my $root = $self->root;

	# The intuitive approach is to find the top-most .pm file
	# in the lib directory.
	my $cursor = File::Spec->catdir( $root, 'lib' );
	unless ( -d $cursor ) {
		# Weird-looking Perl distro...
		return undef;
	}

	while ( 1 ) {
		local *DIRECTORY;
		opendir( DIRECTORY, $cursor )    or last;
		my @files = readdir( DIRECTORY ) or last;
		closedir( DIRECTORY )            or last;

		# Can we find a single dominant module?
		my @modules = grep { /\.pm\z/ } @files;
		if ( @modules == 1 ) {
			return File::Spec->catfile( $cursor, $modules[0] );
		}

		# Can we find a single subdirectory without punctuation to descend?
		# We use a slightly unusual checking process, because we want to abort
		# as soon as we see the second subdirectory (because this scanning
		# happens in the foreground and we don't want to overblock)
		my $candidate = undef;
		foreach my $file ( @files ) {
			next if $file =~ /\./;
			my $path = File::Spec->catdir( $cursor, $file );
			next unless -d $path;
			if ( $candidate ) {
				# Shortcut, more than one
				last;
			} else {
				$candidate = $path;
			}
		}

		# Did we find a single candidate?
		last unless $candidate;
		$cursor = $candidate;
	}

	return undef;
}





######################################################################
# Directory Integration

sub ignore_rule {
	return sub {

		# Default filter as per normal
		return 0 if $_->{name} =~ /^\./;

		# In a distribution, we can ignore more things
		return 0 if $_->{name} =~ /^(?:blib|_build|inc|Makefile|pm_to_blib)\z/;

		# Everything left, so we show it
		return 1;
	};
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Project::Perl;

# This is not usable yet

use strict;
use warnings;
use Padre::Project ();

our $VERSION = '0.41';
our @ISA     = 'Padre::Project';

sub from_file {
	my $class = shift;

	# Check the file argument
	my $focus_file = shift;
	unless ( -f $focus_file ) {
		return;
	}

	# Search upwards from the file to find the project root
	my ( $v, $d, $f ) = File::Spec->splitpath($focus_file);
	my @d = File::Spec->splitdir($d);
	pop @d if $d[-1] eq '';
	my $dirs = List::Util::first {
		       -f File::Spec->catpath( $v, $_, 'Makefile.PL' )
			or -f File::Spec->catpath( $v, $_, 'Build.PL' )
			or -f File::Spec->catpath( $v, $_, 'dist.ini' )
			or -f File::Spec->catpath( $v, $_, 'padre.yml' );
	}
	map { File::Spec->catdir( @d[ 0 .. $_ ] ) } reverse( 0 .. $#d );
	unless ( defined $dirs ) {
		return;
	}

	# Hand off to the regular constructor
	return $class->new(
		root => File::Spec->catpath( $v, $dirs ),
	);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Project::Perl::Temp;

use 5.008005;
use strict;
use warnings;
use File::Path       ();
use File::Spec       ();
use File::Spec::Unix ();
use File::Temp       ();

our $VERSION = '0.94';

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	if ( ref $self->{project} ) {
		$self->{project} = $self->{project}->root;
	}
	if ( defined $self->{project} ) {
		$self->{project} = File::Spec->rel2abs( $self->{project} );
	}
	unless ( $self->{files} ) {
		$self->{files} = {};
	}
	return $self;
}

sub run {
	my $self  = shift;
	my $files = $self->{files};

	# Write the unsaved files
	foreach my $unix ( sort keys %$files ) {

		# Determine where to write the file to
		my ( $v, $d, $f ) = File::Spec::Unix->splitpath($unix);
		my @p    = File::Spec::Unix->splitdir($d);
		my $dir  = File::Spec->catdir( $self->temp, @p );
		my $file = File::Spec->catfile( $dir, $f );

		# Create the directory the file will be written to
		unless ( -d $dir ) {
			File::Path::mkpath( $dir, { verbose => 0 } );
		}

		# Write the file content
		open( my $fh, '>', $file ) or die "open($file): $!";
		binmode( $fh, ':encoding(UTF-8)' );
		$fh->print( $files->{$unix} );
		close($fh) or die "close($file): $!";
	}

	return 1;
}

sub temp {
	$_[0]->{temp}
		or $_[0]->{temp} = File::Temp::tempdir( CLEANUP => 1 );
}

sub include {
	my $self = shift;
	my @include = File::Spec->catdir( $self->{temp}, 'lib' );
	if ( $self->{project} ) {
		push @include, File::Spec->catdir( $self->{project}, 'lib' );
	}
	return @include;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

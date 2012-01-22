package Padre::SVN;

# Utility functions needed for basic SVN introspection

use 5.008;
use strict;
use warnings;
use File::Spec ();

our $VERSION = '0.94';

# Find the mime type for a file
sub file_mimetype {
	my $hash = file_props(shift);
	return $hash->{'svn:mime-type'};
}

# Find and parse the properties file
sub file_props {
	my $file = shift;
	my $base = find_props($file);
	return parse_props($base);
}

# Find the props-base for a file
sub find_props {
	my $file = shift;
	my ( $v, $d, $f ) = File::Spec->splitpath($file);
	my $path = File::Spec->catpath(
		$v,
		File::Spec->catdir( $d, '.svn', 'prop' ),
		$f . '.svn-work',
	);
	return $path if -f $path;
	$path = File::Spec->catpath(
		$v,
		File::Spec->catdir( $d, '.svn', 'prop-base' ),
		$f . '.svn-base',
	);
	return $path if -f $path;
	return undef;
}

# Parse a property file
sub parse_props {
	my $file = shift;
	open( my $fh, '<', $file ) or die "Failed to open '$file'";

	# Simple state parser
	my %hash   = ();
	my $kbytes = 0;
	my $vbytes = 0;
	my $key    = undef;
	my $value  = undef;
	while ( my $line = <$fh> ) {
		if ( $vbytes ) {
			my $l = length $line;
			if ( $l == $vbytes + 1 ) {
				# Perfect content length
				chomp($line);
				$hash{$key} = $value . $line;
				$vbytes = 0;
				$key    = undef;
				$value  = undef;
				next;
			}
			if ( $l > $vbytes ) {
				$value .= $line;
				$vbytes -= $l;
				next;
			}
			die "Found value longer than specified length";
		}

		if ( $kbytes ) {
			my $l = length $line;
			if ( $l == $kbytes + 1 ) {
				# Perfect content length
				chomp($line);
				$key .= $line;
				$kbytes = 0;
				next;
			}
			if ( $l > $kbytes ) {
				$key .= $line;
				$kbytes -= $l;
				next;
			}
			die "Found key longer than specified length";
		}

		if ( defined $key ) {
			$line =~ /^V\s(\d+)/ or die "Failed to find expected V line";
			$vbytes = $1;
			$value  = '';
			next;
		}

		last if $line =~ /^END/;

		# We should have a K line indicating key size
		$line =~ /^K\s(\d+)/ or die "Failed to find expected K line";
		$kbytes = $1;
		$key    = '';
	}

	close $fh;

	return \%hash;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
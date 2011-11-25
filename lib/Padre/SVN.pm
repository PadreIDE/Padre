package Padre::SVN;

# Utility functions needed for basic SVN introspection

use 5.008;
use strict;
use warnings;

our $VERSION = '0.93';

# Parse a property file
sub parse_props {
	my $file = shift;
	open( FILE, '<', $file ) or die "Failed to open '$file'";

	# Simple state parser
	my %props = ();
	while ( my $line = <FILE> ) {
		last if $line =~ /^END/;

		# We should have a K line indicating key size
		$line =~ /^K\s(\d+)/ or die "Failed to find expected K line";
		my $bytes = $1;

		# Fetch 
	}
}

1;

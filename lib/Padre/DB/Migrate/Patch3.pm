package Padre::DB::Migrate::Patch3;

use strict;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	# Remove the dedundant modules table
	$self->do('DROP TABLE modules');

	return 1;
}

1;

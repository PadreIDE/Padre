package Padre::DB::Migrate::Patch11;

use strict;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	# Create the recently used table
	do(<<'END_SQL');
CREATE TABLE recently_used (
	name      VARCHAR(255) PRIMARY KEY,
	value     VARCHAR(255) NOT NULL,
	type      VARCHAR(255) NOT NULL,
	last_used DATE
)
END_SQL

	return 1;
}

1;

package Padre::DB::Migrate::Patch7;

# Add a new table to keep the last position in file
# NOTE: We're not using the history table, since history can be truncated.

use strict;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	$self->do(<<'END_SQL');
create table last_position_in_file (
	name varchar(255) not null primary key,
	position integer not null
)
END_SQL

	return 1;
}

1;

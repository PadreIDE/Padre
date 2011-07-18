package Padre::DB::Migrate::Patch9;

use strict;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.85';
our @ISA     = 'Padre::DB::Migrate::Patch';





######################################################################
# Migrate Forwards

sub upgrade {
	my $self = shift;

	# Syntax highlighter preferences
	$self->do(<<'END_SQL');
CREATE TABLE syntax_highlight (
	mime_type VARCHAR(255) PRIMARY KEY,
	value VARCHAR(255)
)
END_SQL

	return 1;
}

1;

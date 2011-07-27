package Padre::DB::Migrate::Patch9;

use 5.008;
use strict;
use warnings;
use Padre::DB::Migrate::Patch ();

our $VERSION = '0.89';
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

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


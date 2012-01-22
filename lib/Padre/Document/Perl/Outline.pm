package Padre::Document::Perl::Outline;

use 5.008;
use strict;
use warnings;
use Padre::Task::Outline ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task::Outline';





######################################################################
# Padre::Task::Outline Methods

sub find {
	my $self = shift;
	my $text = shift;

	require PPIx::EditorTools::Outline;
	return PPIx::EditorTools::Outline->new->find( code => $text );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

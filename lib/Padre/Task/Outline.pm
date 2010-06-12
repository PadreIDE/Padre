package Padre::Task::Outline;

# Function list refresh task, done mainly as a full-feature proof of concept.

use 5.008005;
use strict;
use warnings;
use Padre::Task   ();

our $VERSION = '0.64';
our @ISA     = 'Padre::Task';





######################################################################
# Padre::Task Methods

sub run {
	my $self  = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text = delete $self->{text};

	# Generate the outline
	$self->{data} = $self->find( $text );

	return 1;
}





######################################################################
# Padre::Task::Outline Methods

# Show an empty function list by default
sub find {
	return [];
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

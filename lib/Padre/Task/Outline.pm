package Padre::Task::Outline;

# Outline refresh task, done mainly as a full-feature proof of concept.

use 5.008005;
use strict;
use warnings;
use Params::Util ('_INSTANCE');
use Padre::Task  ();

our $VERSION = '1.02';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Just convert the document to text for now.
	# Later, we'll suck in more data from the project and
	# other related documents to create an outline tree more awesomely.
	unless ( _INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the outline task";
	}

	# Remove the document entirely as we do this,
	# as it won't be able to survive serialisation.
	my $document = delete $self->{document};
	$self->{text} = $document->text_get;

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text = delete $self->{text};

	# Generate the outline
	$self->{data} = $self->find($text);

	return 1;
}





######################################################################
# Padre::Task::Outline Methods

# Show an empty function list by default
sub find {
	return [];
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

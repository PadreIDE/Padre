package Padre::Task::Syntax;

use 5.008;
use strict;
use warnings;
use Carp         ();
use Params::Util ();
use Padre::Task  ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Just convert the document to text for now.
	# Later, we'll suck in more data from the project and
	# other related documents to do syntax checks more awesomely.
	unless ( Params::Util::_INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the syntax check task";
	}

	# Remove the document entirely as we do this,
	# as it won't be able to survive serialisation.
	my $document = delete $self->{document};
	$self->{text}     = $document->text_get;
	$self->{project}  = $document->project_dir;
	$self->{filename} = $document->filename;

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text = delete $self->{text};

	# Get the syntax model object
	$self->{model} = $self->syntax($text);

	return 1;
}

sub syntax {
	return {};
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

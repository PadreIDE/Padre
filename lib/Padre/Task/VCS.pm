package Padre::Task::VCS;

use 5.008005;
use strict;
use warnings;
use Padre::Task     ();
use Padre::Util     ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = 'Padre::Task';

######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Just convert the document to text for now.
	# Later, we'll suck in more data from the project and
	# other related documents to do VCS operations more awesomely.
	unless ( Params::Util::_INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the VCS task\n";
	}

	# Remove the document entirely as we do this,
	# as it won't be able to survive serialisation.
	my $document = delete $self->{document};

	# Obtain document full filename
	my $file = $document->{file};
	$self->{filename} = $file ? $file->filename : undef;

	# Obtain project's Version Control System (VCS)
	$self->{vcs} = $document->project->vcs;

	# Obtain document project dir
	$self->{project_dir} = $document->project_dir;

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Pull the text off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	my $text        = delete $self->{text}        if $self->{text};
	my $vcs         = delete $self->{vcs}         if $self->{vcs};
	my $filename    = delete $self->{filename}    if $self->{filename};
	my $project_dir = delete $self->{project_dir} if $self->{project_dir};

	# TODO implement run

	$self->{data} = [];

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

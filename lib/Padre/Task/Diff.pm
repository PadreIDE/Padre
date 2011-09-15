package Padre::Task::Diff;

use 5.008005;
use strict;
use warnings;
use Params::Util ();
use Padre::Task  ();
use Padre::Util  ();
use Algorithm::Diff ();

our $VERSION = '0.91';
our @ISA     = 'Padre::Task';

######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Just convert the document to text for now.
	# Later, we'll suck in more data from the project and
	# other related documents to do differences calculation more awesomely.
	unless ( Params::Util::_INSTANCE( $self->{document}, 'Padre::Document' ) ) {
		die "Failed to provide a document to the diff task\n";
	}

	# Remove the document entirely as we do this,
	# as it won't be able to survive serialisation.
	my $document = delete $self->{document};

	# Obtain document full filename
	my $file     = $document->{file};
	unless ($file) {
		die "Could not find a filename for the current document\n";
	}
	$self->{filename} = $file->filename;

	# Obtain document text
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

	# Generate the differences between saved and current document
	$self->{data} = [];
 	my $content = Padre::Util::slurp($self->{filename});
 	if($content) {
		my @seq1  = split /\n/, $$content;
		my @seq2  = split /\n/, $text;
		my @diffs = Algorithm::Diff::diff(\@seq1, \@seq2);
		$self->{data} = \@diffs;
	}

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

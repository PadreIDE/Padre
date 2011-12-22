package Padre::Wx::Dialog::Document;

use 5.008;
use strict;
use warnings;
use Scalar::Util ();
use Padre::Locale ();
use Padre::Wx::FBP::Document ();

our $VERSION = '0.93';
our @ISA     = 'Padre::Wx::FBP::Document';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->CentreOnParent;
	return $self;
}





######################################################################
# Main Methods

sub run {
	my $class = shift;
	my $self  = $class->new(@_);

	# Load all the document information
	$self->refresh;

	# Show the document information
	$self->ShowModal;

	# Clean up
	$self->Destroy;
}

sub refresh {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document or return;
	my $editor   = $current->editor   or return;
	my $mime     = $document->mime;

	# Find the document encoding
	my $encoding = $document->encoding;
	unless ( $encoding and $encoding ne 'ascii' ) {
		$encoding = Padre::Locale::encoding_from_string();
	}
	unless ( $encoding and $encoding ne 'ascii' ) {
		$encoding = "ASCII";
	}

	# Update the general document information
	$self->{filename}->SetLabel( $document->get_title );
	$self->{document_type}->SetLabel( $mime->name );
	$self->{document_class}->SetLabel( Scalar::Util::blessed($document) );
	$self->{mime_type}->SetLabel( $mime->type );
	$self->{encoding}->SetLabel( $encoding );
	$self->{newline_type}->SetLabel( $document->newline_type );

	# Update the overall document statistics
	$self->{document_lines} = $editor->GetLineCount;
	$self->{document_bytes} = $editor->GetLength;

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

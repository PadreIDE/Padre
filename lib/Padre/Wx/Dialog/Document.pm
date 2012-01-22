package Padre::Wx::Dialog::Document;

use 5.008;
use strict;
use warnings;
use Scalar::Util ();
use Padre::Locale ();
use Padre::Wx::FBP::Document ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::Document';

my @SELECTION_FIELDS = qw{
	selection_label
	selection_bytes
	selection_characters
	selection_visible
	selection_lines
	selection_words
};




######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->CentreOnParent;

	# Save the label colours for later
	$self->{strong} = $self->{document_label}->GetForegroundColour;
	$self->{weak}   = $self->{selection_label}->GetForegroundColour;

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
		$encoding = Padre::Locale::encoding_from_string( $editor->GetText );
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
	SCOPE: {
		my $text  = $editor->GetText;
		my @words = $text =~ /(\w+)/g;
		$text =~ s/\s//g;
		$self->{document_bytes}->SetLabel( $editor->GetLength );
		$self->{document_characters}->SetLabel( length $editor->GetText );
		$self->{document_visible}->SetLabel( length $text );
		$self->{document_lines}->SetLabel( $editor->GetLineCount );
		$self->{document_words}->SetLabel( scalar @words );
	}

	# Update the selection statistics
	SCOPE: {
		my $text = $editor->GetSelectedText;
		if ( length $text ) {
			my @words = $text =~ /(\w+)/g;
			$text =~ s/\s//g;
			$self->{selection_bytes}->SetLabel( length $editor->GetSelectedText );
			$self->{selection_characters}->SetLabel( length $editor->GetSelectedText );
			$self->{selection_visible}->SetLabel( length $text );
			$self->{selection_lines}->SetLabel( '?' );
			$self->{selection_words}->SetLabel( scalar @words );
		} else {
			$self->{selection_bytes}->SetLabel(0);
			$self->{selection_characters}->SetLabel(0);
			$self->{selection_visible}->SetLabel(0);
			$self->{selection_lines}->SetLabel(0);
			$self->{selection_words}->SetLabel(0);
		}

		# Set the colour of the selection labels
		my $colour = length($text) ? $self->{strong} : $self->{weak};
		foreach my $field ( @SELECTION_FIELDS ) {
			$self->{$field}->SetForegroundColour($colour);
		}
	}

	# Recalculate the layout and fix the size
	$self->Layout;

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

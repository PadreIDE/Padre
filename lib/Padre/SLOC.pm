package Padre::SLOC;

# A basic Source Lines of Code counter/accumulator

use 5.008;
use strict;
use warnings;
use Params::Util ();
use Padre::MIME  ();

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';





######################################################################
# Constructor

sub new {
	my $class = shift;
	return bless { }, $class;
}





######################################################################
# Statistics Capture

sub add {
	my $self  = shift;
	my $add   = shift;
	foreach my $key ( sort keys %$add ) {
		next unless $add->{$key};
		$self->{$key} ||= 0;
		$self->{$key} += $add->{$key};
	}
	return 1;
}

sub add_text {
	my $self = shift;
	my $text = shift;
	my $mime = shift;

	# Normalise newlines
	$$text =~ s/(?:\015{1,2}\012|\015|\012)/\n/sg;

	# Detect MIME if not provided
	$mime ||= Padre::MIME->detect(
		text => $$text,
	);

	# Get the line count for the file
	my $count = $self->count_mime( $text, $mime );

	# Add the line counts for the scalar
	$self->add($count);
}

sub add_document {
	my $self     = shift;
	my $document = shift;
	my $text     = $document->text_get or return;
	my $mime     = $document->mime     or return;
	$self->add_text( \$text, $mime );
}

sub add_editor {
	my $self   = shift;
	my $editor = shift;
	my $document = $editor->document or return;
	$self->add_document($document);
}

sub add_file {
	my $self = shift;
	my $file = shift;
	unless ( Params::Util::_INSTANCE($file, 'Padre::File') ) {
		require Padre::File::Local;
		$file = Padre::File::Local->new($file);
	}

	# Load the file
	my $text = $file->read;
	return unless defined $text;

	# Detect the MIME type
	my $mime = Padre::MIME->detect(
		file => $file->filename,
		text => $text,
	);

	$self->add_text( $mime, \$text );
}





######################################################################
# Statistics Reporting

sub total_code {
	my $self  = shift;
	my $total = 0;
	foreach my $key ( sort keys %$self ) {
		my ($lang, $type) = split /\s+/, $key;
		if ( $type eq 'code' ) {
			$total += $self->{$key};
		}
	}
	return $total;
}

sub report_languages {
	my $self  = shift;
	my %hash  = ();
	foreach my $key ( sort keys %$self ) {
		my ($lang, $type) = split /\s+/, $key;
		$hash{$lang} ||= 0;
		$hash{$lang} += $self->{$key};
	}
	return \%hash;
}

sub report_types {
	my $self = shift;
	my %hash  = ();
	foreach my $key ( sort keys %$self ) {
		my ($lang, $type) = split /\s+/, $key;
		$hash{$type} ||= 0;
		$hash{$type} += $self->{$key};
	}
	return \%hash;
}





######################################################################
# SLOC Counters

sub count_mime {
	my $self = shift;
	my $text = shift;
	my $mime = shift;

	# Dispatch to language-specific counting methods
	if ( $mime->type eq 'application/x-perl' ) {
		return $self->count_perl5( $text, $mime );
	}
	if ( $mime->type eq 'text/pod' ) {
		return $self->count_perl5( $text, $mime );
	}

	# Fall back to the generic counting methods
	if ( $mime->comment ) {
		return $self->count_commented( $text, $mime );
	} else {
		return $self->count_uncommented( $text, $mime );
	}
}

sub count_perl5 {
	my $self  = shift;
	my $text  = shift;
	my %count = (
		'text/pod comment'           => 0,
		'text/pod blank'             => 0,
		'application/x-perl code'    => 0,
		'application/x-perl comment' => 0,
		'application/x-perl blank'   => 0,
	);

	my $code = 1;
	foreach my $line ( split /\n/, $$text, -1 ) {
		if ( $line !~ /\S/ ) {
			if ( $code ) {
				$count{'application/x-perl blank'}++;
			} else {
				$count{'text/pod blank'}++;
			}
		} elsif ( $line =~ /^=cut\s*/ ) {
			$count{'text/pod comment'}++;
			$code = 1;
		} elsif ( $code ) {
			if ( $line =~ /^=\w+/ ) {
				$count{'text/pod comment'}++;
				$code = 0;
			} elsif ( $line =~ /^\s*#/ ) {
				$count{'application/x-perl comment'}++;
			} else {
				$count{'application/x-perl code'}++;
			}
		} else {
			$count{'text/pod comment'}++;
		}
	}

	return \%count;
}

# Find SLOC information for languages which have comments
sub count_commented {
	my $self    = shift;
	my $text    = shift;
	my $mime    = shift;
	my $type    = $mime->type;
	my $comment = $mime->comment or return undef;
	my $matches = $comment->line_match;
	my %count   = (
		"$type code"    => 0,
		"$type comment" => 0,
		"$type blank"   => 0,
	);

	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{"$type blank"}++;
		} elsif ( $line =~ $matches ) {
			$count{"$type comment"}++;
		} else {
			$count{"$type code"}++;
		}
	}

	return \%count;
}

# Find SLOC information for languages which do not have comments
sub count_uncommented {
	my $self  = shift;
	my $text  = shift;
	my $mime  = shift;
	my $type  = $mime->type;
	my %count = (
		"$type code"  => 0,
		"$type blank" => 0,
	);

	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{"$type blank"}++;
		} else {
			$count{"$type code"}++;
		}
	}

	return \%count;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

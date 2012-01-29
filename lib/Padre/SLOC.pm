package Padre::SLOC;

use 5.008;
use strict;
use warnings;
use Padre::MIME ();

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';





######################################################################
# Constructor

sub new {
	my $class = shift;
	return bless {
		total => { },
	}, $class;
}

sub add_count {
	my $self  = shift;
	my $add   = shift;
	my $total = $self->{total};
	foreach my $key ( sort keys %$add ) {
		next unless $add->{$key};
		$total->{$key} ||= 0;
		$total->{$key} += $add->{$key};
	}
	return 1;
}

sub add_scalar {
	my $self = shift;
	my $text = shift;

	# Normalise newlines
	$$text =~ s/(?:\015{1,2}\012|\015|\012)/\n/sg;

}

sub add_file {
	my $self = shift;
	my $file = shift;
	my $type = Padre::MIME->detect(
		file => $file,
	);
	
}





######################################################################
# SLOC Counters

sub count_mime {
	my $self = shift;
	my $mime = shift;
	my $text = shift;

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
	my $mime    = shift;
	my $text    = shift;
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
	my $mime  = shift;
	my $text  = shift;
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

package Padre::SLOC;

use 5.008;
use strict;
use warnings;
use Padre::MIME ();

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';

my %COMMENT = (
	'text/x-pod' => 1,
);





######################################################################
# Constructor

sub new {
	my $class = shift;
	return bless {
		count => { },
	}, $class;
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

sub count_perl5 {
	my $self  = shift;
	my $text  = shift;
	my %count = (
		'text/x-pod'         => 0,
		'application/x-perl' => 0,
		'comment'            => 0,
		'blank'              => 0,
	);

	my $code = 1;
	foreach my $line ( split /\n/, $$text, -1 ) {
		if ( $line !~ /\S/ ) {
			$count{'blank'}++;
		} elsif ( $line =~ /^=cut\s*/ ) {
			$count{'text/x-pod'}++;
			$code = 1;
		} elsif ( $code ) {
			if ( $line =~ /^=\w+/ ) {
				$count{'text/x-pod'}++;
				$code = 0;
			} elsif ( $line =~ /^\s*#/ ) {
				$count{'comment'}++;
			} else {
				$count{'application/x-perl'}++;
			}
		} else {
			$count{'text/x-pod'}++;
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
		$type   => 0,
		comment => 0,
		blank   => 0,
	);

	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{blank}++;
		} elsif ( $line =~ $matches ) {
			$count{comment}++;
		} else {
			$count{$type}++;
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
		$type => 0,
		blank => 0,
	);

	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{blank}++;
		} else {
			$count{$type}++;
		}
	}

	return \%count;		
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

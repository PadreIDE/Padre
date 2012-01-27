package Padre::SLOC;

use 5.008;
use strict;
use warnings;
use Padre::MIME ();

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';

my %DOCUMENTATION = map { $_ => 1 } qw{
	text/x-pod
};





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

sub sloc_perl5 {
	my $self  = shift;
	my $text  = shift;
	my %count = (
		'text/x-pod'  => 0,
		'application/x-perl' => 0,
		'comment'     => 0,
		'blank'       => 0,
	);

	my $code = 1;
	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{'blank'}++;
			next;
		}
		if ( $line =~ /^=cut\s*/ ) {
			$count{'text/x-pod'}++;
			$code = 1;
			next;
		}
		if ( $line =~ /^=\w+/ ) {
			$count{'text/x-pod'}++;
			$code = 0;
			next;
		}
		if ( $code and $line =~ /\s*#/ ) {
			$count{'comment'}++;
		} else {
			$count{'application/x-perl'}++;
		}			
	}

	return \%count;
}

sub sloc_csharp {
	my $self  = shift;
	my $text  = shift;
	my %count = (
		'text/x-csharp' => 0,
		'comment'       => 0,
		'blank'         => 0,
	);

	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{'blank'}++;
		} elsif ( $line =~ /\s*\/\// ) {
			$count{'comment'}++;
		} else {
			$count{'text/x-csharp'}++;
		}			
	}

	return \%count;
}

sub sloc_text {
	my $self  = shift;
	my $text  = shift;
	my %count  = (
		'text/plain' => 0,
		'blank'      => 0,
	);

	# Iterate through the file
	foreach my $line ( split /\n/, $$text ) {
		if ( $line !~ /\S/ ) {
			$count{'blank'}++;
		} elsif ( $line =~ /\s*\/\// ) {
			$count{'comment'}++;
		} else {
			$count{'text/x-csharp'}++;
		}			
	}

	return \%count;		
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

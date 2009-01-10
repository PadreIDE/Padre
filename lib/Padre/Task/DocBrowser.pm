package Padre::Task::DocBrowser;

use strict;
use warnings;
use Padre::DocBrowser;
use threads;

use base 'Padre::Task';

our $VERSION = '0.25';

use Data::Dumper;

sub run {
	my ($self) = @_;

	$self->{browser} ||=  Padre::DocBrowser->new();
	my $type = $self->{type} || 'error';
	if ( $type eq 'error' ) {
		return "BREAK";
	}
	unless ( $self->{browser}->can( $type ) ) {
		return "BREAK";
	}

	my $result = $self->{browser}->$type( $self->{document} );
	$self->{result} = $result;
	return 1;
	
	   
}

sub finish {
	my $self = shift;
	$self->{main_thread_only}->( $self->{result}, $self->{document} );
}

1;
# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

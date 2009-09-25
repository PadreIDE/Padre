package Padre::Task::DocBrowser;

use 5.008;
use strict;
use warnings;
use threads;
use Padre::Task ();

our $VERSION = '0.47';
our @ISA     = 'Padre::Task';

sub run {
	my ($self) = @_;

	require Padre::DocBrowser;
	$self->{browser} ||= Padre::DocBrowser->new;
	my $type = $self->{type} || 'error';
	if ( $type eq 'error' ) {
		return "BREAK";
	}
	unless ( $self->{browser}->can($type) ) {
		return "BREAK";
	}

	my $result = $self->{browser}->$type(
		$self->{document},
		$self->{args}
	);
	$self->{result} = $result;

	return 1;

}

sub finish {
	my $self = shift;
	$self->{main_thread_only}->( $self->{result}, $self->{document} );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Task::Browser;

use 5.008;
use strict;
use warnings;
use threads;
use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

sub prepare {
	my $self = shift;
	$self->{method} ||= 'error';
	return 0 if $self->{method} eq 'error';
	return 1;
}

sub run {
	my $self   = shift;
	my $method = $self->{method};

	require Padre::Browser;
	my $browser = Padre::Browser->new;
	unless ( $browser->can($method) ) {
		die "Browser does not support '$method'";
	}

	$self->{result} = $browser->$method(
		$self->{document},
		$self->{args}
	);

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

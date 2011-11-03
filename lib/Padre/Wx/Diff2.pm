package Padre::Wx::Diff2;

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::FBP::Diff   ();
use Padre::Logger qw(TRACE);

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Wx
	Padre::Wx::FBP::Diff
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->SUPER::new($main);

	return $self;
}

sub show {
	my $self = shift;

print "Show\n";
	$self->Show;
	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

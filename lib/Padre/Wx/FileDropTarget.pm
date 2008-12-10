package Padre::Wx::FileDropTarget;

use 5.008;
use strict;
use warnings;
use Wx::DND;

our $VERSION = '0.20';
our @ISA     = 'Wx::FileDropTarget';

sub new {
	my $class     = shift;
	my $self      = $class->SUPER::new;
	$self->{main} = shift;
	return $self;
}

sub OnDropFiles {
	foreach my $i ( @{$_[3]} ) {
		$_[0]->{main}->setup_editor($i);
		$_[0]->{main}->refresh;
	}
	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

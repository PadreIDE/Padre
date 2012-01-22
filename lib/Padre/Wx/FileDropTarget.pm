package Padre::Wx::FileDropTarget;

use 5.008;
use strict;
use warnings;
use Params::Util ();
use Padre::Wx 'DND';

our $VERSION = '0.94';
our @ISA     = 'Wx::FileDropTarget';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new;
	$self->{main} = shift;
	return $self;
}

sub set {
	my $self = shift;
	unless ( Params::Util::_INSTANCE( $self, 'Padre::Wx::FileDropTarget' ) ) {
		$self = $self->new(@_);
	}
	$self->{main}->SetDropTarget($self);
	return 1;
}

sub OnDropFiles {
	foreach my $i ( @{ $_[3] } ) {
		$_[0]->{main}->setup_editor($i);
		$_[0]->{main}->refresh;
	}
	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Wx::Perl::Dialog::Frame;

use 5.008;
use strict;
use warnings;
use File::Spec ();
use Wx::Perl::Dialog;
use Wx::STC ();

use base 'Wx::Frame';

our $VERSION = '0.47';

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'Wx::Perl::Dialog',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	#    Wx::Event:EVT_ACTIVATE($self, \&on_activate);
	Wx::Event::EVT_CLOSE(
		$self,
		sub {
			my ( $self, $event ) = @_;
			$event->Skip;
		}
	);

	return $self;
}

sub on_activate {
	my ( $frame, $event ) = @_;

	$frame->EVT_ACTIVATE( sub { } );

	#$Wx::Perl::Dialog::app->Yield;
	return $Wx::Perl::Dialog::main->($frame);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

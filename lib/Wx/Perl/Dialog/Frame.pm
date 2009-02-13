package Wx::Perl::Dialog::Frame;

use 5.008;
use strict;
use warnings;
use File::Spec         ();
use Wx                 qw(:everything);
use Wx::STC            ();
use Wx::Event          qw(:everything);
use Wx::Perl::Dialog::Frame ();
use base 'Wx::Frame';

our $VERSION = '0.05';

sub new {
    my ($class) = @_;

    my $self = $class->SUPER::new(
        undef,
        -1,
        'Wx::Perl::Dialog',
        wxDefaultPosition,
        wxDefaultSize,
    );


#    EVT_ACTIVATE($self, \&on_activate);
    Wx::Event::EVT_CLOSE( $self,  sub {
         my ( $self, $event ) = @_;
         $event->Skip;
    } );

    return $self;
}

sub on_activate {
   my ($frame, $event) = @_;

   $frame->EVT_ACTIVATE(sub {});
   #$Wx::Perl::Dialog::app->Yield;
   return $Wx::Perl::Dialog::main->($frame);
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

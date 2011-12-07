package Padre::Wx::Dialog::PluginManager2;

use 5.008;
use strict;
use warnings;
use Padre::Wx::FBP::PluginManager ();

our $VERSION = '0.93';
our @ISA     = 'Padre::Wx::FBP::PluginManager';





######################################################################
# Class Methods

sub run {
	my $class = shift;
	my $self  = $class->new(@_);
	$self->ShowModal;
	$self->Delete;
	return 1;
}





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	# Do an initial refresh here

	# Prepare to be shown
	$self->CenterOnParent;

	return $self;
}





######################################################################
# Event Handlers



1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

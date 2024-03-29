package Padre::Wx::FBP::Outline;

## no critic

# This module was generated by Padre::Plugin::FormBuilder::Perl.
# To change this module edit the original .fbp file and regenerate.
# DO NOT MODIFY THIS FILE BY HAND!

use 5.008005;
use utf8;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Role::Main ();
use Padre::Wx::TreeCtrl ();

our $VERSION = '1.02';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Panel
};

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::DefaultPosition,
		[ 195, 530 ],
		Wx::TAB_TRAVERSAL,
	);

	$self->{search} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::SIMPLE_BORDER,
	);

	$self->{tree} = Padre::Wx::TreeCtrl->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TR_HAS_BUTTONS | Wx::TR_HIDE_ROOT | Wx::TR_LINES_AT_ROOT | Wx::TR_SINGLE | Wx::NO_BORDER,
	);

	my $main_sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$main_sizer->Add( $self->{search}, 0, Wx::EXPAND, 1 );
	$main_sizer->Add( $self->{tree}, 1, Wx::ALL | Wx::EXPAND, 1 );

	$self->SetSizer($main_sizer);
	$self->Layout;

	return $self;
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


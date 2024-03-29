package Padre::Wx::FBP::DebugOutput;

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
		[ 500, 300 ],
		Wx::TAB_TRAVERSAL,
	);

	$self->{status} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Status"),
	);

	$self->{debug_launch_options} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Debug Launch Options:"),
	);

	$self->{dl_options} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("none"),
	);

	$self->{output} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_MULTILINE | Wx::TE_READONLY | Wx::SIMPLE_BORDER,
	);

	my $top_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$top_sizer->Add( $self->{status}, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL | Wx::EXPAND, 5 );
	$top_sizer->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$top_sizer->Add( $self->{debug_launch_options}, 0, Wx::ALL, 5 );
	$top_sizer->Add( $self->{dl_options}, 0, Wx::ALL, 5 );
	$top_sizer->Add( 0, 0, 1, Wx::EXPAND, 5 );

	my $main_sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$main_sizer->Add( $top_sizer, 0, Wx::ALIGN_RIGHT | Wx::ALL | Wx::EXPAND, 2 );
	$main_sizer->Add( $self->{output}, 1, Wx::ALL | Wx::EXPAND, 0 );

	$self->SetSizer($main_sizer);
	$self->Layout;

	return $self;
}

sub status {
	$_[0]->{status};
}

sub dl_options {
	$_[0]->{dl_options};
}

sub output {
	$_[0]->{output};
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


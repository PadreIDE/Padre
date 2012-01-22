package Padre::Wx::Frame::HTML;

# Provides a base class for dialogs that are built using dynamic HTML

use 5.008;
use strict;
use warnings;
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();

our $VERSION = '0.94';
our @ISA     = 'Wx::Frame';

sub new {
	my $class = shift;

	# Get the params, and apply defaults
	my %param = (
		parent => undef,
		id     => -1,
		style  => Wx::DEFAULT_FRAME_STYLE,
		title  => '',
		pos    => [ -1, -1 ],
		size   => [ -1, -1 ],
		@_,
	);

	# Create the dialog object
	my $self = $class->SUPER::new(
		$param{parent},
		$param{id},
		$param{title},
		$param{pos},
		$param{size},
		$param{style},
	);
	%$self = %param;

	# Create the panel to hold the HTML widget
	$self->{panel} = Wx::Panel->new( $self, -1 );
	$self->{sizer} = Wx::GridSizer->new( 1, 1, 10, 10 );

	# Add the HTML renderer to the frame
	$self->{renderer} = Padre::Wx::HtmlWindow->new(
		$self->{panel},
		-1,
		[ -1, -1 ],
		[ -1, -1 ],
		Wx::HW_NO_SELECTION,
	);
	$self->{renderer}->SetBorders(0);

	$self->{sizer}->Add(
		$self->{renderer},
		1, # Growth proportion
		Wx::EXPAND,
		5, # Border size
	);

	# Tie the sizing to the panel
	$self->{panel}->SetSizer( $self->{sizer} );
	$self->{panel}->SetAutoLayout(1);

	# Do an initial refresh to load the HTML
	$self->refresh;

	return $self;
}

sub refresh {
	my $self = shift;
	my $html = $self->html;
	$self->{renderer}->SetPage($html);
	return;
}

# The default renderer returns a fixed HTML string passed to the constructor.
# Dialogs that work with dynamic state will build the HTML on the fly.
sub html {
	$_[0]->{html};
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

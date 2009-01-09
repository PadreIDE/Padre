package Padre::Wx::Output;

# Class for the output window at the bottom of Padre.
# This currently has very little customisation code in it,
# but that will change in future.

use 5.008;
use strict;
use warnings;
use utf8;
use Encode       ();
use Params::Util ();
use Padre::Wx    ();

our $VERSION = '0.24';
our @ISA     = 'Wx::TextCtrl';

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$main->bottom,
		-1,
		"", 
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_READONLY
		| Wx::wxTE_MULTILINE
		| Wx::wxTE_DONTWRAP
		| Wx::wxNO_FULL_REPAINT_ON_RESIZE,
	);

	# Do custom startup stuff here
	$self->clear;
	$self->SetFont(
		Wx::Font->new(
			Wx::wxNORMAL_FONT->GetPointSize,
			Wx::wxTELETYPE,
			Wx::wxNORMAL,
			Wx::wxNORMAL,
		),
	);
	$self->AppendText( Wx::gettext('No output') );

	return $self;
}

sub main {
	$_[0]->GetGrandParent;
}

sub gettext_label {
	Wx::gettext('Output');
}





#####################################################################
# Main Methods

# From Sean Healy on wxPerl mailing list.
# Tweaked to avoid copying as much as possible.
sub AppendText {
	my $self = shift;
	if ( utf8::is_utf8($_[0]) ) {
		return $self->SUPER::AppendText($_[0]);
	}
	my $text = Encode::decode('utf8', $_[0]);
	$self->SUPER::AppendText($text);
}

sub select {
	my $self   = shift;
	my $parent = $self->GetParent;
	$parent->SetSelection( $parent->GetPageIndex($self) );
	return;
}

# A convenience not provided by the original version
sub SetBackgroundColour {
	my $self = shift;
	my $arg  = shift;
	if ( defined Params::Util::_STRING($arg) ) {
		$arg = Wx::Colour->new($arg);
	}
	return $self->SUPER::SetBackgroundColour($arg);
}

sub clear {
	my $self = shift;
	$self->SetBackgroundColour('#FFFFFF');
	$self->Remove( 0, $self->GetLastPosition );
	return 1;
}

sub style_good {
	$_[0]->SetBackgroundColour('#CCFFCC');
}

sub style_bad {
	$_[0]->SetBackgroundColour('#FFCCCC');
}

sub style_neutral {
	$_[0]->SetBackgroundColour('#FFFFFF');
}

sub style_busy {
	$_[0]->SetBackgroundColour('#CCCCCC');
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

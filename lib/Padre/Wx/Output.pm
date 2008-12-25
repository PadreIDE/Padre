package Padre::Wx::Output;

# Class for the output window at the bottom of Padre.
# This currently has very little customisation code in it,
# but that will change in future.

use 5.008;
use strict;
use warnings;
use Params::Util ();
use Padre::Wx    ();

use base 'Wx::TextCtrl';

our $VERSION = '0.22';

sub new {
	my $class  = shift;
	my $parent = shift;
	my $self   = $class->SUPER::new(
		$parent,
		-1,
		"", 
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_READONLY | Wx::wxTE_MULTILINE | Wx::wxTE_DONTWRAP | Wx::wxNO_FULL_REPAINT_ON_RESIZE,
	);

	# Do custom startup stuff here
	$self->clear;
	my $stdFontSize = Wx::wxNORMAL_FONT->GetPointSize;
	my $font = Wx::Font->new( $stdFontSize, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL );
	$self->SetFont($font);
	$self->AppendText(Wx::gettext('No output'));

	return $self;
}

# from Sean Healy on wxPerl mailing list
use Encode;
sub AppendText {
	my ($self, $text) = @_;
    my $string = utf8::is_utf8($text) ? $text : decode('utf8', $text);
	$self->SUPER::AppendText($string);
}

sub select {
	my $self = shift;

	my $idx = $self->GetParent->GetPageIndex($self);
	$self->GetParent->SetSelection($idx);

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
	my $self = shift;
	$self->SetBackgroundColour('#CCFFCC');
	return 1;
}

sub style_bad {
	my $self = shift;
	$self->SetBackgroundColour('#FFCCCC');
	return 1;
}

sub style_neutral {
	my $self = shift;
	$self->SetBackgroundColour('#FFFFFF');
	return 1;
}

sub style_busy {
	my $self = shift;
	$self->SetBackgroundColour('#CCCCCC');
	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

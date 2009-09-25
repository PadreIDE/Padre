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

our $VERSION = '0.47';
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
	$self->set_font;

	# see #351: output should be blank by default at startup.
	#$self->AppendText( Wx::gettext('No output') );

	return $self;
}

sub bottom {
	$_[0]->GetParent;
}

sub main {
	$_[0]->GetGrandParent;
}

sub current {
	Padre::Current->new( main => $_[0]->main );
}

sub gettext_label {
	Wx::gettext('Output');
}





#####################################################################
# Process Execution

# If this is the first time a command has been run,
# set up the ProcessStream bindings.
sub setup_bindings {
	my $self = shift;

	if ($Wx::Perl::ProcessStream::VERSION) {
		return 1;
	}

	require Wx::Perl::ProcessStream;
	Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDOUT(
		$self,
		sub {
			$_[1]->Skip(1);
			$_[0]->style_neutral;
			$_[0]->AppendText( $_[1]->GetLine . "\n" );
			return;
		},
	);

	Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_STDERR(
		$self,
		sub {
			$_[1]->Skip(1);
			$_[0]->style_bad;
			$_[0]->AppendText( $_[1]->GetLine . "\n" );
			return;
		},
	);

	Wx::Perl::ProcessStream::EVT_WXP_PROCESS_STREAM_EXIT(
		$self,
		sub {
			$_[1]->Skip(1);
			$_[1]->GetProcess->Destroy;
			$_[0]->current->main->menu->run->enable;
		},
	);

	return 1;
}





#####################################################################
# General Methods

# From Sean Healy on wxPerl mailing list.
# Tweaked to avoid strings copying as much as possible.
sub AppendText {
	my $self     = shift;
	my $use_ansi = $self->main->ide->config->main_output_ansi;
	if ( utf8::is_utf8( $_[0] ) ) {
		if ($use_ansi) {
			$self->_handle_ansi_escapes( $_[0] );
		} else {
			$self->SUPER::AppendText( $_[0] );
		}
	} else {
		my $text = Encode::decode( 'utf8', $_[0] );
		if ($use_ansi) {
			$self->_handle_ansi_escapes($text);
		} else {
			$self->SUPER::AppendText($text);
		}
	}
	return ();
}

SCOPE: {

	# TODO: This should be some sort of style file,
	# but the main editor style support is too wacky
	# to add this at the moment.
	my $fg_colors = [
		Wx::Colour->new('#000000'), # black
		Wx::Colour->new('#FF0000'), # red
		Wx::Colour->new('#00FF00'), # green
		Wx::Colour->new('#FFFF00'), # yellow
		Wx::Colour->new('#0000FF'), # blue
		Wx::Colour->new('#FF00FF'), # magenta
		Wx::Colour->new('#00FFFF'), # cyan
		Wx::Colour->new('#FFFFFF'), # white
		undef,
		Wx::Colour->new('#000000'), # reset to default (black)
	];
	my $bg_colors = [
		Wx::Colour->new('#000000'), # black
		Wx::Colour->new('#FF0000'), # red
		Wx::Colour->new('#00FF00'), # green
		Wx::Colour->new('#FFFF00'), # yellow
		Wx::Colour->new('#0000FF'), # blue
		Wx::Colour->new('#FF00FF'), # magenta
		Wx::Colour->new('#00FFFF'), # cyan
		Wx::Colour->new('#FFFFFF'), # white
		undef,
		Wx::Colour->new('#FFFFFF'), # reset to default (white)
	];

	sub _handle_ansi_escapes {
		my $self    = shift;
		my $newtext = shift;

		# read the next TEXT CONTROL-SEQUENCE pair
		my $style      = $self->GetDefaultStyle;
		my $ansi_found = 0;
		while ( $newtext =~ m{ \G (.*?) \033\[ ( (?: \d+ (?:;\d+)* )? ) m }xcg ) {
			$ansi_found = 1;
			my $ctrl = $2;

			# first print the text preceding the control sequence
			$self->SUPER::AppendText($1);

			# split the sequence on ; -- this may be specific to the graphics 'm' sequences, but
			# we don't handle any others at the moment (see regexp above)
			my @cmds = split /;/, $ctrl;

			foreach my $cmd (@cmds) {
				if ( $cmd >= 0 and $cmd < 30 ) {

					# for all these, we need the font object:
					my $font = $style->GetFont;
					if ( $cmd == 0 ) { # reset
						$style->SetTextColour( $fg_colors->[9] );       # reset text color
						$style->SetBackgroundColour( $bg_colors->[9] ); # reset bg color
						                                                # reset bold/italic/underlined state
						$font->SetWeight(Wx::wxFONTWEIGHT_NORMAL);
						$font->SetUnderlined(0);
						$font->SetStyle(Wx::wxFONTSTYLE_NORMAL);
					} elsif ( $cmd == 1 ) {                             # bold
						$font->SetWeight(Wx::wxFONTWEIGHT_BOLD);
					} elsif ( $cmd == 2 ) {                             # faint
						$font->SetWeight(Wx::wxFONTWEIGHT_LIGHT);
					} elsif ( $cmd == 3 ) {                             # italic
						$font->SetStyle(Wx::wxFONTSTYLE_ITALIC);
					} elsif ( $cmd == 4 || $cmd == 21 ) {               # underline (21==double, but we can't do that)
						$font->SetUnderlined(1);
					} elsif ( $cmd == 22 ) {                            # reset bold and faint
						$font->SetWeight(Wx::wxFONTWEIGHT_NORMAL);
					} elsif ( $cmd == 24 ) {                            # reset underline
						$font->SetUnderlined(0);
					}
					$style->SetFont($font);
				}

				# the high range is supposed to be 'high intensity' as supported by aixterm
				elsif ( $cmd >= 30 && $cmd < 40 or $cmd >= 90 && $cmd < 100 ) {

					# foreground
					$cmd -= $cmd > 40 ? 90 : 30;
					my $color = $fg_colors->[$cmd];
					if ( defined $color ) {
						$style->SetTextColour($color);
						$self->SetDefaultStyle($style);
					}
				}

				# the high range is supposed to be 'high intensity' as supported by aixterm
				elsif ( $cmd >= 40 && $cmd < 50 or $cmd >= 100 && $cmd < 110 ) {

					# background
					$cmd -= $cmd > 50 ? 100 : 40;
					my $color = $bg_colors->[$cmd];
					if ( defined $color ) {
						$style->SetBackgroundColour($color);
					}
				}

				$self->SetDefaultStyle($style);
			} # end foreach command in the sequence
		} # end while more control sequences

		# the remaining text
		if ( defined( pos($newtext) ) ) {
			$self->SUPER::AppendText( substr( $newtext, pos($newtext) ) );
		}
		unless ($ansi_found) {
			$self->SUPER::AppendText($newtext);
		}
	}
}

sub select {
	my $self   = shift;
	my $parent = $self->GetParent;
	$parent->SetSelection( $parent->GetPageIndex($self) );
	return;
}

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
	$self->Refresh;
	return 1;
}

sub style_good {
	$_[0]->SetBackgroundColour('#CCFFCC');
	$_[0]->Refresh;
}

sub style_bad {
	$_[0]->SetBackgroundColour('#FFCCCC');
	$_[0]->Refresh;
}

sub style_neutral {
	$_[0]->SetBackgroundColour('#FFFFFF');
	$_[0]->Refresh;
}

sub style_busy {
	$_[0]->SetBackgroundColour('#CCCCCC');
	$_[0]->Refresh;
}

sub set_font {
	my $self   = shift;
	my $config = $self->main->config;
	my $font   = Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL );
	if ( defined $config->editor_font && length $config->editor_font > 0 ) { # empty default...
		$font->SetNativeFontInfoUserDesc( $config->editor_font );
	}
	my $style = $self->GetDefaultStyle;
	$style->SetFont($font);
	$self->SetDefaultStyle($style);

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

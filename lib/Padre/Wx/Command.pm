package Padre::Wx::Command;

# Class for the command window at the bottom of Padre.
# This currently has very little customisation code in it,
# but that will change in future.

use 5.008;
use strict;
use warnings;
use utf8;
use Encode                ();
use File::Spec            ();
use Params::Util          ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.68';
our @ISA     = qw{
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::TextCtrl
};


######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	# Create the underlying object
	my $self = $class->SUPER::new(
		$panel,
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
			Wx::wxTE_DONTWRAP
			| Wx::wxNO_FULL_REPAINT_ON_RESIZE,
	);

	# Do custom start-up stuff here
	#$self->clear;
	#$self->set_font;

	Wx::Event::EVT_TEXT_ENTER( $self, $main, 
		sub {
			shift->text_entered(@_);
		},
	);

	return $self;
}


######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	shift->main->show_command_line(0);
}



######################################################################
# Event Handlers

sub text_entered {
	my ($self, $event) = @_;

	my $text = $self->GetRange(0, $self->GetLastPosition);
	#$self->Clear;
	#$self->out(">> $text\n");
	print STDERR "Text: $text\n";
	
	# TODO catch stdout, stderr
	#my $out = eval $text;
	#my $error = $@;
	#if (defined $out) {
		#$self->out("$out\n");
	#}
	#if ($error) {
		#$self->out("$@\n");
	#}
}



#####################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Command');
}


sub select {
	my $self   = shift;
	my $parent = $self->GetParent;
	$parent->SetSelection( $parent->GetPageIndex($self) );
	return;
}

sub clear {
	my $self = shift;
	#$self->SetBackgroundColour('#FFFFFF');
	#$self->Remove( 0, $self->GetLastPosition );
	#$self->Refresh;
	return 1;
}


sub relocale {
	# do nothing
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

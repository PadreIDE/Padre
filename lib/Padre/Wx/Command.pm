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
	Wx::SplitterWindow
};


######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;

	my $self = $class->SUPER::new(
		$panel, -1, Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxNO_FULL_REPAINT_ON_RESIZE|Wx::wxCLIP_CHILDREN );
	
	my $output = Wx::TextCtrl->new
      ( $self, -1, "", Wx::wxDefaultPosition, Wx::wxDefaultSize,
        Wx::wxTE_READONLY|Wx::wxTE_MULTILINE|Wx::wxNO_FULL_REPAINT_ON_RESIZE );

	my $input = Wx::TextCtrl->new
      ( $self, -1, "", Wx::wxDefaultPosition, Wx::wxDefaultSize,
        Wx::wxNO_FULL_REPAINT_ON_RESIZE|Wx::wxTE_PROCESS_ENTER );

	$self->{_output_} = $output;
	$self->{_input_}  = $input;

	# Do custom start-up stuff here
	#$self->clear;
	#$self->set_font;

	Wx::Event::EVT_TEXT_ENTER( $main, $input, sub {
		$self->text_entered(@_)
	});
	my $height = $main->{bottom}->GetSize->GetHeight;
	$self->SplitHorizontally( $output, $input, $height-120 ); ## TODO ???
	$input->SetFocus;

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
	my ($self, $main, $event) = @_;

	my $text = $self->{_input_}->GetRange(0, $self->{_input_}->GetLastPosition);
	$self->{_input_}->Clear;
	$self->out(">> $text\n");
	my %commands = (
		pwd => 'Print current workind directory',
		ls  => 'List directory',
	);

	if ($text eq 'pwd') {
		require Cwd;
		$self->outn(Cwd::cwd);
	} elsif ($text eq 'ls') {
		require Cwd;
		opendir my $dh, Cwd::cwd;
		foreach my $thing (sort readdir $dh) {
			$self->outn($thing);
		}
	} elsif ($text eq '?') {
		foreach my $cmd (sort keys %commands) {
			$self->outn("$cmd    - $commands{$cmd}");
		}
	} else {
		$self->outn("Invalid command");
	}

	return;
}

sub out {
	my ($self, $text) = @_;
	$self->{_output_}->WriteText($text);
}
sub outn {
	my ($self, $text) = @_;
	$self->{_output_}->WriteText("$text\n");
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

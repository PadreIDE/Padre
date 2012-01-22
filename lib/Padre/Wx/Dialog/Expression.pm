package Padre::Wx::Dialog::Expression;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::FBP::Expression ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::Expression';





######################################################################
# Event Handlers

sub on_combobox {
	return 1;
}

sub on_text {
	my $self  = shift;
	my $event = shift;
	$self->{code}->SetBackgroundColour( Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW) );
	$self->Refresh;
	$event->Skip(1);
}

sub on_text_enter {
	my $self  = shift;
	my $event = shift;
	$self->run;
	$self->Refresh;
	$event->Skip(1);
}

sub on_evaluate {
	my $self  = shift;
	my $event = shift;
	$self->run;
	$self->Refresh;
	$event->Skip(1);
}





######################################################################
# Main Methods

sub run {
	my $self = shift;
	my $code = $self->{code}->GetValue;

	# Reset the expression and blank old output
	$self->{output}->SetValue('');
	$self->{code}->SetBackgroundColour( Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW) );

	# Execute the code and handle errors
	local $@;
	my @rv = eval $code;
	if ($@) {
		$self->error($@);
		return;
	}

	# Dump to the output window
	require Devel::Dumpvar;
	$self->{output}->SetValue( Devel::Dumpvar->new( to => 'return' )->dump(@rv) );
	$self->{output}->SetSelection( 0, 0 );

	# Success
	$self->{code}->SetBackgroundColour( Wx::Colour->new('#CCFFCC') );

	return;
}

sub error {
	$_[0]->{output}->SetValue( $_[1] );
	$_[0]->{code}->SetBackgroundColour( Wx::Colour->new('#FFCCCC') );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

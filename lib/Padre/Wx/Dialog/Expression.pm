package Padre::Wx::Dialog::Expression;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::ScrollLock      ();
use Padre::Wx::Role::Timer     ();
use Padre::Wx::FBP::Expression ();

our $VERSION = '1.00';
our @ISA     = qw{
	Padre::Wx::Role::Timer
	Padre::Wx::FBP::Expression
};





######################################################################
# Event Handlers

sub on_combobox {
	return 1;
}

sub on_text {
	my $self  = shift;
	my $event = shift;
	if ( $self->{watch}->GetValue ) {
		$self->{watch}->SetValue(0);
		$self->watch_clicked;
	}
	$self->{code}->SetBackgroundColour( Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW) );
	$self->Refresh;
	$event->Skip(1);
}

sub on_text_enter {
	my $self  = shift;
	my $event = shift;
	$self->run;
	$event->Skip(1);
}

sub evaluate_clicked {
	my $self  = shift;
	my $event = shift;
	$self->run;
	$event->Skip(1);
}

sub watch_clicked {
	my $self  = shift;
	my $event = shift;
	if ( $self->{watch}->GetValue ) {
		$self->dwell_start( 'watch_timer' => 1000 );
	} else {
		$self->dwell_stop('watch_timer');
	}
	$event->Skip(1) if $event;
}

sub watch_timer {
	my $self  = shift;
	my $event = shift;
	if ( $self->IsShown ) {
		$self->run;
	}
	if ( $self->{watch}->GetValue ) {
		$self->dwell_start( 'watch_timer' => 1000 );
	}
	return;
}





######################################################################
# Main Methods

sub run {
	my $self  = shift;
	my $code  = $self->{code}->GetValue;
	my @locks = (
		Wx::WindowUpdateLocker->new( $self->{code} ),
		Wx::WindowUpdateLocker->new( $self->{output} ),
	);

	# Reset the expression and blank old output
	$self->{code}->SetBackgroundColour( Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW) );

	# Execute the code and handle errors
	local $@;
	my @rv = eval $code;
	if ($@) {
		$self->{output}->SetValue('');
		$self->error($@);
		return;
	}

	# Dump to the output window
	require Devel::Dumpvar;
	$self->{output}->ChangeValue( Devel::Dumpvar->new( to => 'return' )->dump(@rv) );
	unless ( $self->{watch}->GetValue ) {
		$self->{output}->SetSelection( 0, 0 );
	}

	# Success
	$self->{code}->SetBackgroundColour( Wx::Colour->new('#CCFFCC') );
	$self->Refresh;

	return;
}

sub error {
	$_[0]->{output}->SetValue( $_[1] );
	$_[0]->{code}->SetBackgroundColour( Wx::Colour->new('#FFCCCC') );
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

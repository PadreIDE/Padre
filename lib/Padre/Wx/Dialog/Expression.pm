package Padre::Wx::Dialog::Expression;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::FBP::Expression ();

our $VERSION = '0.89';
our @ISA     = 'Padre::Wx::FBP::Expression';

my $BASE_COLOUR = Wx::SystemSettings::GetColour( Wx::wxSYS_COLOUR_WINDOW );
my $EVAL_COLOUR = Wx::Colour->new('#CCFFCC');
my $FAIL_COLOUR = Wx::Colour->new('#FFCCCC');





######################################################################
# Event Handlers

sub on_text {
	my $self  = shift;
	my $event = shift;
	$self->code->SetBackgroundColour($BASE_COLOUR);
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
	my $code = $self->code->GetValue;

	# Reset the expression and blank old output
	$self->output->SetValue('');
	$self->code->SetBackgroundColour($BASE_COLOUR);

	# Execute the code and handle errors
	local $@;
	my @rv = eval $code;
	if ( $@ ) {
		$self->error($@);
		return;
	}

	# Dump to the output window
	require Devel::Dumpvar;
	$self->output->SetValue(
		Devel::Dumpvar->new( to => 'return' )->dump(@rv)
	);
	$self->output->SetSelection( 0, 0 );

	# Success
	$self->code->SetBackgroundColour($EVAL_COLOUR);

	return;
}

sub error {
	$_[0]->output->SetValue($_[1]);
	$_[0]->code->SetBackgroundColour($FAIL_COLOUR);
}

1;

package Padre::Wx::Menu::Run;

# Fully encapsulated Run menu

use 5.008;
use strict;
use warnings;
use Padre::Wx          ();
use Padre::Wx::Submenu ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Wx::Submenu';





#####################################################################
# Padre::Wx::Submenu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Script Execution
	$self->{run_script} = $self->Append( -1, Wx::gettext("Run Script\tF5") );
	Wx::Event::EVT_MENU( $main,
		$self->{run_script},
		sub {
			$_[0]->run_script;
		},
	);

	$self->{run_command} = $self->Append( -1, Wx::gettext("Run Command\tCtrl-F5") );
	Wx::Event::EVT_MENU( $main,
		$self->{run_command},
		sub {
			$_[0]->on_run_command;
		},
	);

	$self->{stop} = $self->Append( -1, Wx::gettext("&Stop") );
	Wx::Event::EVT_MENU( $main,
		$self->{stop},
		sub {
			if ( $_[0]->{command} ) {
				$_[0]->{command}->TerminateProcess;
			}
			delete $_[0]->{command};
			return;
		},
	);

	# Initialise enabled
	$self->enable;

	return $self;
}





#####################################################################
# Custom Methods

sub enable {
	my $self = shift;
	$self->{run_script}->Enable(1);
	$self->{run_command}->Enable(1);
	$self->{stop}->Enable(0);
	return;
}

sub disable {
	my $self = shift;
	$self->{run_script}->Enable(0);
	$self->{run_command}->Enable(0);
	$self->{stop}->Enable(1);
	return;
}

1;

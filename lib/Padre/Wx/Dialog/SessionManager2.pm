package Padre::Wx::Dialog::SessionManager2;

use 5.008;
use strict;
use warnings;
use Padre::DB                      ();
use Padre::Wx::Icon                ();
use Padre::Wx::FBP::SessionManager ();

our $VERSION = '0.93';
our @ISA     = qw{
	Padre::Wx::FBP::SessionManager
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Add the columns for the list
	$self->{list}->InsertColumn( 0, Wx::gettext('Name') );
	$self->{list}->InsertColumn( 1, Wx::gettext('Description') );
	$self->{list}->InsertColumn( 2, Wx::gettext('Last Updated') );

	$self->CenterOnParent;
	return $self;
}





######################################################################
# Event Handlers

1;

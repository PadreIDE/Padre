package Padre::Config::Clear;

# Clear wrapper package intended to break any code
# that is trying to write to the config as a HASH.

use strict;
use warnings;
use Carp         ();
use Scalar::Util ();

our $VERSION = '0.25';

sub new {
	my $class  = ref $_[0] ? ref shift : shift;
	my $object = Scalar::Util::blessed($_[0]) ? shift : return undef;
	my $self   = \$object;
	bless $self, $class;
	return $self;
}

sub isa {
	my $self = shift;
	return ${$self}->isa(@_);
}

sub can {
	my $self = shift;
	return ${$self}->can(@_);
}

sub AUTOLOAD {
	my $self     = shift;
	my ($method) = $Padre::Config::Clear::AUTOLOAD =~ m/^.*::(.*)$/s;
	unless ( ref($self) ) {
		Carp::croak(
			  qq{Can\'t locate object method "$method" via package "$self" }
			. qq{(perhaps you forgot to load "$self")}
		);
	}
	${$self}->$method(@_);
}

sub DESTROY {
	if ( defined ${$_[0]} and ${$_[0]}->can('DESTROY') ) {
		${$_[0]}->DESTROY;
	}
	${$_[0]} = undef;
}

1;

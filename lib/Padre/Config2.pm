package Padre::Config2;

use 5.008;
use strict;
use warnings;
use Carp                   ();
use Params::Util           qw{_INSTANCE};
use Padre::Config::Host    ();
use Padre::Config::User    ();
use Padre::Config::Project ();

our $VERSION = '0.25';

use constant HOST    => 0;
use constant USER    => 1;
use constant PROJECT => 2;





#####################################################################
# Constructor and Accessors

sub new {
	my $class   = shift;
	my $host    = shift;
	my $user    = shift;
	unless ( _INSTANCE($host, 'Padre::Config::Host') ) {
		Carp::croak("Did not provide a host config to Padre::Config2->new");
	}
	unless ( _INSTANCE($user, 'Padre::Config::User') ) {
		Carp::croak("Did not provide a user config to Padre::Config2->new");
	}

	# Create the basic object with the two required elements
	my $self = bless [ $host, $user ], $class;

	# Add the optional third element
	if ( @_ ) {
		my $project = shift;
		unless ( _INSTANCE($project, 'Padre::Config::Project') ) {
			Carp::croak("Did not provide a project config to Padre::Config2->new");
		}
		$self->[PROJECT] = $project;
	}

	return $self;
}

sub read {
	my $class = shift;

	# Load the host configuration
	my $host = Padre::Config::Host->read;

	# Load the user configuration
	die "TO BE COMPLETED";
}

1;

package Padre::Task::Files;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;

our $VERSION = '0.64';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Default expansion-controlling variables
	$self->{recurse} ||= 0;
	$self->{expand}  ||= {};

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	if ( $self->{recurse} ) {
		# Handle recursive mode fairly simplistically
		$self->{files} = [
			File::Find::Rule->file->in( $self->{root} )
		];
	} else {
		# TO BE COMPLETED
		$self->{files} = [ ];
	}

	return 1;
}

1;

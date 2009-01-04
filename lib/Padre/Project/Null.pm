package Padre::Project::Null;

use strict;
use warnings;
use Padre::Project ();

our $VERSION = '0.23';
our @ISA     = 'Padre::Project';

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Check the root directory
	unless ( defined $self->root ) {
		croak("Did not provide a root directory");
	}
	unless ( -d $self->root ) {
		croak("Root directory " . $self->root . " does not exist");
	}

	return $self;
}

sub padre_yml {
	return undef;
}

1;

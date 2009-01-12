package Padre::Config::Host;

# Configuration and state data related to the host that Padre is running on.

use 5.008;
use strict;
use warnings;
use Padre::DB ();

our $VERSION = '0.25';





#####################################################################
# Constructor and Storage Interaction

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

# Read config from the database (overwriting any existing data)
sub read {
	my $class = shift;

	# Read in the config data
	my %hash = map {
		$_->name => $_->value
	} Padre::DB::Hostconf->select;

	# Create and return the object
	return $class->new( %hash );
}

sub write {
	my $self = shift;
	Padre::DB->begin;
	Padre::DB::Hostconf->truncate;
	foreach my $name ( sort keys %$self ) {
		Padre::DB::Hostconf->create(
			name  => $name,
			value => $hash->{$name},
		);
	}
	Padre::DB->commit;
	return 1;
}

1;

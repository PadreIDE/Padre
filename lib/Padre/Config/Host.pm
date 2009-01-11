package Padre::Config::Host;

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
	my $self = shift;
	%$self = map {
		$_->name => $_->value
	} Padre::DB::Hostconf->select;
	return 1;
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

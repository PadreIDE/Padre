package t::files::Debugger;
use strict;
use warnings;

sub new {
	my ($class, %args) = @_;
	my $self = bless \%args, $class;
	
	return $self;
}

sub set_xyz {
	my ($self, $value) = @_;
	$self->{xyz} = $value;
	return;
}

sub get_xyz {
	my ($self) = @_;
	return $self->{xyz};
}

1;

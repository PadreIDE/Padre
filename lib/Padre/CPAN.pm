package Padre::CPAN;

use 5.008;
use strict;
use warnings;
use Carp ();

our $VERSION = '0.43';

use CPAN ();

my $SINGLETON;

sub new {
	my ($class) = @_;
	return $SINGLETON if $SINGLETON;

	my $self = bless {}, $class;
	CPAN::HandleConfig->load(
		be_silent => 1,
	);
	my @modules = map { $_->id } CPAN::Shell->expand( 'Module', '/^/' );
	$self->{modules} = \@modules;

	$SINGLETON = $self;

	return $self;
}

sub get_modules {
	my ( $self, $regex ) = @_;

	$regex ||= '^';
	$regex =~ s/ //g;

	my $MAX_DISPLAY = 100;
	my $i           = 0;
	my @modules;
	foreach my $module ( @{ $self->{modules} } ) {
		next if $module !~ /$regex/;
		$i++;
		last if $i > $MAX_DISPLAY;
		push @modules, $module;
	}
	return \@modules;
}

sub install {
	my ( $self, $module ) = @_;
	CPAN::Shell->install($module);

}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

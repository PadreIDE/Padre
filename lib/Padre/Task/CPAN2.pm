package Padre::Task::CPAN2;

use 5.008005;
use strict;
use warnings;
use Padre::Task ();
use Padre::Logger qw(TRACE);

our $VERSION = '0.91';
our @ISA     = 'Padre::Task';

use constant {
	CPAN_SEARCH  => 'search',
	CPAN_INSTALL => 'install',
};

######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Assert required command parameter
	unless ( defined $self->{command} ) {
		die "Failed to provide a command to the CPAN task\n";
	}

	return $self;
}

######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Create empty model
	$self->{model} = [];

	# Pull things off the task so we won't need to serialize
	# it back up to the parent Wx thread at the end of the task.
	return unless $self->{command};
	my $command = delete $self->{command};
	return unless $self->{query};
	my $query = delete $self->{query};

	if ( $command eq CPAN_SEARCH ) {
		require LWP::UserAgent;
		my $ua = LWP::UserAgent->new;
		$ua->timeout(10);
		$ua->env_proxy;
		my $url      = "https://metacpan.org/search/autocomplete?q=$query";
		my $response = $ua->get($url);
		unless ( $response->is_success ) {
			TRACE( sprintf( "Got '%s for %s", $response->status_line, $url ) )
				if DEBUG;
			return;
		}
		require JSON::XS;
		$self->{model} = JSON::XS::decode_json( $response->decoded_content );
	} elsif ( $command eq CPAN_INSTALL ) {

		#TODO run cpanm module!
	} else {
		TRACE("Unimplemented $command. Please fix!") if DEBUG;
	}

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

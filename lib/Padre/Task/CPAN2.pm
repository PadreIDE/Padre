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
		$self->{model} = $self->metacpan_autocomplete( $query, 10 );
	}
	elsif ( $command eq CPAN_INSTALL ) {

		#TODO run cpanm module!
	}
	else {
		TRACE("Unimplemented $command. Please fix!") if DEBUG;
	}

	return 1;
}

#
# Adopted from https://github.com/CPAN-API/metacpan-web
#
sub metacpan_autocomplete {
	my ( $self, $query, $size ) = @_;

	# Convert :: to spaces so we dont crash request :)
	$query =~ s/::/ /g;

	# Create an array of query keywords that are separated by spaces
	my @query = split( /\s+/, $query );

	# The documentation Module-Name that should be analyzed
	my $should = [
		map {
			{ field   => { 'documentation.analyzed'  => "$_*" } },
			  { field => { 'documentation.camelcase' => "$_*" } }
		  } grep { $_ } @query
	];

	# The distribution we do not want in our search
	my @ROGUE_DISTRIBUTIONS =
	  qw(kurila perl_debug perl-5.005_02+apache1.3.3+modperl pod2texi perlbench spodcxx);

	# The ElasticSearch query in Perl
	my %payload = (
		query => {
			filtered => {
				query => {
					custom_score => {
						query => { bool => { should => $should } },
						script =>
"_score - doc['documentation'].stringValue.length()/100"
					},
				},
				filter => {
					and => [
						{
							not => {
								filter => {
									or => [
										map {
											{ term =>
												  { 'file.distribution' => $_ }
											}
										  } @ROGUE_DISTRIBUTIONS
									]
								}
							}
						},
						{ exists => { field          => 'documentation' } },
						{ term   => { 'file.indexed' => \1 } },
						{ term   => { 'file.status'  => 'latest' } },
						{
							not => {
								filter =>
								  { term => { 'file.authorized' => \0 } }
							}
						}
					]
				}
			}
		},
		fields => [qw(documentation release author distribution)],
		size   => $size,
	);

	# Convert ElasticSearch Perl query to a JSON request
	require JSON::XS;
	my $json_request = JSON::XS::encode_json( \%payload );

	# POST the json request to api.metacpan.org
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new( agent => "Padre/$VERSION" );
	$ua->timeout(10);
	$ua->env_proxy;
	my $response = $ua->post( 'http://api.metacpan.org/v0/file/_search',
		Content => $json_request, );

	unless ( $response->is_success ) {
		TRACE( sprintf( "Got '%s' from metacpan.org", $response->status_line ) )
		  if DEBUG;
		return [];
	}

	# Decode json response then cleverly map it for the average joe :)
	my $data = JSON::XS::decode_json( $response->decoded_content );
	my @results = map { $_->{fields} } @{ $data->{hits}->{hits} || [] };

	# And return its reference
	return \@results;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

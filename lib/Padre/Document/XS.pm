package Padre::Document::XS;

use 5.008;
use strict;
use warnings;
use Padre::Document ();

our $VERSION = '0.50';
our @ISA     = 'Padre::Document';

# TODO better highlighting. Can vim do better? Can we steal? Add an STC highlighter? ...

sub keywords {
	my $self = shift;

	if ( not defined $self->{_perlapi_keywords} ) {
		$self->_load_perlapi_keywords();
	}
	return $self->{_perlapi_keywords};
}


# This loads the perlapi keywords for calltips
# It first tries to use the Perl::APIReference module which has perlapi references
# for many, many releases of perl. It fetches the desired perlapi version from the
# project configuration and uses the newest if not configured. Then, it asks the
# Perl::APIReference for the index of keywords. Since this can fail at various levels,
# we fall back to reading the perlapi keywords from an included YAML file if necessary
# --Steffen
sub _load_perlapi_keywords {
	my $self = shift;
	
	if (not eval "use Perl::APIReference 0.03; 1;") {
		$self->{_perlapi_keywords} =
			YAML::Tiny::LoadFile( Padre::Util::sharefile( 'languages', 'perl5', 'perlapi_current.yml' ) );
		return;
	}

	my $perl_version = $self->{_perlapi_version};
	
	if (not defined $perl_version) {
		my $project = $self->project;
		if (defined $project) {
			$perl_version = 'newest';
			my $cfg = $project->config;
			$perl_version = $cfg->xs_calltips_perlapi_version();
		}
		else {
			$perl_version = Padre->ide->config->xs_calltips_perlapi_version();
		}
		$self->{_perlapi_version} = $perl_version;
	}
	
	my $apiref = eval {Perl::APIReference->new(perl_version => $perl_version)};
	if (not $apiref) {
		# fallback...
		$self->{_perlapi_keywords} =
			YAML::Tiny::LoadFile( Padre::Util::sharefile( 'languages', 'perl5', 'perlapi_current.yml' ) );
		return;
	}
	
	# TODO: Perl::APIReference also provides an "index" method, but that doesn't return the structure
	#       in exactly the way we want it. Easy way out: Add an accessor to Perl::APIReference that
	#       returns an API structure akin to what would be returned by loading the YAML.
	require YAML::Tiny;
	$self->{_perlapi_keywords} = YAML::Tiny::Load($apiref->as_yaml_calltips);
	return;
}


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

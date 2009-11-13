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

	if (not defined $self->{_perlapi_keywords}) {
		# TODO support for multiple perlapi versions...
		$self->{_perlapi_keywords} = YAML::Tiny::LoadFile( Padre::Util::sharefile( 'languages', 'perl5', 'perlapi_current.yml' ) );
	}
	return $self->{_perlapi_keywords};
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

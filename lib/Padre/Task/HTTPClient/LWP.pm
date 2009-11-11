package Padre::Task::HTTPClient::LWP;

use 5.008;
use strict;
use warnings;
use Params::Util qw{_CODE _INSTANCE};
use Padre::Task::HTTPClient;

our $VERSION = '0.50';
our @ISA     = 'Padre::Task::HTTPClient';

=pod

=head1 NAME

Padre::Task::HTTPClient::LWP - Generic HTTP client processing task using L<LWP>

=head1 SYNOPSIS

=head1 DESCRIPTION

Sending and receiving data via HTTP.

See L<Padre::Task::HTTPClient> for details.

This module uses "require" instead of "use" to load the required modules

	LWP::UserAgent
	HTTP::Request

because it need to be loaded without failing on dependencies which are no
global Padre dependencies.

=cut

sub new {
	my $class = shift;
	my %args  = @_;

	# These modules are no and should be no global Padre dependency, if they're
	# installed, use this module, otherwise another one needs to do the job:
	eval {
		require LWP::UserAgent;
		require HTTP::Request;
	};

	my $self = bless {@_}, $class;

	$self->{_UA} = LWP::UserAgent->new();
	$self->{_UA}->timeout(60); # TO DO: Make this configurable
	$self->{_UA}->env_proxy;

	return $self;

}

sub run {
	my $self = shift;

	# content (POST data) and query (GET data) may be passed as hash ref's
	# and they're converted automatically:
	for my $var ( 'query', 'content' ) {
		next unless ref( $self->{$var} ) eq 'HASH';
		$self->{$var} = join(
			'&',
			map {
				my $value = $self->{$var}->{$_} || '';
				$value =~ s/(\W)/"%".uc(unpack("H*",$1))/ge;
				$value =~ s/\%20/\+/g;
				$_ . '=' . $value;
				} ( keys( %{ $self->{$var} } ) )
		);
	}

	$self->{query} = '?' . $self->{query} if defined( $self->{query} );

	my $Request = HTTP::Request->new( $self->{method}, $self->{URL} . $self->{query} );

	if ( $self->{method} eq 'POST' ) {
		$Request->content_type( $self->{content_type} || 'application/x-www-form-urlencoded' );
		$Request->content( $self->{content} );
	}

	$Request->header( %{ $self->{header} } )
		if defined( $self->{header} )
			and ( ref( $self->header ) eq 'HASH' );

	my $Result = $self->{_UA}->request($Request);

	if ( $Result->is_success ) {
		if (wantarray) {
			return $Result->content, $Result;
		} else {
			return $Result->content;
		}
	} else {
		if (wantarray) {
			return undef, $Result;
		} else {
			return;
		}
	}

}

1;

__END__

=head1 SEE ALSO

This class inherits from C<Padre::Task::HTTPClient>.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

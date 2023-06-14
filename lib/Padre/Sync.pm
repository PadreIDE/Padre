package Padre::Sync;

=pod

=head1 NAME

Padre::Sync - Utility functions for handling remote Configuration Syncing

=head1 DESCRIPTION

The C<Padre::Sync> class contains logic for communicating with a remote 
L<Madre::Sync> server. This class interacts with the
L<Padre::Wx::Dialog::Sync> class for user interface display.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp                  ();
use File::Spec            ();
use Scalar::Util          ();
use Params::Util          ();
use JSON::XS              ();
use LWP::UserAgent        ();
use HTTP::Cookies         ();
use HTTP::Request::Common ();
use Padre::Current        ();
use Padre::Constant       ();

our $VERSION    = '1.02';
our $COMPATIBLE = '0.95';





#####################################################################
# Constructor and Accessors

=pod

=head2 C<new>

The constructor returns a new C<Padre::Sync> object, but
you should normally access it via the main Padre object:

  my $manager = Padre->ide->config_sync;

First argument should be a Padre object.

=cut

sub new {
	my $class = shift;
	my $ide = Params::Util::_INSTANCE( shift, 'Padre' );
	Carp::croak("Failed to create Padre::Sync") unless $ide;

	# Create the useragent.
	# We need this to handle login actions.
	# Save cookies for state management from Padre session to session
	# NOTE: Is this even wanted? Remove at padre close?
	my $ua = LWP::UserAgent->new(
		timeout    => 10,
		cookie_jar => HTTP::Cookies->new(
			file => File::Spec->catfile(
				Padre::Constant::CONFIG_DIR,
				'lwp_cookies.dat',
			),
			autosave => 1,
		)
	);

	my $self = bless {
		ide   => $ide,
		state => 'not_logged_in',
		ua    => $ua,
		@_,
	}, $class;

	return $self;
}

=pod

=head2 C<main>

A convenience method to get to the main window.

=cut

sub main {
	$_[0]->{ide}->wx->main;
}

=pod

=head2 C<config>

A convenience method to get to the config object

=cut

sub config {
	$_[0]->{ide}->config;
}

=pod

=head2 C<ua> 

A convenience method to get to the useragent object

=cut 

sub ua {
	$_[0]->{ua};
}

=pod

=head2 C<register>

Attempts to register a user account with the information provided on the
Sync server. 

Parameters: a list of key value pairs to be interpreted as POST parameters

Returns error string if user state is already logged in or serverside error
occurs.

=cut

sub register {
	my $self   = shift;
	my %params = @_;

	if ( $self->{state} ne 'not_logged_in' ) {
		return 'Failure: cannot register account, user already logged in.';
	}

	# BUG: This crashes if server is unavailable.
	my $server = $self->server or return 'Failure: no server found.';
	my $response = $self->POST(
		"$server/register",
		'Content-Type' => 'application/json',
		'Content'      => $self->encode( \%params ),
	);
	if ( $response->code == 201 ) {
		return 'Account registered successfully. Please log in.';
	}

	local $@;
	my $h = eval { $self->decode( $response->content ); };

	return "Registration failure(Server): $h->{error}" if $h->{error};
	return "Registration failure(Padre): $@" if $@;
	return "Registration failure(unknown)";
}

=pod

=head2 C<login>

Will log in to remote Sync server using given credentials. State will 
be updated if login successful.

=cut

sub login {
	my $self = shift;

	if ( $self->{state} ne 'not_logged_in' ) {
		return 'Failure: cannot log in, user already logged in.';
	}

	my $server = $self->server or return 'Failure: no server found.';
	my $response = $self->POST( "$server/login", [ {@_} ] );
	if ( $response->content !~ /Wrong username or password/i
		and ( $response->code == 200 or $response->code == 302 ) )
	{
		$self->{state} = 'logged_in';
		return 'Logged in successfully.';
	}

	return 'Login Failure.';
}

=pod

=head2 C<logout>

If currently logged in, will log the Sync session out from the server.
State will be updated.

=cut

sub logout {
	my $self = shift;

	if ( $self->{state} ne 'logged_in' ) {
		return 'Failure: cannot logout, user not logged in.';
	}

	my $server = $self->server or return 'Failure: no server found.';
	my $response = $self->GET("$server/logout");
	if ( $response->code == 200 ) {
		$self->{state} = 'not_logged_in';
		return 'Logged out successfully.';
	}

	return 'Failed to log out.';
}

=pod

=head2 C<server_delete>

Given a logged in session, will attempt to delete the config currently
stored on the Sync server (if one currently exists).
Will fail if not logged in.

=cut

sub server_delete {
	my $self = shift;

	if ( $self->{state} ne 'logged_in' ) {
		return 'Failure: user not logged in.';
	}

	my $server = $self->server or return 'Failure: no server found.';
	my $response = $self->DELETE("$server/config");
	if ( $response->code == 204 ) {
		return 'Configuration deleted successfully.';
	}

	return 'Failed to delete serverside configuration file.';

}

=pod

=head2 C<local_to_server>

Given a logged in session, will attempt to place the current local config to 
the Sync server. 

=cut

sub local_to_server {
	my $self = shift;

	if ( $self->{state} ne 'logged_in' ) {
		return 'Failure: user not logged in.';
	}

	# NOTE: There has be a better way to do this
	my $conf     = $self->config->human;
	my %copy     = %$conf;
	my $server   = $self->server or return 'Failure: no server found.';
	my $response = $self->PUT(
		"$server/config",
		'Content-Type' => 'application/json',
		'Content'      => $self->encode( \%copy ),
	);
	if ( $response->code == 204 ) {
		return 'Configuration uploaded successfully.';
	}

	return 'Failed to upload configuration file to server.';
}

=pod

=head2 C<server_to_local>

Given a logged in session, will replace the local config with what is stored
on the server. 
TODO: is validation of config before replacement required?

=cut

sub server_to_local {
	my $self = shift;

	if ( $self->{state} ne 'logged_in' ) {
		return 'Failure: user not logged in.';
	}

	my $server = $self->server or return 'Failure: no server found.';
	my $response = $self->GET(
		"$server/config",
		'Accept' => 'application/json',
	);

	local $@;
	my $json;
	eval { $json = $self->decode( $response->content ); };
	return 'Failed to deserialize serverside configuration.' if $@;

	# Apply each setting to the global config. should only be HUMAN
	# settings.
	delete $json->{Version};
	delete $json->{version};
	my @errors;
	my $config = $self->config;
	for my $key ( keys %$json ) {
		my $meta = eval { $config->meta($key); };
		unless ( $meta and $meta->store == Padre::Constant::HUMAN ) {

			# Skip unknown or non-HUMAN settings
			next;
		}
		eval { $config->apply( $key, $json->{$key} ); };
		push @errors, $@ if $@;
	}
	$config->write;

	if ( $response->code == 200 && @errors == 0 ) {
		return 'Configuration downloaded and applied successfully.';
	} elsif ( $response->code == 200 && @errors ) {
		warn @errors;
		return 'Configuration downloaded successfully, some errors encountered applying to your current configuration.';
	}

	return 'Failed to download serverside configuration file to local Padre instance.';
}

=pod

=head2 C<english_status>

Will return a string explaining current state of Sync
dependent on $self->{state}

=cut

sub english_status {
	my $self = shift;
	return 'User is not currently logged into the system.' if $self->{state} eq 'not_logged_in';
	return 'User is currently logged into the system.'     if $self->{state} eq 'logged_in';
	return "State unknown: $self->{state}";
}





######################################################################
# Support Methods

sub encode {
	JSON::XS->new->encode( $_[1] );
}

sub decode {
	JSON::XS->new->decode( $_[1] );
}

sub server {
	my $self   = shift;
	my $server = $self->config->config_sync_server;
	$server =~ s/\/$// if $server;
	return $server;
}

sub GET {
	shift->ua->request( HTTP::Request::Common::GET(@_) );
}

sub POST {
	shift->ua->request( HTTP::Request::Common::POST(@_) );
}

sub PUT {
	shift->ua->request( HTTP::Request::Common::PUT(@_) );
}

sub DELETE {
	shift->ua->request( HTTP::Request::Common::DELETE(@_) );
}

1;

=pod

=head1 SEE ALSO

L<Padre>, L<Padre::Config>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2016 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

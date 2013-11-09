package Padre::ServerManager;

# Second generation Padre sync client, which operates via background tasks
# and is not bound tightly to any front end GUI objects.

use 5.008;
use strict;
use warnings;
use Carp                ();
use File::Spec          ();
use JSON::XS            ();
use Padre::Constant     ();
use Padre::Role::Task   ();
use Padre::Role::PubSub ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';
our @ISA        = qw{
	Padre::Role::Task
	Padre::Role::PubSub
};

# Subscribable Events
use constant {
	SERVER_VERSION => 'server_version',
	SERVER_ERROR   => 'server_error',
	LOGIN_SUCCESS  => 'login_success',
	LOGIN_FAILURE  => 'login_failure',
	PUSH_SUCCESS   => 'push_success',
	PUSH_FAILURE   => 'push_failure',
	PULL_SUCCESS   => 'pull_success',
	PULL_FAILURE   => 'pull_failure',
};




######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = bless {
		@_,
		version => undef,
		user    => undef,
	}, $class;

	# Check and default params
	unless ( $self->{ide} ) {
		Carp::croak("Did not provide ide param to Padre::ServerManager");
	}

	return $self;
}

sub server {
	$_[0]->{server};
}

sub user {
	$_[0]->{user};
}





######################################################################
# Server Discovery

sub version {
	my $self = shift;

	# Reset task state and send the request
	$self->task_reset;
	$self->task_get(
		on_finish => 'version_finish',
		url       => 'version',
	);
}

sub version_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);
	unless ( $json ) {
		return $self->publish( SERVER_ERROR, $response );
	}

	$self->{server} = $json->{server};
	$self->publish( SERVER_VERSION );
}





######################################################################
# Login Task

sub login {
	my $self = shift;

	# Do we have the things we need
	my $config   = $self->config;
	my $email    = $config->identity_email       or return undef;
	my $password = $config->config_sync_password or return undef;

	# Reset task state and send the request
	$self->task_reset;
	$self->task_post(
		on_finish => 'login_finish',
		url       => 'login',
		query     => {
			email    => $email,
			password => $password,
		},
	);
}

sub login_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);

	# Handle the positive case first, it is simpler
	if ( $json ) {
		$self->{user} = $json->{user};
		$self->publish( LOGIN_SUCCESS );
		return 1;
	}

	# Handle the failed login case
	$self->publish( LOGIN_FAILURE );
}





######################################################################
# Registration Task

sub register {
	my $self = shift;

	# Do we have the things we need
	my $config   = $self->config;
	my $email    = $config->identity_email       or return undef;
	my $password = $config->config_sync_password or return undef;

	# Reset task state and send the request
	$self->task_reset;
	$self->task_post(
		on_finish => 'register_finish',
		url       => 'register',
		query     => {
			email    => $email,
			password => $password,
		},
	);
}

sub register_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);

	# TODO: To be completed

	$self->publish("on_register", $response);
}





######################################################################
# Configuration Pull Task

sub pull {
	my $self     = shift;
	my $config   = $self->config;
	my $email    = $config->identity_email       or return undef;
	my $password = $config->config_sync_password or return undef;

	# Fetch the server configuration
	$self->task_reset;
	$self->task_get(
		on_finish => 'pull_finish',
		url       => 'config',
		query     => {
			email    => $email,
			password => $password,
		},
	);

	return 1;
} 

sub pull_finish {
	my $self     = shift;
	my $config   = $self->config;
	my $response = shift->response;
	my $json     = $self->decode($response);
	unless ( $json ) {
		return $self->publish( PULL_FAILURE );
	}

	# Apply the server settings to the current instance
	my $server = $json->{config}->{data};
	if (Params::Util::_HASH0($server)) {
		foreach my $name ( $config->settings ) {
			my $meta = $config->meta($name);
			if ($meta->store == Padre::Constant::HUMAN) {
				if (exists $server->{$name}) {
					$config->apply($name, $server->{$name});
				} else {
					$config->apply($name, $config->default($name));
				}
			}
		}
	}

	return $self->publish( PULL_SUCCESS, $json->{config} );
}





######################################################################
# Configuration Push Task

sub push {
	my $self = shift;

	# Do we have the things we need
	my $config   = $self->config;
	my $email    = $config->identity_email       or return undef;
	my $password = $config->config_sync_password or return undef;

	# Send configuration to the server
	$self->task_reset;
	$self->task_post(
		on_finish => 'push_finish',
		url       => 'config',
		query     => {
			email    => $email,
			password => $password,
			data     => $self->encode( $self->config->human->as_hash ),
		},
	);

	return 1;
}

sub push_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);
	unless ( $json ) {
		return $self->publish( PUSH_FAILURE );
	}

	return $self->publish( PUSH_SUCCESS, $json->{config} );
}





######################################################################
# Configuration Delete Task

sub delete {
	my $self = shift;

	# Delete configuration from the server
	$self->task_reset;
	$self->task_delete(
		on_finish => 'delete_finish',
		url       => 'config',
	);

	return 1;
}

sub delete_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);

	# TODO: To be completed

	$self->publish("on_delete", $response);
}





######################################################################
# Logout Task

sub logout {
	my $self = shift;

	# Allow a logout action no matter what state we are in
	$self->task_reset;
	$self->task_get(
		on_finish => 'logout_finish',
		url       => 'logout',
	);

	return 1;
}

sub logout_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);

	# TODO: To be completed

	$self->publish("on_logout", $response);
}





######################################################################
# Telemetry Task

sub telemetry {
	my $self = shift;

	# Don't reset, telemetry occurs in parallel
	$self->task_post(
		on_finish => 'telemetry_finish',
		url       => 'telemetry',
	);
}

sub telemetry_finish {
	my $self     = shift;
	my $response = shift->response;
	my $json     = $self->decode($response);

	# TODO: To be completed

	$self->publish("on_telemetry", $response);
}





######################################################################
# Padre::Task::LWP Integration

sub task_get {
	shift->task_request(
		method => 'GET',
		@_,
	);
}

sub task_delete {
	shift->task_request(
		method => 'DELETE',
		@_,
	);
}

sub task_post {
	my $self  = shift;
	my %param = @_;
	if ( $param{query} and $param{content_type} and $param{content_type} eq 'text/json' ) {
		$param{query} = $self->encode($param{query});
	}

	$self->task_request(
		method => 'POST',
		%param,
	);
}

sub task_request {
	my $self   = shift;
	my $server = $self->baseurl or return;
	my %param  = @_;
	my $url    = join( '/', $server, delete $param{url} ) . '.json';
	$self->SUPER::task_request(
		%param,
		task => 'Padre::Task::LWP',
		url  => $url,
	);
}

sub baseurl {
	my $self   = shift;
	my $server = $self->config->config_sync_server;
	$server =~ s/\/$// if $server;
	return $server;
}

sub config {
	$_[0]->{ide}->config;
}

sub encode {
	require JSON::XS;
	JSON::XS->new->encode( $_[1] );
}

sub decode {
	my $self     = shift;
	my $response = shift or return undef;

	require HTTP::Response;
	$response->is_success or return undef;

	local $@;
	my $json = eval {
		require JSON::XS;
		JSON::XS->new->decode( $response->decoded_content );
	};
	if ( $@ or not $json ) {
		return undef;
	}
	return $json;
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

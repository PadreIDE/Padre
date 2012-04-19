package Padre::ServerManager;

# Second generation Padre sync client, which operates via background tasks
# and is not bound tightly to any front end GUI objects.

use 5.008;
use strict;
use warnings;
use Carp              ();
use File::Spec        ();
use Padre::Constant   ();
use Padre::Role::Task ();

our $VERSION    = '0.96';
our $COMPATIBLE = '0.95';
our @ISA        = 'Padre::Role::Task';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = bless {
		@_,
		state   => 'LOGOUT',
		version => undef,
	}, $class;

	# Check and default params
	unless ( $self->{ide} ) {
		Carp::croak("Did not provide ide param to Padre::ServerManager");
	}
	unless ( $self->{cookie_file} ) {
		$self->{cookie_file} = File::Spec->catfile(
			Padre::Constant::CONFIG_DIR,
			'lwp_cookies.dat',
		);
	}

	return $self;
}





######################################################################
# Server Discovery

sub version {
	my $self = shift;
	unless ( $self->{state} eq 'LOGOUT' ) {

		# Not sure what to do with this...
		return undef;
	}

	# Reset task state and send the request
	$self->task_reset;
	$self->task_get(
		url       => 'version',
		on_finish => 'version_finish',
	);
}

sub version_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Login Task

sub login {
	my $self = shift;

	unless ( $self->{state} eq 'LOGOUT' ) {

		# Not sure what to do with this...
		return undef;
	}

	# Reset task state and send the request
	$self->task_reset;
	$self->task_post(
		url       => 'login',
		query     => {},            # TODO: stuff
		on_finish => 'login_finish',
	);
}

sub login_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Registration Task

sub register {
	my $self = shift;

	# Reset task state and send the request
	$self->task_reset;
	$self->task_post(
		url       => 'register',
		query     => {},               # TODO: stuff
		on_finish => 'register_finish',
	);
}

sub register_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Configuration Pull Task

sub pull {
	my $self = shift;

	# Fetch the server configuration
	$self->task_reset;
	$self->task_get(
		url       => 'config',
		on_finish => 'pull_finish',
	);

	return 1;
}

sub pull_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Configuration Push Task

sub push {
	my $self = shift;

	# Send configuration to the server
	$self->task_reset;
	$self->task_put(
		url       => 'config',
		on_finish => 'push_finish',
	);

	return 1;
}

sub push_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Configuration Delete Task

sub delete {
	my $self = shift;

	# Delete configuration from the server
	$self->task_reset;
	$self->task_delete(
		url       => 'config',
		on_finish => 'delete_finish',
	);

	return 1;
}

sub delete_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Logout Task

sub logout {
	my $self = shift;

	# Allow a logout action no matter what state we are in
	$self->task_reset;
	$self->task_get(
		url       => 'logout',
		on_finish => 'logout_finish',
	);

	return 1;
}

sub logout_finish {
	my $self = shift;

	#my $response = shift->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Telemetry Task

sub telemetry {
	my $self = shift;

	# Don't reset, telemetry occurs in parallel
	$self->task_post(
		url       => 'telemetry',
		on_finish => 'telemetry_finish',
	);
}

sub telemetry_finish {
	my $self = shift;

	#my $response = $self->response or return;

	# TODO: To be completed

	return 1;
}





######################################################################
# Padre::Task::LWP Integration

sub task_get {
	shift->task_request(
		method => 'GET',
		@_,
	);
}

sub task_put {
	shift->task_request(
		method => 'GET',
		@_,

		# TODO: Document content here
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
	my $query = delete $param{query};
	$query = $self->encode($query) if $query;

	$self->task_request(
		method => 'POST',
		query  => $query,
		@_,
	);
}

sub task_request {
	my $self   = shift;
	my $server = $self->server or return;
	my %param  = @_;
	my $url    = join( '/', $server, delete $param{url} );
	$self->SUPER::task_request(
		%param,
		task        => 'Padre::Task::LWP',
		url         => $url,
		cookie_file => $self->{cookie_file},
	);
}

sub server {
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
	require JSON::XS;
	JSON::XS->new->decode( $_[1] );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

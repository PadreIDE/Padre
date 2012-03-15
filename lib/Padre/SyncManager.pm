package Padre::SyncManager;

# Second generation Padre sync client, which operates via background tasks
# and is not bound tightly to any front end GUI objects.

use 5.008;
use strict;
use warnings;
use Carp              ();
use File::Spec        ();
use Padre::Constant   ();
use Padre::Role::Task ();

our $VERSION    = '0.95';
our $COMPATIBLE = '0.95';
our @ISA        = 'Padre::Role::Task';





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = bless {
		@_,
		state => 'LOGOUT',
	}, $class;

	# Check and default params
	unless ( $self->{ide} ) {
		Carp::croak("Did not provide ide param to Padre::SyncManager");
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
		query     => { }, # TODO: stuff
		on_finish => 'login_finish',
	);
}

sub login_finish {
	my $self = shift;

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

	# TODO: To be completed

	return 1;
}





######################################################################
# Support Methods

sub config {
	$_[0]->{ide}->config;
}

sub server {
	my $self   = shift;
	my $server = $self->config->config_sync_server;
	$server =~ s/\/$// if $server;
	return $server;
}

sub task_get {
	my $self   = shift;
	my $server = $self->server or return;
	my $url    = join( '/', $server, shift );

	# Hand off to the normal task method
	$self->task_request(
		task        => 'Padre::Task::LWP',
		cookie_file => $self->{cookie_file},
		method      => 'GET',
		url         => $url,
	);
}

sub task_delete {
	my $self = shift;
	my $server = $self->server or return;
	my $url    = join( '/', $server, shift );

	# Hand off to the normal task method
	$self->task_request(
		task        => 'Padre::Task::LWP',
		cookie_file => $self->{cookie_file},
		method      => 'DELETE',
		url         => $url,
	);
}

1;

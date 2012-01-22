package Padre::Wx::Dialog::Sync;

use 5.008;
use strict;
use warnings;
use Padre::Sync          ();
use Padre::Wx::FBP::Sync ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Wx::FBP::Sync';

sub new {
	my $class  = shift;
	my $self   = $class->SUPER::new(@_);
	my $config = $self->config;

	# Fill form elements from configuration
	$self->{txt_remote}->SetValue( $config->config_sync_server );
	$self->{txt_login}->SetFocus;
	$self->{txt_login}->SetValue( $config->config_sync_username );
	$self->{txt_password}->SetValue( $config->config_sync_password );

	# registration prefill
	$self->{txt_username}->SetValue( $config->identity_nickname );
	$self->{txt_email}->SetValue( $config->identity_email );
	$self->{txt_email_confirm}->SetValue( $config->identity_email );

	# Create the sync manager
	$self->{sync} = Padre::Sync->new( $self->ide );

	# Update form to match sync manager
	$self->refresh;

	return $self;
}

sub refresh {
	my $self = shift;
	my $sync = $self->{sync};

	# Set up the form from the sync manager
	$self->{lbl_status}->SetLabel( $self->{sync}->english_status );

	# Are we logged in?
	my $in = $sync->{state} eq 'logged_in' ? 1 : 0;
	$self->{btn_login}->SetLabel( $in ? 'Logout' : 'Login' );
	$self->{btn_local}->Enable($in);
	$self->{btn_remote}->Enable($in);
	$self->{btn_delete}->Enable($in);

	return 1;
}





######################################################################
# Event Handlers

sub btn_login {
	my $self = shift;
	my $sync = $self->{sync};

	my $server = $self->{txt_remote}->GetValue;
	if ( $server ne $self->config->config_sync_server ) {
		$self->config->apply( 'config_sync_server' => $server );
	}

	my $username = $self->{txt_login}->GetValue;
	my $password = $self->{txt_password}->GetValue;

	# Handle login / logout logic toggle
	if ( $sync->{state} eq 'logged_in' ) {
		if ( $sync->logout =~ /success/ ) {
			Wx::MessageBox(
				sprintf('Successfully logged out.'),
				Wx::gettext('Error'),
				Wx::OK,
				$self,
			);
			$self->{btn_login}->SetLabel('Log in');
		} else {
			Wx::MessageBox(
				sprintf('Failed to log out.'),
				Wx::gettext('Error'),
				Wx::OK,
				$self,
			);
		}

		$self->{lbl_status}->SetLabel( $sync->english_status );
		return;
	}

	if ( not $username or not $password ) {
		Wx::MessageBox(
			sprintf( Wx::gettext('Please input a valid value for both username and password') ),
			Wx::gettext('Error'),
			Wx::OK,
			$self,
		);
		return;
	}

	# Attempt login
	my $rc = $sync->login(
		{   username => $username,
			password => $password,
		}
	);

	$self->refresh;

	# Print the return information
	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::OK,
		$self,
	);

}

sub btn_register {
	my $self          = shift;
	my $username      = $self->{txt_username}->GetValue;
	my $pw            = $self->{txt_pw}->GetValue;
	my $pw_confirm    = $self->{txt_pw_confirm}->GetValue;
	my $email         = $self->{txt_email}->GetValue;
	my $email_confirm = $self->{txt_email_confirm}->GetValue;

	# Validation of inputs
	if (   not $username
		or not $pw
		or not $pw_confirm
		or not $email
		or not $email_confirm )
	{
		Wx::MessageBox(
			sprintf( Wx::gettext('Please ensure all inputs have appropriate values.') ),
			Wx::gettext('Error'),
			Wx::OK,
			$self,
		);
		return;
	}

	# Not sure if password quality rules should be enforced at this level?
	if ( $pw ne $pw_confirm ) {
		Wx::MessageBox(
			sprintf( Wx::gettext('Password and confirmation do not match.') ),
			Wx::gettext('Error'),
			Wx::OK,
			$self,
		);
		return;
	}

	if ( $email ne $email_confirm ) {
		Wx::MessageBox(
			sprintf( Wx::gettext('Email and confirmation do not match.') ),
			Wx::gettext('Error'),
			Wx::OK,
			$self,
		);
		return;
	}

	# Attempt registration
	my $rc = $self->{sync}->register(
		{   username         => $username,
			password         => $pw,
			password_confirm => $pw_confirm,
			email            => $email,
			email_confirm    => $email_confirm,
		}
	);

	# Print the return information
	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::OK,
		$self,
	);
}

sub btn_local {
	my $self = shift;
	my $rc   = $self->{sync}->local_to_server;
	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::OK,
		$self,
	);
}

sub btn_remote {
	my $self = shift;
	my $rc   = $self->{sync}->server_to_local;
	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::OK,
		$self,
	);
}

sub btn_delete {
	my $self = shift;
	my $rc   = $self->{sync}->server_delete;
	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::OK,
		$self,
	);

}

# Save changes to dialog inputs to config
sub btn_ok {
	my $self   = shift;
	my $config = $self->current->config;

	# Save the server access defaults
	$config->set( config_sync_server   => $self->{txt_remote}->GetValue );
	$config->set( config_sync_username => $self->{txt_login}->GetValue );
	$config->set( config_sync_password => $self->{txt_password}->GetValue );

	$self->Destroy;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

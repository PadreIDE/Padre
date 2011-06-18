package Padre::Wx::Dialog::ModuleStarter;

use 5.008;
use strict;
use warnings;
use Padre::Wx::Role::Config       ();
use Padre::Wx::FBP::ModuleStarter ();

our $VERSION = '0.86';
our @ISA     = qw{
	Padre::Wx::Role::Config
	Padre::Wx::FBP::ModuleStarter
};





######################################################################
# Class Methods

sub run {
	my $class  = shift;
	my $main   = shift;
	my $self   = $class->new($main);
	my $config = $main->config;

	# Load preferences
	$self->config_load(
		$config, qw{
			identity_name
			identity_email
			module_starter_directory
			module_starter_builder
			module_starter_license
			}
	);

	# Show the dialog
	$self->Fit;
	$self->CentreOnParent;
	if ( $self->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}

	# Save preferences
	$self->config_save(
		$config, qw{
			module_starter_directory
			module_starter_builder
			module_starter_license
			}
	);

	# Generate the distribution
	### TO BE COMPLETED

	# Clean up
	$self->Destroy;
	return 1;
}





######################################################################
# Constructor and Accessors

sub new {
	my $self = shift->SUPER::new(@_);

	# Focus on the module name
	$self->module->SetFocus;

	return $self;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


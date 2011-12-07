package Padre::Wx::Dialog::PluginManager2;

use 5.008;
use strict;
use warnings;
use Padre::Wx::Icon ();
use Padre::Wx::FBP::PluginManager ();

our $VERSION = '0.93';
our @ISA     = 'Padre::Wx::FBP::PluginManager';





######################################################################
# Class Methods

sub run {
	my $class = shift;
	my $self  = $class->new(@_);
	$self->ShowModal;
	$self->Destroy;
	return 1;
}





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Do an initial refresh of the plugin list
	$self->refresh;

	# Select the first plugin and focus on the list
	if ( $self->{list}->GetCount ) {
		$self->{list}->Select(0);
	}
	$self->{list}->SetFocus;

	# Prepare to be shown
	$self->SetSize( [ 750, 500 ] );
	$self->CenterOnParent;

	return $self;
}

sub refresh {
	my $self = shift;
	my $list = $self->{list};

	# Clear the existing list data
	$list->Clear;

	# Fill the list from the plugin handles
	foreach my $handle ( $self->ide->plugin_manager->handles ) {
		$list->Append( $handle->plugin_name );
	}

	return 1;
}





######################################################################
# Event Handlers

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

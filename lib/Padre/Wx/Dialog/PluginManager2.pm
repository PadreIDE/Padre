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
	my $list  = $self->{list};

	# This is a core dialog so apply the Padre icon
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Make the heading fonts larger
	$self->{plugin_name}->SetFont(
		Wx::Font->new( Wx::NORMAL_FONT->GetPointSize + 4, 70, 90, 92, 0, "" )
	);
	$self->{plugin_status}->SetFont(
		Wx::Font->new( Wx::NORMAL_FONT->GetPointSize + 4, 70, 90, 92, 0, "" )
	);

	# Do an initial refresh of the plugin list
	$self->refresh;

	# Select the first plugin and focus on the list
	$list->Select(0) if $list->GetCount;
	$list->SetFocus;

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
		$list->Append( $handle->plugin_name, $handle->class );
	}

	return 1;
}

sub refresh_details {
	my $self   = shift;
	my $handle = $self->selected or return;

	# Update the header fields
	$self->{plugin_name}    = $handle->plugin_name;
	$self->{plugin_version} = $handle->version;

	return 1;
}





######################################################################
# Event Handlers





######################################################################
# Support Methods

sub selected {
	my $self = shift;

	# Find the selection
	my $list = $self->{list};
	my $item = $list->GetSelection;
	return if $item == Wx::NOT_FOUND;

	# Load the plugin handle for the selection
	my $module = $list->GetClientData($item);
	$self->ide->plugin_manager->handle($module);
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

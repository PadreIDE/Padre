package Padre::Wx::Dialog::PluginManager;

use 5.008;
use strict;
use warnings;
use Padre::Wx::Icon ();
use Padre::Wx::FBP::PluginManager ();
use Padre::Locale::T;

our $VERSION = '0.94';
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

	# Prepare to be shown
	$self->SetSize( [ 750, 500 ] );
	$self->CenterOnParent;

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

	# Show the details for the selected plugin
	$self->refresh_plugin;

	return $self;
}





######################################################################
# Event Handlers

sub refresh_plugin {
	my $self   = shift;
	my $handle = $self->selected or return;

	# Update the basic fields
	SCOPE: {
		my $lock = $self->lock_update;

		# Update the details fields
		$self->{plugin_name}->SetLabel( $handle->plugin_name );
		$self->{plugin_version}->SetLabel( $handle->plugin_version );
		$self->{plugin_status}->SetLabel( $handle->status_localized );

		# Only show the preferences button if the plugin has them
		if ( $handle->plugin_can('plugin_preferences') ) {
			$self->{preferences}->Show;
		} else {
			$self->{preferences}->Hide;
		}

		# Update the action button
		if ( $handle->error or $handle->incompatible ) {
			$self->{action}->{method} = 'explain_selected';
			$self->{action}->SetLabel( Wx::gettext('&Show Error Message') );
			$self->{action}->Enable;
			$self->{preferences}->Disable;

		} elsif ( $handle->enabled ) {
			$self->{action}->{method} = 'disable_selected';
			$self->{action}->SetLabel( Wx::gettext('&Disable') );
			$self->{action}->Enable;
			$self->{preferences}->Disable;

		} elsif ( $handle->can_enable ) {
			$self->{action}->{method} = 'enable_selected';
			$self->{action}->SetLabel( Wx::gettext('&Enable') );
			$self->{action}->Enable;
			$self->{preferences}->Enable;

		} else {
			$self->{action}->{method} = 'enable_selected';
			$self->{action}->SetLabel( Wx::gettext('&Enable') );
			$self->{action}->Disable;
			$self->{preferences}->Disable;
		}

		# Update the layout for the changed interface
		$self->{details}->Layout;
	}

	# Find the documentation
	require Padre::Browser;
	my $browser = Padre::Browser->new;
	my $class   = $handle->class;
	my $doc     = $browser->resolve($class);

	# Render the documentation.
	# TODO Convert this to a background task later
	local $@;
	my $output = eval { $browser->browse($doc) };
	my $html   = $@
		? sprintf(
			Wx::gettext("Error loading pod for class '%s': %s"),
			$class,
			$@,
		)
		: $output->body;
	$self->{whtml}->SetPage($html);

	return 1;
}

sub action_clicked {
	my $self   = shift;
	my $method = $self->{action}->{method} or return;
	$self->$method();
}

sub preferences_clicked {
	my $self   = shift;
	my $handle = $self->selected or return;

	$handle->plugin_preferences;
}





######################################################################
# Main Methods

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

sub enable_selected {
	my $self   = shift;
	my $handle = $self->selected or return;
	my $lock   = $self->main->lock( 'DB', 'refresh_menu_plugins' );
	$self->ide->plugin_manager->user_enable($handle);
	$self->refresh_plugin;
}

sub disable_selected {
	my $self   = shift;
	my $handle = $self->selected or return;
	my $lock   = $self->main->lock( 'DB', 'refresh_menu_plugins' );
	$self->ide->plugin_manager->user_disable($handle);
	$self->refresh_plugin;
}

sub explain_selected {
	my $self    = shift;
	my $handle  = $self->selected or return;

	# @INC gets printed out between () remove that for now
	my $message = $handle->errstr;
	$message =~ s/\(\@INC.*\)//;

	# Show the message box
	Wx::MessageBox(
		$message,
		Wx::gettext('Error'),
		Wx::OK | Wx::CENTRE,
		$self,
	);
}





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


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::PluginManager - Padre Plug-in Manager Dialog

=head1 SYNOPSIS

  Padre::Wx::Dialog::PluginManager->run($main);

=head1 DESCRIPTION

Padre will have a lot of plug-ins. First plug-in manager was not taking
this into account, and the first plug-in manager window was too small &
too crowded to show them all properly.

This revamped plug-in manager is now using a list control, and thus can
show lots of plug-ins in an effective manner.

Upon selection, the right pane will be updated with the plug-in name &
plug-in documentation. Two buttons will allow to de/activate the plug-in
(or see plug-in error message) and set plug-in preferences.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

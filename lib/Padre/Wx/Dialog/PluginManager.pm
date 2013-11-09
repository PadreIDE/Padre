package Padre::Wx::Dialog::PluginManager;

use 5.010;
use strict;
use warnings;
no if $] > 5.017010, warnings => 'experimental::smartmatch';

use Padre::Wx::Util               ();
use Padre::Wx::Icon               ();
use Padre::Wx::FBP::PluginManager ();
use Padre::Locale::T;
use Try::Tiny;

our $VERSION = '1.00';
our @ISA     = 'Padre::Wx::FBP::PluginManager';


use constant {
	RED        => Wx::Colour->new('red'),
	DARK_GREEN => Wx::Colour->new( 0x00, 0x90, 0x00 ),
	BLUE       => Wx::Colour->new('blue'),
	GRAY       => Wx::Colour->new('gray'),
	DARK_GRAY  => Wx::Colour->new( 0x7f, 0x7f, 0x7f ),
	BLACK      => Wx::Colour->new('black'),
};


######################################################################
# Class Methods
#####
sub run {
	my $class = shift;
	my $self  = $class->new(@_);
	$self->ShowModal;
	$self->Destroy;
	return 1;
}


######################################################################
# Constructor
#####
sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	$self->{handle} = 'empty';

	# This is a core dialog so apply the Padre icon
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Prepare to be shown
	$self->SetSize( [ 760, 480 ] );
	$self->CenterOnParent;

	# TODO Active should be droped, just on show for now
	# Setup columns names, Active should be droped, just and order here
	# my @column_headers = qw( Path Line Active ); do not remove
	my @column_headers = ( 'Plug-in Name', 'Version', 'Status', 'Plug-in Class' );
	my $index = 0;
	for my $column_header (@column_headers) {
		$self->{list}->InsertColumn( $index++, Wx::gettext($column_header) );
	}

	# Select the first item in CrtList
	$self->{list_focus} = 0;

	# Image List
	$self->{imagelist} = Wx::ImageList->new( 16, 16, 1 );
	$self->{list}->AssignImageList(
		$self->{imagelist},
		Wx::IMAGE_LIST_SMALL,
	);

	# Do an initial refresh of the plugin list_two
	$self->refresh;
	$self->refresh_plugin;

	return $self;
}



######################################################################
# Event Handlers

sub refresh_plugin {
	my $self = shift;

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
	my $class   = $handle->class // 'Padre::Plugin::My';
	my $doc     = $browser->resolve($class);

	# Render the documentation.
	# TODO Convert this to a background task later
	local $@;
	my $output = eval { $browser->browse($doc) };
	my $html =
		$@
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
	my $self = shift;

	# say 'in action_clicked';
	my $method = $self->{action}->{method} or return;

	# p $method;

	# p $self->$method();
	$self->$method();
}

sub preferences_clicked {
	my $self = shift;

	my $handle = $self->selected or return;

	# p $handle;

	# my $handle = $self->handle or return;
	$handle->plugin_preferences;
}


######################################################################
# Main Methods

sub refresh {
	my $self = shift;

	# Clear image list & fill it again
	$self->{imagelist}->RemoveAll;

	# Default plug-in icon
	$self->{imagelist}->Add( Padre::Wx::Icon::find('status/padre-plugin') );

	# Clear ListCtrl items
	$self->{list}->DeleteAllItems;

	my $index = 0;

	# Fill the list_two from the plugin handles
	foreach my $handle ( $self->ide->plugin_manager->handles ) {
		if ( $self->{handle} eq 'empty' ) {
			if ( $handle->plugin_name eq 'My Plugin' ) {
				$self->{handle} = $handle;
			}
		}

		# Check if plug-in is supplying its own icon
		my $position = 0;
		my $icon     = $handle->plugin_icon;
		if ( defined $icon ) {
			$self->{imagelist}->Add($icon);
			$position = $self->{imagelist}->GetImageCount - 1;
		}

		# Inserting the plug-in in the list
		$self->{list}->InsertStringImageItem(
			$index,
			$handle->plugin_name,
			$position,
		);

		given ( $handle->status ) {
			when ( $_ eq 'enabled' )      { $self->{list}->SetItemTextColour( $index, BLUE ); }
			when ( $_ eq 'disabled' )     { $self->{list}->SetItemTextColour( $index, BLACK ); }
			when ( $_ eq 'incompatible' ) { $self->{list}->SetItemTextColour( $index, DARK_GRAY ); }
			when ( $_ eq 'error' )        { $self->{list}->SetItemTextColour( $index, RED ); }
		}

		# $self->{list}->SetItem( $index,   0, $handle->plugin_name );
		$self->{list}->SetItem( $index, 1, $handle->plugin_version || '???' );
		$self->{list}->SetItem( $index, 2, $handle->status );
		$self->{list}->SetItem( $index++, 3, $handle->class );

		# Tidy the list
		Padre::Wx::Util::tidy_list( $self->{list} );
	}

	# Select the current list item
	if ( $self->{list}->GetItemCount > 0 ) {
		$self->{list}->SetItemState( $self->{list_focus}, Wx::LIST_STATE_SELECTED, Wx::LIST_STATE_SELECTED );
		$self->{list}->EnsureVisible( $self->{list_focus} );
	}

	return 1;
}


sub enable_selected {
	my $self = shift;

	my $handle = $self->selected or return;
	my $lock = $self->main->lock( 'DB', 'refresh_menu_plugins' );

	$self->ide->plugin_manager->user_enable($handle);
	$self->refresh;
	$self->refresh_plugin;
}

sub disable_selected {
	my $self = shift;

	my $handle = $self->selected or return;
	my $lock = $self->main->lock( 'DB', 'refresh_menu_plugins' );

	$self->ide->plugin_manager->user_disable($handle);
	$self->refresh;
	$self->refresh_plugin;
}

sub explain_selected {
	my $self = shift;

	my $handle = $self->selected or return;

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

#######
# Event Handler _on_list_item_selected
#######
sub _on_list_item_selected {
	my $self  = shift;
	my $event = shift;
	$self->{list_focus} = $event->GetIndex; # zero based

	my $plugin_name = $event->GetText;
	my $module_name;

	# Find the plugin module given plugin name
	foreach my $handle ( $self->ide->plugin_manager->handles ) {
		if ( $handle->plugin_name eq $plugin_name ) {
			$module_name = $handle->class;
		}
	}

	$self->{handle} = $self->ide->plugin_manager->handle($module_name);
	$self->refresh_plugin;

	return 1;

}



######################################################################
# Support Methods

sub selected {
	my $self = shift;

	if ( defined $self->{handle} ) {
		return $self->{handle};
	} else {
		return 0;
	}
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

This revamped plug-in manager is now using a list_two control, and thus can
show lots of plug-ins in an effective manner.

Upon selection, the right pane will be updated with the plug-in name &
plug-in documentation. Two buttons will allow to de/activate the plug-in
(or see plug-in error message) and set plug-in preferences.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

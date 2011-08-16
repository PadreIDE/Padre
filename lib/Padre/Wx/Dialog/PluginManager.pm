package Padre::Wx::Dialog::PluginManager;

# The Plug-in Manager GUI for Padre

use 5.008;
use strict;
use warnings;
use Carp                  ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};





######################################################################
# Constructor

sub new {
	my $class   = shift;
	my $main    = shift;
	my $manager = shift;

	# Create the basic object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Plug-in Manager'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# Set some internal parameters
	$self->{sortcolumn}  = 0;
	$self->{sortreverse} = 0;

	# Set basic dialog properties
	$self->SetIcon(Padre::Wx::Icon::PADRE);
	$self->SetMinSize( [ 750, 550 ] );

	# Store plug-in manager
	$self->{manager} = $manager;
	unless ( $manager->isa('Padre::PluginManager') ) {
		Carp::croak("Missing or invalid Padre::PluginManager object");
	}

	# Dialog Controls

	# Create the plug-in list
	$self->{list} = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT
			| Wx::wxLC_SINGLE_SEL,
	);
	$self->{list}->InsertColumn( 0, Wx::gettext('Name') );
	$self->{list}->InsertColumn( 1, Wx::gettext('Version') );
	$self->{list}->InsertColumn( 2, Wx::gettext('Status') );
	Wx::Event::EVT_LIST_ITEM_SELECTED(
		$self,
		$self->{list},
		sub {
			shift->list_item_selected(@_);
		},
	);
	Wx::Event::EVT_LIST_ITEM_ACTIVATED(
		$self,
		$self->{list},
		sub {
			shift->button_main;
		},
	);
	Wx::Event::EVT_LIST_COL_CLICK(
		$self,
		$self->{list},
		sub {
			shift->list_col_click(@_);
		},
	);

	# Image List
	$self->{imagelist} = Wx::ImageList->new( 16, 16 );
	$self->{list}->AssignImageList(
		$self->{imagelist},
		Wx::wxIMAGE_LIST_SMALL,
	);

	# Plug-in Name Header
	$self->{label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('Plug-in Name'),
	);
	my $font = $self->{label}->GetFont;
	$font->SetWeight(Wx::wxFONTWEIGHT_BOLD);
	$font->SetPointSize( $font->GetPointSize + 4 );
	$self->{label}->SetFont($font);

	# Plug-in Documentation HTML Window
	require Padre::Wx::HtmlWindow;
	$self->{whtml} = Wx::HtmlWindow->new($self);

	# Enable/Disable Button
	$self->{button_main} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		Wx::gettext('&Enable'),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_main},
		sub {
			$_[0]->button_main;
		},
	);

	# Preferences Button
	$self->{button_preferences} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext('&Preferences'),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_preferences},
		sub {
			$_[0]->button_preferences;
		},
	);

	# Close Button
	$self->{button_close} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext('&Close'),
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_close},
		sub {
			$_[0]->button_close;
		},
	);

	# Dialog Layout

	# Horizontal button sizer
	my $buttons = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{button_main},        0, Wx::wxALL, 1 );
	$buttons->Add( $self->{button_preferences}, 0, Wx::wxALL, 1 );
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{button_close}, 0, Wx::wxALL, 1 );
	$buttons->AddStretchSpacer;

	# Horizontal plug-in name positioning
	my $header = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$header->AddStretchSpacer;
	$header->Add( $self->{label}, 0, Wx::wxEXPAND | Wx::wxALIGN_CENTER, 1 );
	$header->AddStretchSpacer;

	# Vertical layout of the right hand side
	my $right = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$right->Add( $header, 0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$right->Add(
		$self->{whtml},
		1,
		Wx::wxALL | Wx::wxALIGN_TOP | Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxEXPAND,
		1
	);
	$right->Add( $buttons, 0, Wx::wxALL | Wx::wxEXPAND, 1 );

	# Main sizer
	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizer->Add( $self->{list}, 0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$sizer->Add( $right,        1, Wx::wxALL | Wx::wxEXPAND, 1 );

	# Tune the size and position it appears
	$self->SetSizer($sizer);
	$self->Fit;
	$self->CentreOnParent;

	$self->{list}->SetFocus;

	return $self;
}

# -- public methods

sub show {
	my $self = shift;

	$self->_update_list;

	# select first item in the list. we don't need to test if
	# there's at least a plug-in, since there will always be
	# 'my plug-in'
	my $item = $self->{list}->GetItem(0);
	$item->SetState(Wx::wxLIST_STATE_SELECTED);
	$self->{list}->SetItem($item);

	$self->Show;
}

# GUI Handlers

#
# $self->list_item_selected( $event );
#
# handler called when a list item has been selected. it will in turn update
# the right part of the frame.
#
# $event is a Wx::ListEvent.
#
sub list_item_selected {
	my $self     = shift;
	my $event    = shift;
	my $fullname = $event->GetLabel;
	my $module   = $self->{plugin_class}->{$fullname};
	my $plugin   = $self->{manager}->plugins->{$module};
	$self->{plugin} = $plugin;          # storing selected plug-in
	$self->{row}    = $event->GetIndex; # storing selected row

	# Updating plug-in name in right pane
	$self->{label}->SetLabel( $plugin->plugin_name );

	# Update plug-in documentation
	require Padre::Browser;
	my $browser = Padre::Browser->new;
	my $class   = $plugin->class;
	my $doc     = $browser->resolve($class);
	my $output  = eval { $browser->browse($doc) };
	my $html =
		$@
		? sprintf( Wx::gettext("Error loading pod for class '%s': %s"), $class, $@ )
		: $output->body;
	$self->{whtml}->SetPage($html);

	# Update buttons
	$self->_update_plugin_state;

	# force window to recompute layout. indeed, changes are that plug-in
	# name has a different length, and thus should be recentered.
	$self->Layout;
}

#
# $self->list_col_click;
#
# handler called when a column has been clicked, to reorder the list.
#
sub list_col_click {
	my $self     = shift;
	my $event    = shift;
	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sortcolumn};
	my $reversed = $self->{sortreverse};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sortcolumn}  = $column;
	$self->{sortreverse} = $reversed;
	$self->_update_list;
}

#
# $self->button_main;
#
# handler called when the first button has been clicked.
#
sub button_main {
	my $self = shift;

	# find method to call
	my $method = $self->{action};

	# call method
	$self->$method();
}

#
# $self->button_preferences;
#
# handler called when the preferences button has been clicked.
#
sub button_preferences {
	my $self = shift;
	eval { $self->{plugin}->object->plugin_preferences; };
	if ($@) {
		$self->{plugin}->errstr($@);
		$self->show_error_message;
	}
}

#
# $self->button_close;
#
# handler called when the close button has been clicked.
#
sub button_close {
	$_[0]->Destroy;
}

#
# $self->_plugin_disable;
#
# Disable plug-in, and update GUI.
#
sub _plugin_disable {
	my $self   = shift;
	my $lock   = $self->main->lock( 'UPDATE', 'DB', 'refresh_menu_plugins' );
	my $plugin = $self->{plugin}->class;

	# disable plug-in
	Padre::DB::Plugin->update_enabled( $plugin => 0 );
	$self->{manager}->plugin_disable($plugin);

	# Update plug-in manager dialog to reflect new state
	$self->_update_plugin_state;
}

#
# $self->_plugin_enable;
#
# Enable plug-in, and update GUI.
#
sub _plugin_enable {
	my $self   = shift;
	my $lock   = $self->main->lock( 'UPDATE', 'DB', 'refresh_menu_plugins' );
	my $plugin = $self->{plugin}->class;

	# Enable plug-in
	Padre::DB::Plugin->update_enabled( $plugin => 1 );
	$self->{manager}->plugin_enable($plugin);

	# Update plug-in manager dialog to reflect new state
	$self->_update_plugin_state;
}

#
# $self->show_error_message;
#
# show plug-in error message, in an error dialog box.
#
sub show_error_message {
	my $self    = shift;
	my $message = $self->{plugin}->errstr;
	my $title   = Wx::gettext('Error');

	# @INC gets printed out between () remove that for now
	$message =~ s/\(\@INC.*\)//;

	Wx::MessageBox( $message, $title, Wx::wxOK | Wx::wxCENTER, $self );
}

#
# $dialog->_update_list;
#
# refresh list of plug-ins and their associated state. list is sorted
# according to current sort criterion.
#
sub _update_list {
	my $self = shift;

	# Clear image list & fill it again
	$self->{imagelist}->RemoveAll;

	# Default plug-in icon
	$self->{imagelist}->Add( Padre::Wx::Icon::find('status/padre-plugin') );
	my %icon = ( plugin => 0 );

	# Plug-in status
	my $i = 0;
	foreach my $name (
		qw{
		enabled
		disabled
		error
		crashed
		incompatible
		}
		)
	{
		$self->{imagelist}->Add( Padre::Wx::Icon::find("status/padre-plugin-$name") );
		$icon{$name} = ++$i;
	}

	# Get list of plug-ins, and sort it. Note that $self->{manager}->plugins
	# names is sorted (with my plug-in first), and that perl sort is now
	# stable: sorting on another criterion will keep the alphabetical order
	# if new criterion is not enough.
	my $plugins = $self->{manager}->plugins;
	my @plugins = map { $plugins->{$_} } $self->{manager}->plugin_order;
	if ( $self->{sortcolumn} == 1 ) {

		#		no warnings;
		# We see ??? in the version field for modules that don't have a version number or were not loaded
		@plugins =
			map  { $_->[0] }
			sort { $a->[1] <=> $b->[1] }
			map  { [ $_, version->new( ( $_->version && $_->version ne '???' ) || 0 ) ] } @plugins;
	}
	if ( $self->{sortcolumn} == 2 ) {
		@plugins = sort { $a->status cmp $b->status } @plugins;
	}
	if ( $self->{sortreverse} ) {
		@plugins = reverse @plugins;
	}

	# Clear plug-in list & fill it again
	my $idx          = -1;
	my %plugin_class = ();
	$self->{list}->DeleteAllItems;
	foreach my $plugin (@plugins) {
		$plugin_class{ $plugin->plugin_name } = $plugin->class;

		# Check if plug-in is supplying its own icon
		my $position = 0;
		my $icon     = $plugin->plugin_icon;
		if ( defined $icon ) {
			$self->{imagelist}->Add($icon);
			$position = $self->{imagelist}->GetImageCount - 1;
		}

		# Inserting the plug-in in the list
		$self->{list}->InsertStringImageItem(
			++$idx,
			$plugin->plugin_name,
			$position,
		);
		$self->{list}->SetItem(
			$idx, 1,
			$plugin->version || '???'
		);
		$self->{list}->SetItem(
			$idx, 2,
			$plugin->status_localized,
			$icon{ $plugin->status },
		);
	}

	# Store mapping of full plug-in names / short plug-in names
	$self->{plugin_class} = \%plugin_class;

	# Auto-resize columns
	foreach ( 0 .. 2 ) {
		$self->{list}->SetColumnWidth( $_, Wx::wxLIST_AUTOSIZE );
	}

	# Making sure the list can show all columns
	my $width = 15; # Taking vertical scrollbar into account
	foreach ( 0 .. 2 ) {
		$width += $self->{list}->GetColumnWidth($_);
	}
	$self->{list}->SetMinSize( [ $width, -1 ] );

	return;
}

#
# $dialog->_update_plugin_state;
#
# Update button caption & state, as well as status icon in the list,
# depending on the new plug-in state.
#
sub _update_plugin_state {
	my $self   = shift;
	my $plugin = $self->{plugin};

	# my $list   = $self->{list};
	# my $item   = $list->GetItem( $self->{row}, 2 );

	# Updating buttons
	my $button_main        = $self->{button_main};
	my $button_preferences = $self->{button_preferences};

	if ( $plugin->error ) {

		# Plug-in is in error state
		$self->{action} = 'show_error_message';
		$button_main->SetLabel( Wx::gettext('&Show error message') );
		$button_preferences->Disable;
		$self->{list}->SetItem( $self->{row}, 2, Wx::gettext('error'), 3 );

		# $item->SetText( Wx::gettext('error') );
		# $item->SetImage(3);
		# $list->SetItem($item);

	} elsif ( $plugin->incompatible ) {

		# Plugin is incompatible
		$self->{action} = 'show_error_message';
		$button_main->SetLabel( Wx::gettext('&Show error message') );
		$button_preferences->Disable;
		$self->{list}->SetItem( $self->{row}, 2, Wx::gettext('incompatible'), 5 );

		# $item->SetText( Wx::gettext('incompatible') );
		# $item->SetImage(5);
		# $list->SetItem($item);

	} else {

		# Plug-in is working...
		if ( $plugin->enabled ) {

			# ...and enabled
			$self->{action} = '_plugin_disable';
			$button_main->SetLabel( Wx::gettext('&Disable') );
			$button_main->Enable;
			$self->{list}->SetItem( $self->{row}, 2, Wx::gettext('enabled'), 1 );

			# $item->SetText( Wx::gettext('enabled') );
			# $item->SetImage(1);
			# $list->SetItem($item);

		} elsif ( $plugin->can_enable ) {

			# ...and disabled
			$self->{action} = '_plugin_enable';
			$button_main->SetLabel( Wx::gettext('&Enable') );
			$button_main->Enable;
			$self->{list}->SetItem( $self->{row}, 2, Wx::gettext('disabled'), 2 );

			# $item->SetText( Wx::gettext('disabled') );
			# $item->SetImage(2);
			# $list->SetItem($item);

		} else {

			# ...disabled but cannot be enabled
			$button_main->Disable;
		}

		# Updating preferences button
		if ( $plugin->object->can('plugin_preferences') ) {
			$button_preferences->Enable;
		} else {
			$button_preferences->Disable;
		}
	}

	# Update the list item
	# $self->_update_list;

	# Force window to recompute layout. indeed, changes are that plug-in
	# name has a different length, and thus should be recentered.
	$self->Layout;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog::PluginManager - Plug-in manager dialog for Padre

=head1 DESCRIPTION

Padre will have a lot of plug-ins. First plug-in manager was not taking
this into account, and the first plug-in manager window was too small &
too crowded to show them all properly.

This revamped plug-in manager is now using a list control, and thus can
show lots of plug-ins in an effective manner.

Upon selection, the right pane will be updated with the plug-in name &
plug-in documentation. Two buttons will allow to de/activate the plug-in
(or see plug-in error message) and set plug-in preferences.

Double-clicking on a plug-in in the list will de/activate it.

=head1 PUBLIC API

=head2 Constructor

=over 4

=item * my $dialog = P::W::D::PM->new( $parent, $manager )

Create and return a new Wx dialog listing all the plug-ins. It needs a
C<$parent> window and a C<Padre::PluginManager> object that really
handles Padre plug-ins under the hood.

=back

=head2 Public methods

=over 4

=item * $dialog->show;

Request the plug-in manager dialog to be shown. It will be refreshed
first with a current list of plug-ins with their state.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

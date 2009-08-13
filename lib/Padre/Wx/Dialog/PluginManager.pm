package Padre::Wx::Dialog::PluginManager;

# The Plugin Manager GUI for Padre

use strict;
use warnings;
use Carp 'croak';
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.42';
our @ISA     = 'Wx::Dialog';

use Class::XSAccessor accessors => {
	_action       => '_action',       # action of default button
	_button       => '_button',       # general-purpose button
	_butprefs     => '_butprefs',     # preferences button
	_currow       => '_currow',       # current list row number
	_curplugin    => '_curplugin',    # current plugin selected
	_hbox         => '_hbox',         # the window hbox sizer
	_imagelist    => '_imagelist',    # image list for the listctrl
	_label        => '_label',        # label at top of right pane
	_list         => '_list',         # list on the left of the pane
	_manager      => '_manager',      # ref to plugin manager
	_plugin_class => '_plugin_class', # mapping of full name to class
	_sortcolumn   => '_sortcolumn',   # column used for list sorting
	_sortreverse  => '_sortreverse',  # list sorting is reversed
	_whtml        => '_whtml',        # html space for plugin doc
};

# -- constructor

sub new {
	my $class   = shift;
	my $parent  = shift;
	my $manager = shift;

	# Create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext('Plugin Manager'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	$self->SetIcon(Padre::Wx::Icon::PADRE);
	$self->_sortcolumn(0);
	$self->_sortreverse(0);

	# Store plugin manager
	unless ( $manager->isa('Padre::PluginManager') ) {
		croak("Missing or invalid Padre::PluginManager object");
	}
	$self->_manager($manager);

	# Create dialog
	$self->_create;

	# Tune the size and position it appears
	$self->Fit;
	$self->CentreOnParent;

	return $self;
}

# -- public methods

sub show {
	my $self = shift;

	$self->_refresh_list;

	# select first item in the list. we don't need to test if
	# there's at least a plugin, since there will always be
	# 'my plugin'
	my $list = $self->_list;
	my $item = $list->GetItem(0);
	$item->SetState(Wx::wxLIST_STATE_SELECTED);
	$list->SetItem($item);

	$self->Show;
}

# -- gui handlers

#
# $self->_on_butclose_clicked;
#
# handler called when the close button has been clicked.
#
sub _on_butclose_clicked {
	$_[0]->Destroy;
}

#
# $self->_on_butprefs_clicked;
#
# handler called when the preferences button has been clicked.
#
sub _on_butprefs_clicked {
	$_[0]->_curplugin->object->plugin_preferences;
}

#
# $self->_on_button_clicked;
#
# handler called when the first button has been clicked.
#
sub _on_button_clicked {
	my $self = shift;

	# find method to call
	my $method = $self->_action;

	# call method
	$self->$method();
}

#
# $self->_on_list_col_click;
#
# handler called when a column has been clicked, to reorder the list.
#
sub _on_list_col_click {
	my $self     = shift;
	my $event    = shift;
	my $column   = $event->GetColumn;
	my $prevcol  = $self->_sortcolumn;
	my $reversed = $self->_sortreverse;
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->_sortcolumn($column);
	$self->_sortreverse($reversed);
	$self->_refresh_list;
}

#
# $self->_on_list_item_activated;
#
# handler called when a list item has been activated (enter pressed, or
# double-click). it will enable / disable plugin - or display error message
# if plugin is currently in error.
#
# note that it definitely the same as clicking on the button, but we're
# keeping a different handler in case we want to do sthg different.
#
*_on_list_item_activated = \&_on_button_clicked;

#
# $self->_on_list_item_selected( $event );
#
# handler called when a list item has been selected. it will in turn update
# the right part of the frame.
#
# $event is a Wx::ListEvent.
#
sub _on_list_item_selected {
	my $self     = shift;
	my $event    = shift;
	my $fullname = $event->GetLabel;
	my $module   = $self->_plugin_class->{$fullname};
	my $plugin   = $self->_manager->plugins->{$module};
	$self->_curplugin($plugin);         # storing selected plugin
	$self->_currow( $event->GetIndex ); # storing selected row

	# Updating plugin name in right pane
	$self->_label->SetLabel( $plugin->plugin_name );

	# Update plugin documentation
	require Padre::DocBrowser;
	my $browser = Padre::DocBrowser->new;
	my $class   = $plugin->class;
	my $doc     = $browser->resolve($class);
	my $output  = eval { $browser->browse($doc) };
	my $html =
		$@
		? sprintf( Wx::gettext("Error loading pod for class '%s': %s"), $class, $@ )
		: $output->body;
	$self->_whtml->SetPage($html);

	# Update buttons
	$self->_update_plugin_state;

	# force window to recompute layout. indeed, changes are that plugin
	# name has a different length, and thus should be recentered.
	$self->Layout;
}

# -- private methods

#
# $self->_create;
#
# create the dialog itself. it will have a list on the left with all found
# plugins, and a pane on the right holding the details for the selected
# plugin, as well as control buttons.
#
# no params, no return values.
#
sub _create {
	my $self = shift;

	# create vertical box that will host all controls
	my $hbox = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$self->SetSizer($hbox);
	$self->SetMinSize( [ 800, 600 ] );
	$self->_hbox($hbox);
	$self->_create_list;
	$self->_create_right_pane;

	return 1;
}

#
# $dialog->_create_list;
#
# create the list on the left of the frame. it will hold a list of available
# plugins, along with their version & current status.
#
# no params. no return values.
#
sub _create_list {
	my $self = shift;

	# create list
	my $list = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT | Wx::wxLC_SINGLE_SEL,
	);
	$list->InsertColumn( 0, Wx::gettext('Name') );
	$list->InsertColumn( 1, Wx::gettext('Version') );
	$list->InsertColumn( 2, Wx::gettext('Status') );
	$self->_list($list);

	# install event handler
	Wx::Event::EVT_LIST_ITEM_SELECTED( $self, $list, \&_on_list_item_selected );
	Wx::Event::EVT_LIST_ITEM_ACTIVATED( $self, $list, \&_on_list_item_activated );
	Wx::Event::EVT_LIST_COL_CLICK( $self, $list, \&_on_list_col_click );

	# create imagelist
	my $imglist = Wx::ImageList->new( 16, 16 );
	$list->AssignImageList( $imglist, Wx::wxIMAGE_LIST_SMALL );
	$self->_imagelist($imglist);

	# pack the list
	$self->_hbox->Add( $list, 0, Wx::wxALL | Wx::wxEXPAND, 1 );
}

#
# $dialog->_create_right_pane;
#
# create the right pane of the frame. it will hold the name of the plugin,
# the associated documentation, and the action buttons to manage the plugin.
#
# no params. no return values.
#
sub _create_right_pane {
	my $self = shift;

	# all controls will be lined up in a vbox
	my $vbox = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$self->_hbox->Add( $vbox, 1, Wx::wxALL | Wx::wxEXPAND, 1 );

	# the plugin name
	my $hbox1 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $label = Wx::StaticText->new( $self, -1, 'plugin name' );
	my $font  = $label->GetFont;
	$vbox->Add( $hbox1, 0, Wx::wxALL | Wx::wxEXPAND, 1 );
	$font->SetWeight(Wx::wxFONTWEIGHT_BOLD);
	$font->SetPointSize( $font->GetPointSize + 2 );
	$label->SetFont($font);
	$hbox1->AddStretchSpacer;
	$hbox1->Add( $label, 0, Wx::wxEXPAND | Wx::wxALIGN_CENTER, 1 );
	$hbox1->AddStretchSpacer;
	$self->_label($label);

	# the plugin documentation
	require Padre::Wx::HtmlWindow;
	my $whtml = Wx::HtmlWindow->new($self);
	$vbox->Add(
		$whtml,
		1,
		Wx::wxALL | Wx::wxALIGN_TOP | Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxEXPAND,
		1
	);
	$self->_whtml($whtml);

	# the buttons
	my $hbox2 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$vbox->Add( $hbox2, 0, Wx::wxALL | Wx::wxEXPAND, 1 );
	my $b1 = Wx::Button->new( $self, Wx::wxID_OK,     'Button 1' );
	my $b2 = Wx::Button->new( $self, -1,              Wx::gettext('Preferences') );
	my $b3 = Wx::Button->new( $self, Wx::wxID_CANCEL, Wx::gettext('Close') );
	Wx::Event::EVT_BUTTON( $self, $b1, \&_on_button_clicked );
	Wx::Event::EVT_BUTTON( $self, $b2, \&_on_butprefs_clicked );
	Wx::Event::EVT_BUTTON( $self, $b3, \&_on_butclose_clicked );
	$hbox2->AddStretchSpacer;
	$hbox2->Add( $b1, 0, Wx::wxALL, 1 );
	$hbox2->Add( $b2, 0, Wx::wxALL, 1 );
	$hbox2->AddStretchSpacer;
	$hbox2->Add( $b3, 0, Wx::wxALL, 1 );
	$hbox2->AddStretchSpacer;
	$self->_button($b1);
	$self->_butprefs($b2);
}

#
# $self->_plugin_disable;
#
# disable plugin, and update gui.
#
sub _plugin_disable {
	my $self   = shift;
	my $plugin = $self->_curplugin;
	my $parent = $self->GetParent;

	# disable plugin
	$parent->Freeze;
	Padre::DB::Plugin->update_enabled( $plugin->class => 0 );
	$self->_manager->_plugin_disable( $plugin->class );
	$parent->menu->refresh(1);
	$parent->Thaw;

	# Update plugin manager dialog to reflect new state
	$self->_update_plugin_state;
}

#
# $self->_plugin_enable;
#
# enable plugin, and update gui.
#
sub _plugin_enable {
	my $self   = shift;
	my $plugin = $self->_curplugin;
	my $parent = $self->GetParent;

	# enable plugin
	$parent->Freeze;
	Padre::DB::Plugin->update_enabled( $plugin->class => 1 );
	$self->_manager->_plugin_enable( $plugin->class );
	$parent->menu->refresh(1);
	$parent->Thaw;

	# Update plugin manager dialog to reflect new state
	$self->_update_plugin_state;
}

#
# $self->_plugin_show_error_msg;
#
# show plugin error message, in an error dialog box.
#
sub _plugin_show_error_msg {
	my $self    = shift;
	my $message = $self->_curplugin->errstr;
	my $title   = Wx::gettext('Error');
	Wx::MessageBox( $message, $title, Wx::wxOK | Wx::wxCENTER, $self );
}

#
# $dialog->_refresh_list;
#
# refresh list of plugins and their associated state. list is sorted
# according to current sort criterion.
#
sub _refresh_list {
	my ($self) = @_;

	my $list    = $self->_list;
	my $manager = $self->_manager;
	my $plugins = $manager->plugins;
	my $imglist = $self->_imagelist;

	# Default sorting
	my $column  = $self->_sortcolumn;
	my $reverse = $self->_sortreverse;

	# Clear image list & fill it again
	$imglist->RemoveAll;

	# Default plugin icon
	$imglist->Add( Padre::Wx::Icon::find('status/padre-plugin') );
	my %icon = ( plugin => 0 );

	# Plugin status
	my $i = 0;
	foreach my $name (qw{ enabled disabled error crashed incompatible }) {
		$imglist->Add( Padre::Wx::Icon::find("status/padre-plugin-$name") );
		$icon{$name} = ++$i;
	}

	# Get list of plugins, and sort it. note that $manager->plugins names
	# is sorted (with my plugin first), and that perl sort is now stable:
	# sorting on another criterion will keep the alphabetical order if new
	# criterion is not enough.
	my @plugins = map { $plugins->{$_} } $manager->plugin_order;
	if ( $column == 1 ) {
		no warnings;
		@plugins = map { $_->[0] }
			sort { $a->[1] <=> $b->[1] }
			map { [ $_, version->new( $_->version || 0 ) ] } @plugins;
	}
	@plugins = sort { $a->status cmp $b->status } @plugins if $column == 2;
	@plugins = reverse @plugins if $reverse;

	# Clear plugin list & fill it again
	$list->DeleteAllItems;
	my %plugin_class = ();
	foreach my $plugin ( reverse @plugins ) {
		my $module     = $plugin->class;
		my $fullname   = $plugin->plugin_name;
		my $version    = $plugin->version || '???';
		my $status     = $plugin->status;
		my $l10nstatus = $plugin->status_localized;
		$plugin_class{$fullname} = $module;

		# Check if plugin is supplying its own icon
		my $position = 0;
		my $icon     = $plugin->plugin_icon;
		if ( defined $icon ) {
			$imglist->Add($icon);
			$position = $imglist->GetImageCount - 1;
		}

		# Inserting the plugin in the list
		my $idx = $list->InsertStringImageItem( 0, $fullname, $position );
		$list->SetItem( $idx, 1, $version );
		$list->SetItem( $idx, 2, $l10nstatus, $icon{$status} );
	}

	# Store mapping of full plugin names / short plugin names
	$self->_plugin_class( \%plugin_class );

	# Auto-resize columns
	foreach ( 0 .. 2 ) {
		$list->SetColumnWidth( $_, Wx::wxLIST_AUTOSIZE );
	}

	# Making sure the list can show all columns
	my $width = 15; # Taking vertical scrollbar into account
	foreach ( 0 .. 2 ) {
		$width += $list->GetColumnWidth($_);
	}
	$list->SetMinSize( [ $width, -1 ] );
}

#
# $dialog->_update_plugin_state;
#
# Update button caption & state, as well as status icon in the list,
# depending on the new plugin state.
#
sub _update_plugin_state {
	my $self   = shift;
	my $plugin = $self->_curplugin;
	my $list   = $self->_list;
	my $item   = $list->GetItem( $self->_currow, 2 );

	# Updating buttons
	my $button   = $self->_button;
	my $butprefs = $self->_butprefs;

	if ( $plugin->error ) {

		# plugin is in error state
		$button->SetLabel( Wx::gettext('Show error message') );
		$self->_action('_plugin_show_error_msg');
		$butprefs->Disable;
		$item->SetText( Wx::gettext('error') );
		$item->SetImage(3);
		$list->SetItem($item);

	} elsif ( $plugin->incompatible ) {

		# plugin is incompatible
		$button->SetLabel( Wx::gettext('Show error message') );
		$self->_action('_plugin_show_error_msg');
		$butprefs->Disable;
		$item->SetText( Wx::gettext('incompatible') );
		$item->SetImage(5);
		$list->SetItem($item);

	} else {

		# plugin is working...
		if ( $plugin->enabled ) {

			# ... and enabled
			$button->SetLabel( Wx::gettext('Disable') );
			$self->_action('_plugin_disable');
			$button->Enable;
			$item->SetText( Wx::gettext('enabled') );
			$item->SetImage(1);
			$list->SetItem($item);

		} elsif ( $plugin->can_enable ) {

			# ... and disabled
			$button->SetLabel( Wx::gettext('Enable') );
			$self->_action('_plugin_enable');
			$button->Enable;
			$item->SetText( Wx::gettext('disabled') );
			$item->SetImage(2);
			$list->SetItem($item);

		} else {

			# ... disabled but cannot be enabled
			$button->Disable;
		}

		# Updating preferences button
		if ( $plugin->object->can('plugin_preferences') ) {
			$self->_butprefs->Enable;
		} else {
			$self->_butprefs->Disable;
		}
	}

	# Update the list item

	# force window to recompute layout. indeed, changes are that plugin
	# name has a different length, and thus should be recentered.
	$self->Layout;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog::PluginManager - Plugin manager dialog for Padre

=head1 DESCRIPTION

Padre will have a lot of plugins. First plugin manager was not taking
this into account, and the first plugin manager window was too small &
too crowded to show them all properly.

This revamped plugin manager is now using a list control, and thus can
show lots of plugins in an effective manner.

Upon selection, the right pane will be updated with the plugin name &
plugin documentation. Two buttons will allow to de/activate the plugin
(or see plugin error message) and set plugin preferences.

Double-clicking on a plugin in the list will de/activate it.

=head1 PUBLIC API

=head2 Constructor

=over 4

=item * my $dialog = P::W::D::PM->new( $parent, $manager )

Create and return a new Wx dialog listing all the plugins. It needs a
C<$parent> window and a C<Padre::PluginManager> object that really
handles Padre plugins under the hood.

=back

=head2 Public methods

=over 4

=item * $dialog->show;

Request the plugin manager dialog to be shown. It will be refreshed
first with a current list of plugins with their state.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Locale               ();
use Padre::Document             ();
use Padre::Wx                   ();
use Padre::Wx::Role::Config     ();
use Padre::Wx::FBP::Preferences ();
use Padre::Wx::Choice::Theme    ();
use Padre::Wx::Theme            ();
use Padre::Wx::Role::Dialog     ();
use Padre::Util                 ('_T');
use Padre::Logger;

our $VERSION = '0.92';
our @ISA     = qw{
	Padre::Wx::Role::Config
	Padre::Wx::Role::Dialog
	Padre::Wx::FBP::Preferences
};





#####################################################################
# Class Methods

# One-shot creation, display and execution.
# Does return the object, but we don't expect anyone to use it.
sub run {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->new($main);

	# Always show the first tab regardless of which one
	# was selected in wxFormBuilder.
	$self->treebook->ChangeSelection(0);

	# Load preferences from configuration
	my $config = $main->config;
	$self->config_load($config);

	# Refresh the sizing, layout and position after the config load
	$self->GetSizer->SetSizeHints($self);
	$self->CentreOnParent;

	# Hide value and info sizer at startup
	if ( $self->{keybindings_panel} ) {
		my $sizer = $self->{keybindings_panel}->GetSizer;
		$sizer->Show( 2, 0 );
		$sizer->Show( 3, 0 );
		$sizer->Layout;
	}

	# Show the dialog
	if ( $self->ShowModal == Wx::ID_CANCEL ) {
		return;
	}

	# Save back to configuration
	$self->config_save($config);

	# re-create menu to activate shortcuts
	$self->_recreate_menubar;

	# Clean up
	$self->Destroy;
	return 1;
}





#####################################################################
# Constructor and Accessors

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift->SUPER::new(@_);

	# Set the content of the editor preview
	my $preview = $self->preview;
	$preview->{Document} = Padre::Document->new( mimetype => 'application/x-perl', );
	$preview->{Document}->set_editor( $self->preview );
	$preview->SetLexer('application/x-perl');
	$preview->SetText(<<'HERE'
#!/usr/bin/perl

use strict;

main();
exit 0;

sub main {
	# some senseless comment
	my $x = $_[0] ? $_[0] : 5;
	print "x is $x\n";
	if ( $x > 5 ) {
		return 1;
	} else {
		return 0;
	}
}

__END__
HERE
	);
	$preview->SetReadOnly(1);

	# Build the list of configuration dialog elements.
	# We assume all public dialog elements will match a wx widget with
	# a public method returning it.
	$self->{names} = [ grep { $self->can($_) } $self->config->settings ];

	#TODO access the panel by name instead of by index
	$self->{keybindings_panel} = $self->{treebook}->GetPage(4)
		or warn "Key bindings panel is not found!\n";

	# Set some internal parameters for key bindings
	$self->{sortcolumn}  = 0;
	$self->{sortreverse} = 0;

	my @titles = qw(Action Description Shortcut);
	foreach my $i ( 0 .. $#titles ) {
		$self->{list}->InsertColumn( $i, Wx::gettext( $titles[$i] ) );
		$self->{list}->SetColumnWidth( $i, Wx::LIST_AUTOSIZE );
	}

	# key choice list
	my @keys = (
		_T('None'),   _T('Backspace'), _T('Tab'),    _T('Space'),  _T('Up'),   _T('Down'),
		_T('Left'),   _T('Right'),     _T('Insert'), _T('Delete'), _T('Home'), _T('End'),
		_T('PageUp'), _T('PageDown'),  _T('Enter'),  _T('Escape'),
		'F1',       'F2',       'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
		'A' .. 'Z', '0' .. '9', '~',  '-',  '=',  '[',  ']',  ';',  '\'', ',',   '.',   '/'
	);
	$self->{keys} = \@keys;

	my @translated_keys = map { Wx::gettext($_) } @keys;
	for my $key (@translated_keys) {
		$self->{key}->Append($key);
	}
	$self->{key}->SetSelection(0);

	# Update the key bindings list
	$self->_update_list;

	# Tidy the list
	Padre::Util::tidy_list( $self->{list} );

	return $self;
}

sub names {
	return @{ $_[0]->{names} };
}





#####################################################################
# Padre::Wx::Role::Config Methods

sub config_load {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $config = shift;

	# We assume all public dialog elements will match a wx widget with
	# a public method returning it.
	$self->SUPER::config_load( $config, $self->names );

	# Do an initial style refresh of the editor preview
	$self->preview_refresh;

	return 1;
}

sub config_diff {
	TRACE( $_[0] ) if DEBUG;
	my $self   = shift;
	my $config = shift;

	# We assume all public dialog elements will match a wx widget
	# with a public method returning it.
	$self->SUPER::config_diff( $config, $self->names );
}





######################################################################
# Event Handlers

sub cancel {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Cancel the preferences dialog in Wx
	$self->EndModal(Wx::ID_CANCEL);

	return;
}

sub advanced {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Cancel the preferences dialog since it is not needed
	# but save it first
	$self->config_save( $self->main->config );
	$self->cancel;

	# Show the advanced settings dialog instead
	require Padre::Wx::Dialog::Advanced;
	my $advanced = Padre::Wx::Dialog::Advanced->new( $self->main );
	my $ret      = $advanced->show;

	return;
}

sub guess {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $indent   = $document->guess_indentation_style;

	$self->editor_indent_tab->SetValue( $indent->{use_tabs} );
	$self->editor_indent_tab_width->SetValue( $indent->{tabwidth} );
	$self->editor_indent_width->SetValue( $indent->{indentwidth} );

	return;
}

# We do this the long-hand way for now, as we don't have a suitable
# method for generating proper logical style objects.
sub preview_refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');
	my $name = $self->choice('editor_style');
	Padre::Wx::Theme->find($name)->apply( $self->preview );
	return;
}





######################################################################
# Support Methods

# Convenience method to get the current value for a single named choice
sub choice {
	my $self    = shift;
	my $name    = shift;
	my $ctrl    = $self->$name() or return;
	my $setting = $self->config->meta($name) or return;
	my $options = $setting->options or return;
	my @results = sort keys %$options;
	return $results[ $ctrl->GetSelection ];
}


#######################################################################
# Key Bindings panel methods

# Private method to update the key bindings list view
sub _update_list {
	my $self   = shift;
	my $filter = quotemeta $self->{filter}->GetValue;

	# Clear list
	my $list = $self->{list};
	$list->DeleteAllItems;

	my $actions         = $self->ide->actions;
	my $real_color      = Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW);
	my $alternate_color = Wx::Colour->new(
		int( $real_color->Red * 0.9 ),
		int( $real_color->Green * 0.9 ),
		$real_color->Blue,
	);
	my $index = 0;

	my @action_names = sort { $a cmp $b } keys %$actions;
	if ( $self->{sortcolumn} == 1 ) {

		# Sort by Descreption
		@action_names = sort { $actions->{$a}->label_text cmp $actions->{$b}->label_text } keys %$actions;
	}
	if ( $self->{sortcolumn} == 2 ) {

		# Sort by Shortcut
		@action_names = sort {
			_translate_shortcut( $actions->{$a}->shortcut || '' )
				cmp _translate_shortcut( $actions->{$b}->shortcut || '' )
		} keys %$actions;
	}
	if ( $self->{sortreverse} ) {
		@action_names = reverse @action_names;
	}

	foreach my $action_name (@action_names) {
		my $action = $actions->{$action_name};
		my $shortcut = defined $action->shortcut ? $action->shortcut : '';

		# Ignore key binding if it does not match the filter
		next
			if $action->label_text !~ /$filter/i
				and $action_name !~ /$filter/i
				and $shortcut !~ /$filter/i;

		# Add the key binding to the list control
		$list->InsertStringItem( $index, $action_name );
		$list->SetItem( $index, 1, $action->label_text );
		$list->SetItem( $index, 2, _translate_shortcut($shortcut) );

		# Non-default (i.e. overriden) shortcuts should have a bold font
		my $non_default = $self->config->default( $action->shortcut_setting ) ne $shortcut;
		$self->_set_item_bold_font( $index, $non_default );

		# Alternating table colors
		$list->SetItemBackgroundColour( $index, $alternate_color ) unless $index % 2;
		$index++;
	}

	return;
}

# Translates the shortcut to its native language
sub _translate_shortcut {
	my ($shortcut) = @_;

	my @parts = split /-/, $shortcut;
	my $regular_key = @parts ? $parts[-1] : '';

	return join '-', map { Wx::gettext($_) } @parts;
}

# Private method to set item to bold
# Somehow SetItemFont is not there... hence i had to write this long workaround
sub _set_item_bold_font {
	my ( $self, $index, $bold ) = @_;

	my $list = $self->{list};
	my $item = $list->GetItem($index);
	my $font = $item->GetFont;
	$font->SetWeight( $bold ? Wx::FONTWEIGHT_BOLD : Wx::FONTWEIGHT_NORMAL );
	$item->SetFont($font);
	$list->SetItem($item);

	return;
}

sub _on_list_col_click {
	my $self     = shift;
	my $event    = shift;
	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sortcolumn};
	my $reversed = $self->{sortreverse};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sortcolumn}  = $column;
	$self->{sortreverse} = $reversed;
	$self->_update_list;
	return;
}

# Private method to handle the selection of a key binding item
sub _on_list_item_selected {
	my $self  = shift;
	my $event = shift;

	my $list        = $self->{list};
	my $index       = $list->GetFirstSelected;
	my $action_name = $list->GetItemText($index);
	my $action      = $self->ide->actions->{$action_name};

	my $shortcut = $self->ide->actions->{$action_name}->shortcut;
	$shortcut = '' if not defined $shortcut;

	$self->{button_reset}->Enable( $shortcut ne $self->config->default( $action->shortcut_setting ) );

	$self->{button_delete}->Enable( $shortcut ne '' );

	$self->_update_shortcut_ui($shortcut);

	return;
}

# Updates the shortcut UI
sub _update_shortcut_ui {
	my ( $self, $shortcut ) = @_;

	my @parts = split /-/, $shortcut;
	my $regular_key = @parts ? $parts[-1] : '';

	# Find the regular key index in the choice box
	my $regular_index = 0;
	my @keys          = @{ $self->{keys} };
	for ( my $i = 0; $i < scalar @keys; $i++ ) {
		if ( $regular_key eq $keys[$i] ) {
			$regular_index = $i;
			last;
		}
	}

	# and update the UI
	$self->{key}->SetSelection($regular_index);
	$self->{ctrl}->SetValue( $shortcut  =~ /Ctrl/  ? 1 : 0 );
	$self->{alt}->SetValue( $shortcut   =~ /Alt/   ? 1 : 0 );
	$self->{shift}->SetValue( $shortcut =~ /Shift/ ? 1 : 0 );

	# Make sure the value and info sizer are not hidden
	if ( $self->{keybindings_panel} ) {
		my $sizer = $self->{keybindings_panel}->GetSizer;
		$sizer->Show( 2, 1 );
		$sizer->Show( 3, 1 );
		$sizer->Layout;
	}

	return;
}

# Private method to handle the pressing of the set value button
sub _on_set_button {
	my $self = shift;

	my $index       = $self->{list}->GetFirstSelected;
	my $action_name = $self->{list}->GetItemText($index);

	my @key_list = ();
	for my $regular_key ( 'Shift', 'Ctrl', 'Alt' ) {
		push @key_list, $regular_key if $self->{ lc $regular_key }->GetValue;
	}
	my $key_index   = $self->{key}->GetSelection;
	my $regular_key = $self->{keys}->[$key_index];
	push @key_list, $regular_key if not $regular_key eq 'None';
	my $shortcut = join '-', @key_list;

	$self->_try_to_set_binding( $action_name, $shortcut );

	return;
}

# Tries to set the binding and asks the user if he want to set the shortcut if has already be used elsewhere
sub _try_to_set_binding {
	my ( $self, $action_name, $shortcut ) = @_;

	my $other_action = $self->ide->shortcuts->{$shortcut};
	if ( defined $other_action && $other_action->name ne $action_name ) {
		return unless $self->yes_no(
			sprintf(
				Wx::gettext("The shortcut '%s' is already used by the action '%s'.\n"),
				$shortcut, $other_action->label_text
				)
				. Wx::gettext('Do you want to override it with the selected action?'),
			Wx::gettext('Override Shortcut')
		);
		$self->_set_binding( $other_action->name, '' );
	}

	$self->_set_binding( $action_name, $shortcut );

	return;
}

# Sets the key binding in Padre's configuration
sub _set_binding {
	my ( $self, $action_name, $shortcut ) = @_;

	my $shortcuts = $self->ide->shortcuts;
	my $action    = $self->ide->actions->{$action_name};

	# modify shortcut registry
	my $old_shortcut = $action->shortcut;
	delete $shortcuts->{$old_shortcut} if defined $old_shortcut;
	$shortcuts->{$shortcut} = $action;

	# set the action's shortcut
	$action->shortcut( $shortcut eq '' ? undef : $shortcut );

	# modify the configuration database
	$self->config->set( $action->shortcut_setting, $shortcut );
	$self->config->write;

	# Update the action's UI
	my $non_default = $self->config->default( $action->shortcut_setting ) ne $shortcut;
	$self->_update_action_ui( $action_name, $shortcut, $non_default );

	return;
}

# Private method to update the UI from the provided preference
sub _update_action_ui {

	my ( $self, $action_name, $shortcut, $non_default ) = @_;

	my $list = $self->{list};
	my $index = $list->FindItem( -1, $action_name );

	$self->{button_reset}->Enable($non_default);
	$list->SetItem( $index, 2, _translate_shortcut($shortcut) );
	$self->_set_item_bold_font( $index, $non_default );

	$self->_update_shortcut_ui($shortcut);

	return;
}

# Private method to handle the pressing of the delete button
sub _on_delete_button {
	my $self = shift;

	# Prepare the key binding
	my $index       = $self->{list}->GetFirstSelected;
	my $action_name = $self->{list}->GetItemText($index);

	$self->_set_binding( $action_name, '' );

	return;
}

# Private method to handle the pressing of the reset button
sub _on_reset_button {
	my $self = shift;

	my $index       = $self->{list}->GetFirstSelected;
	my $action_name = $self->{list}->GetItemText($index);
	my $action      = $self->ide->actions->{$action_name};

	$self->_try_to_set_binding(
		$action_name,
		$self->config->default( $action->shortcut_setting )
	);

	return;
}

# re-create menu to activate shortcuts
sub _recreate_menubar {
	my $self = shift;

	my $main = $self->main;
	delete $main->{menu};
	$main->{menu} = Padre::Wx::Menubar->new($main);
	$main->SetMenuBar( $main->menu->wx );
	$main->refresh;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

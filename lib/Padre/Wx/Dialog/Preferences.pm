package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Locale               ();
use Padre::Feature              ();
use Padre::Document             ();
use Padre::Wx                   ();
use Padre::Wx::Util             ();
use Padre::Wx::Role::Config     ();
use Padre::Wx::FBP::Preferences ();
use Padre::Wx::Choice::Theme    ();
use Padre::Wx::Theme            ();
use Padre::Wx::Role::Dialog     ();
use Padre::Locale::T;
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Config
	Padre::Wx::Role::Dialog
	Padre::Wx::FBP::Preferences
};

my @KEYS = (
	_T('None'),
	_T('Backspace'),
	_T('Tab'),
	_T('Space'),
	_T('Up'),
	_T('Down'),
	_T('Left'),
	_T('Right'),
	_T('Insert'),
	_T('Delete'),
	_T('Home'),
	_T('End'),
	_T('PageUp'),
	_T('PageDown'),
	_T('Enter'),
	_T('Escape'),
	'F1', 'F2', 'F3', 'F4',
	'F5', 'F6', 'F7', 'F8',
	'F9', 'F10', 'F11', 'F12',
	'A' .. 'Z',
	'0' .. '9',
	'~', '-', '=', '[', ']',
	';', '\'', ',', '.', '/'
);





#####################################################################
# Class Methods

# One-shot creation, display and execution.
# Does return the object, but we don't expect anyone to use it.
sub run {
	my $class = shift;
	my $main  = shift;
	my $self  = $class->new($main);

	# Show the optional sections
	if ( Padre::Feature::CPAN ) {
		$self->{label_cpan}->Show;
		$self->{main_cpan_panel}->Show;
	}
	if ( Padre::Feature::VCS ) {
		$self->{label_vcs}->Show;
		$self->{main_vcs_panel}->Show;
	}

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
		$self->{list}->tidy;
	}

	# Show the dialog
	if ( $self->ShowModal == Wx::ID_CANCEL ) {
		return;
	}

	# Save back to configuration
	$self->config_save($config);

	# Re-create menu to activate shortcuts
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
	$preview->SetText(<<'END_PERL' . '__END__');
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

END_PERL
	$preview->SetReadOnly(1);
	$preview->Show(1);

	# Build the list of configuration dialog elements.
	# We assume all public dialog elements will match a wx widget with
	# a public method returning it.
	$self->{names} = [ grep { $self->can($_) } $self->config->settings ];

	# Set some internal parameters for key bindings
	$self->{sortcolumn}  = 1;
	$self->{sortreverse} = 0;

	# Fill the key choice list
	for my $key ( map { Wx::gettext($_) } @KEYS ) {
		$self->{key}->Append($key);
	}
	$self->{key}->SetSelection(0);

	# Create the list columns
	$self->{list}->init(
		Wx::gettext('Shortcut'),
		Wx::gettext('Action'),
		Wx::gettext('Description'),
	);

	# Update the key bindings list
	$self->_update_list;

	# Tidy the list
	$self->{list}->tidy;

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
	my $self    = shift;
	my $config  = $self->config;
	my $preview = $self->preview;
	my $lock    = $preview->lock_update;

	# Create a tailored theme
	my $style = $self->choice('editor_style');
	my $theme = Padre::Wx::Theme->find($style)->clone;
	foreach ( 'editor_font', 'editor_currentline_color' ) {
		$theme->{$_} = $self->config_get( $config->meta($_) );
	}

	# Apply the tailored theme
	$theme->apply($preview);
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
	my $self    = shift;
	my $list    = $self->{list};
	my $lock    = $list->lock_update;
	my $actions = $self->ide->actions;
	my @names   = keys %$actions;

	# Build the data for the table
	my @table = map { [
		_translate_shortcut( $actions->{$_}->shortcut ),
		$_,
		$actions->{$_}->label_text,
	] } keys %$actions;

	# Apply term filtering
	my $filter = quotemeta $self->{filter}->GetValue;
	@table = grep {
		$_->[0] =~ /$filter/i
		or
		$_->[1] =~ /$filter/i
		or
		$_->[2] =~ /$filter/i
	} @table;

	# Apply sorting
	@table = sort {
		$a->[$self->{sortcolumn}] cmp $b->[$self->{sortcolumn}]
	} @table;
	if ( $self->{sortreverse} ) {
		@table = reverse @table;
	}

	# Find the alternate row colour
	my $color  = Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW);
	my $altcol = Wx::Colour->new(
		int( $color->Red * 0.9 ),
		int( $color->Green * 0.9 ),
		$color->Blue,
	);

	# Refill the table with the filtered list
	my $index = -1;
	$list->DeleteAllItems;
	foreach my $row ( @table ) {
		my $name   = $row->[1];
		my $action = $actions->{$name};

		# Add the row to the list
		$list->InsertStringItem( ++$index, $row->[0] );
		$list->SetItem( $index, 1, $row->[1] );
		$list->SetItem( $index, 2, $row->[2] );

		# Non-default (i.e. overriden) shortcuts should have a bold font
		my $shortcut = $action->shortcut;
		my $setting  = $action->shortcut_setting;
		my $default  = $self->config->default($setting);
		unless ( $shortcut eq $default ) {
			$list->set_item_bold( $index, 1 );
		}

		# Alternating table colors
		unless ( $index % 2 ) {
			$list->SetItemBackgroundColour( $index, $altcol );
		}
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
	my $self   = shift;
	my $event  = shift;
	my $list   = $self->{list};
	my $index  = $list->GetFirstSelected;
	my $name   = $list->GetItemText($index);
	my $action = $self->ide->actions->{$name};

	my $shortcut = $self->ide->actions->{$name}->shortcut;
	$shortcut = '' if not defined $shortcut;

	$self->{button_reset}->Enable( $shortcut ne $self->config->default( $action->shortcut_setting ) );

	$self->{button_delete}->Enable( $shortcut ne '' );

	$self->_update_shortcut_ui($shortcut);

	return;
}

# Updates the shortcut UI
sub _update_shortcut_ui {
	my ( $self, $shortcut ) = @_;

	my @parts       = split /-/, $shortcut;
	my $regular_key = @parts ? $parts[-1] : '';

	# Find the regular key index in the choice box
	my $regular_index = 0;
	for ( my $i = 0; $i < scalar @KEYS; $i++ ) {
		if ( $regular_key eq $KEYS[$i] ) {
			$regular_index = $i;
			last;
		}
	}

	# and update the UI
	$self->{key}->SetSelection($regular_index);
	$self->{ctrl}->SetValue(  $shortcut =~ /Ctrl/  ? 1 : 0 );
	$self->{alt}->SetValue(   $shortcut =~ /Alt/   ? 1 : 0 );
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
	my $self  = shift;
	my $index = $self->{list}->GetFirstSelected;
	my $name  = $self->{list}->GetItemText($index);

	my @key_list = ();
	for my $regular_key ( 'Shift', 'Ctrl', 'Alt' ) {
		push @key_list, $regular_key if $self->{ lc $regular_key }->GetValue;
	}
	my $key_index   = $self->{key}->GetSelection;
	my $regular_key = $KEYS[$key_index];
	push @key_list, $regular_key if not $regular_key eq 'None';
	my $shortcut = join '-', @key_list;

	$self->_try_to_set_binding( $name, $shortcut );

	return;
}

# Tries to set the binding and asks the user if he want to set the shortcut if has already be used elsewhere
sub _try_to_set_binding {
	my ( $self, $name, $shortcut ) = @_;

	my $other_action = $self->ide->shortcuts->{$shortcut};
	if ( defined $other_action && $other_action->name ne $name ) {
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

	$self->_set_binding( $name, $shortcut );

	return;
}

# Sets the key binding in Padre's configuration
sub _set_binding {
	my ( $self, $name, $shortcut ) = @_;

	my $shortcuts = $self->ide->shortcuts;
	my $action    = $self->ide->actions->{$name};

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
	$self->_update_action_ui( $name, $shortcut, $non_default );

	return;
}

# Private method to update the UI from the provided preference
sub _update_action_ui {
	my ( $self, $name, $shortcut, $non_default ) = @_;

	my $list  = $self->{list};
	my $index = $list->FindItem( -1, $name );

	$self->{button_reset}->Enable($non_default);
	$list->SetItem( $index, 2, _translate_shortcut($shortcut) );
	$list->set_item_bold( $index, $non_default );

	$self->_update_shortcut_ui($shortcut);

	return;
}

# Private method to handle the pressing of the delete button
sub _on_delete_button {
	my $self = shift;

	# Prepare the key binding
	my $index = $self->{list}->GetFirstSelected;
	my $name  = $self->{list}->GetItemText($index);

	$self->_set_binding( $name, '' );

	return;
}

# Private method to handle the pressing of the reset button
sub _on_reset_button {
	my $self   = shift;
	my $index  = $self->{list}->GetFirstSelected;
	my $name   = $self->{list}->GetItemText($index);
	my $action = $self->ide->actions->{$name};

	$self->_try_to_set_binding(
		$name,
		$self->config->default( $action->shortcut_setting )
	);

	return;
}

# re-create menu to activate shortcuts
# TO DO Massive encapsulation violation
sub _recreate_menubar {
	my $self = shift;
	my $main = $self->main;

	delete $main->{menu};
	$main->{menu} = Padre::Wx::Menubar->new($main);
	$main->SetMenuBar( $main->menu->wx );
	$main->refresh;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

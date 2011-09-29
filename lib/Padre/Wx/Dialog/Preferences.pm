package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Locale               ();
use Padre::Document             ();
use Padre::Wx                   ();
use Padre::Wx::Role::Config     ();
use Padre::Wx::FBP::Preferences ();
use Padre::Wx::Theme            ();
use Padre::Logger;

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Wx::Role::Config
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

	# Show the dialog
	if ( $self->ShowModal == Wx::ID_CANCEL ) {
		return;
	}

	# Save back to configuration
	$self->config_save($config);

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
	$preview->SetText(
		join '',
		map {"$_\n"} "#!/usr/bin/perl",
		"",
		"use strict;",
		"",
		"main();",
		"",
		"exit 0;",
		"",
		"sub main {",
		"\t# some senseles comment",
		"\tmy \$x = \$_[0] ? \$_[0] : 5;",
		"\tprint \"x is \$x\\n\";\n",
		"\tif ( \$x > 5 ) {",
		"\t\treturn 1;",
		"\t} else {",
		"\t\treturn 0;",
		"\t}",
		"}",
		"",
		"__END__",
	);
	$preview->SetReadOnly(1);

	# Build the list of configuration dialog elements.
	# We assume all public dialog elements will match a wx widget with
	# a public method returning it.
	$self->{names} = [ grep { $self->can($_) } $self->config->settings ];

	# Set some internal parameters for keybindings
	$self->{sortcolumn}  = 0;
	$self->{sortreverse} = 0;

	# Update the key bindings list
	$self->_update_list;

	# resize columns
	$self->_resize_columns;

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
		print "$index\n";
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

# Private method to resize list columns
sub _resize_columns {
	my $self = shift;

	# Resize all columns but the last to their biggest item width
	my $list = $self->{list};
	for ( 0 .. $list->GetColumnCount - 1 ) {
		$list->SetColumnWidth( $_, Wx::LIST_AUTOSIZE );
	}

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

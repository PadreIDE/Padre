package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Current ();

use base qw(Padre::Wx::Dialog);

our $VERSION = '0.27';

sub _new_panel {
	my ($self, $parent) = splice( @_, 0, 2 );
	my $cols = shift || 2;

	my $panel = Wx::Panel->new(
		$parent,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTAB_TRAVERSAL|Wx::wxVSCROLL|Wx::wxHSCROLL,
	);
	my $fgs = Wx::FlexGridSizer->new( 0, $cols, 0, 0 );
	$panel->SetSizer($fgs);

	return $panel;
}

sub _behaviour_panel {
	my ( $self, $treebook, $main_startup, $editor_autoindent, $main_functions_order ) = @_;

	my $config = Padre->ide->config;

	my $table = [
		[
			[ 'Wx::CheckBox', 'editor_wordwrap', ( $config->editor_wordwrap ? 1 : 0 ), Wx::gettext('Default word wrap on for each file') ],
			[ ]
		],
		[
			[ 'Wx::CheckBox', 'editor_beginner', ( $config->editor_beginner ? 1 : 0 ), Wx::gettext('Perl beginner mode') ],
			[]
		],
		[
			[ 'Wx::CheckBox', 'editor_indent_auto', ( $config->editor_indent_auto ? 1 : 0 ), Wx::gettext('Automatic indentation style') ],
			[ ]
		],
		[
			[ 'Wx::CheckBox', 'editor_indent_tab', ( $config->editor_indent_tab ? 1 : 0 ), Wx::gettext('Use Tabs') ],
			[ ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('TAB display size (in spaces):') ],
			[ 'Wx::SpinCtrl', 'editor_indent_tab_width', $config->editor_indent_tab_width, 0, 32 ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Indentation width (in columns):') ],
			[ 'Wx::SpinCtrl', 'editor_indent_width', $config->editor_indent_width, 0, 32 ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Guess from current document:') ],
			[ 'Wx::Button', '_guess_', Wx::gettext('Guess') ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Autoindent:') ],
			[ 'Wx::Choice', 'editor_autoindent', $editor_autoindent ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Open files:') ],
			[ 'Wx::Choice', 'main_startup', $main_startup ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Methods order:') ],
			[ 'Wx::Choice', 'main_functions_order', $main_functions_order ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Preferred language for error diagnostics:') ],
			[ 'Wx::TextCtrl', 'locale_perldiag', $config->locale_perldiag || '' ]
		],
	];

	my $panel = $self->_new_panel($treebook);
	$self->fill_panel_by_table( $panel, $table );

	Wx::Event::EVT_BUTTON( $panel,
		$self->get_widget('_guess_'),
		sub { warn Dumper([@_]); $self->guess_indentation_settings },
	);

	return $panel;
}

sub _appearance_panel {
	my ( $self, $treebook ) = @_;

	my $config = Padre->ide->config;

	my $panel = Wx::Panel->new(
		$treebook,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTAB_TRAVERSAL|Wx::wxVSCROLL|Wx::wxHSCROLL,
	);
	my $main_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);

	my $font =
		( defined $config->editor_font && length $config->editor_font > 0 )
			? $config->editor_font
			: Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL )->GetNativeFontInfoUserDesc;

	my $bgcolor =
		( defined $config->editor_currentline_color )
			? '#' . $config->editor_currentline_color
			: '#ffff04';

	my $table = [
		[
			[ 'Wx::CheckBox', 'main_output_ansi', ( $config->main_output_ansi ? 1 : 0 ), Wx::gettext('Colored text in output window (ANSI)') ],
			[ ]
		],
		[
			[ 'Wx::StaticText', 'undef', Wx::gettext('Editor Font:') ],
			[ 'Wx::FontPickerCtrl', 'editor_font', $font ]
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Editor Current Line Background Colour:') ],
			[ 'Wx::ColourPickerCtrl', 'editor_currentline_color', $bgcolor ]
		],
	];

	my $settings_subpanel = $self->_new_panel($panel);
	$self->fill_panel_by_table( $settings_subpanel, $table );

	$main_sizer->Add($settings_subpanel);

	Wx::Event::EVT_FONTPICKER_CHANGED( $settings_subpanel,
		$self->get_widget('editor_font'),
		sub {
			my $font = Wx::Font->new( $self->get_widget_value('editor_font') );
			$self->get_widget('preview_editor')->SetFont($font);
			foreach my $style ( 0 .. Wx::wxSTC_STYLE_DEFAULT ) {
				$self->get_widget('preview_editor')->StyleSetFont( $style, $font );
			}
		},
	);
	Wx::Event::EVT_COLOURPICKER_CHANGED( $settings_subpanel,
		$self->get_widget('editor_currentline_color'),
		sub {
			my $color = $self->get_widget_value('editor_currentline_color');
			$self->get_widget('preview_editor')->SetCaretLineBackground( Padre::Wx::Editor::_color( substr($color,1) ) );
		},
	);

	my $preview_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$main_sizer->Add( $preview_sizer, 3, Wx::wxGROW|Wx::wxALL, 3 );

	my $notebook = Wx::Notebook->new($panel);

	my $editor_panel = Wx::Panel->new( $notebook, -1 );
	my $editor_panel_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$editor_panel->SetSizer($editor_panel_sizer);

	my $editor = Padre::Wx::Editor->new($editor_panel);
	$self->add_widget('preview_editor', $editor);
	$self->_init_preview_editor( $bgcolor, $font );

	$editor_panel_sizer->Add(
		$self->get_widget('preview_editor'),
		5,
		Wx::wxALIGN_LEFT|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL|Wx::wxGROW,
		3
	);
	$notebook->AddPage( $editor_panel, Wx::gettext('Settings Demo') );

	$preview_sizer->Add( $notebook, 1, Wx::wxGROW, 5 );

	$panel->SetSizerAndFit($main_sizer);

	return $panel;
}

sub _init_preview_editor {
	my $self = shift;
	my ( $bgcolor, $font ) = @_;

	my $doc = Padre::Document::Perl->new();
	my $editor = $self->get_widget('preview_editor');
	$editor->{Document} = $doc;

	my $dummy_text = <<'END_TEXT';
#!/usr/bin/perl

use strict;

main();
exit 0;

sub main {
  # some senseles comment
  my $x = $_[0] ? $_[0] : 5;
  if ( $x > 5 ) {
    return 1;
  }
  else {
    return 0;
  }
}
__END__
END_TEXT

	$editor->SetText($dummy_text);
	$editor->SetWrapMode( Wx::wxSTC_WRAP_WORD );
	$editor->padre_setup;
	$editor->SetCaretLineBackground( Padre::Wx::Editor::_color( substr($bgcolor,1) ) );
	$editor->SetCaretLineVisible(1);
	$editor->SetFont(Wx::Font->new($font));
	$editor->StyleSetFont( Wx::wxSTC_STYLE_DEFAULT, Wx::Font->new($font) );
	$editor->SetReadOnly(1);
	$editor->SetExtraStyle( Wx::wxWS_EX_BLOCK_EVENTS );
	Wx::Event::EVT_RIGHT_DOWN( $editor, undef );
	Wx::Event::EVT_LEFT_UP(    $editor, undef );
	Wx::Event::EVT_CHAR(       $editor, undef );

	return;
}

sub _pluginmanager_panel {
	my ( $self, $treebook ) = @_;

	my $panel = $self->_new_panel($treebook, 3);
	my $fgs   = $panel->GetSizer;

	my $stdStyle = Wx::wxALIGN_LEFT|Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL;

	my $manager = Padre->ide->plugin_manager;

	my $plugins = $manager->plugins;
	foreach my $name ( sort keys %$plugins ) {
		$fgs->Add(
			Wx::StaticText->new(
				$panel,
				Wx::wxID_STATIC,
				$name
			),
			0, $stdStyle, 3
		);

		$self->add_widget( 'plugin_enable_' . $plugins->{$name}->{class},
			Wx::CheckBox->new(
				$panel,
				-1,
				Wx::gettext('Enable?')
			)
		);
		$self->get_widget( 'plugin_enable_' . $plugins->{$name}->{class} )->SetValue(
			( $plugins->{$name}->{status} eq 'enabled' ? 1 : 0 )
		);
		$fgs->Add( $self->get_widget(
			'plugin_enable_' . $plugins->{$name}->{class} ), 0, $stdStyle, 3 );

		if ( $plugins->{$name}->{status} ne 'enabled'
		     and $plugins->{$name}->{status} ne 'disabled'
		) {
			$self->add_widget( 'plugin_info_' . $plugins->{$name}->{class},
				Wx::Button->new(
					$panel,
					-1,
					Wx::gettext('Crashed')
				)
			);
			$fgs->Add( $self->get_widget( 'plugin_info_' . $plugins->{$name}->{class} ), 0, $stdStyle, 3 );
		}
		else {
			$fgs->Add( 0, 0 );
		}
	}

	return $panel;
}

sub _add_plugins {
	my ( $self, $tb ) = @_;

	my $manager = Padre->ide->plugin_manager;

	my $plugins = $manager->plugins;
	foreach my $name ( sort keys %$plugins ) {
		my $panel = $self->_new_panel($tb);
		$tb->AddSubPage($panel, $name, 0);
	}

	return;
}

sub dialog {
	my ($self, $win, $main_startup, $editor_autoindent, $main_functions_order) = @_;

	my $dialog = Wx::Dialog->new(
		$win,
		-1,
		'Settings',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION | Wx::wxRESIZE_BORDER | Wx::wxCLOSE_BOX | Wx::wxSYSTEM_MENU,
	);

	my $dialog_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	#$dialog->SetSizer($bs1);

	my $tb = Wx::Treebook->new(
		$dialog,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxBK_DEFAULT,
	);
	$tb->GetTreeCtrl->SetIndent(10);

	my $behaviour = $self->_behaviour_panel(
		$tb,
		$main_startup,
		$editor_autoindent,
		$main_functions_order
	);
	$tb->AddPage( $behaviour, Wx::gettext('Behaviour') );

	my $appearance = $self->_appearance_panel($tb);
	$tb->AddPage( $appearance, Wx::gettext('Appearance') );

	#my $plugin_manager = $self->_pluginmanager_panel($tb);
	#$tb->AddPage( $plugin_manager, Wx::gettext('Plugin Manager') );
	#$self->_add_plugins($tb);

	$dialog_sizer->Add( $tb, 10, Wx::wxGROW|Wx::wxALL, 5 );

	$dialog_sizer->Add(
		Wx::StaticLine->new(
			$dialog,
			Wx::wxID_STATIC,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			Wx::wxLI_HORIZONTAL|Wx::wxNO_BORDER
		),
		0,
		Wx::wxGROW|Wx::wxALL,
		5
	);

	my $button_row_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$dialog_sizer->Add(
		$button_row_sizer, 0, Wx::wxALIGN_RIGHT|Wx::wxBOTTOM, 5 );

	my $save = Wx::Button->new(
		$dialog,
		Wx::wxID_OK,
		Wx::gettext('&Save'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0
	);
	$button_row_sizer->Add( $save, 0, Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL, 5);

	my $cancel = Wx::Button->new(
		$dialog,
		Wx::wxID_CANCEL,
		Wx::gettext('&Cancel'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0
	);
	$button_row_sizer->Add( $cancel, 0, Wx::wxALIGN_CENTER_VERTICAL|Wx::wxALL, 5);

	$dialog->SetSizerAndFit($dialog_sizer);
	return $dialog;
}

sub guess_indentation_settings {
	my $self   = shift;
	my $doc    = Padre::Current->document;
	my $indent = $doc->guess_indentation_style;
	$self->get_widget('editor_indent_tab')->SetValue( $indent->{use_tabs} );
	$self->get_widget('editor_indent_tab_width')->SetValue( $indent->{tabwidth} );
	$self->get_widget('editor_indent_width')->SetValue( $indent->{indentwidth} );
}

sub new {
	my ( $class, $win ) = @_;

	return bless {}, $class;
}

sub run {
	my $self   = shift;
	my $win    = shift;
	my $config = Padre->ide->config;

	# Keep this in order for tools/update_pot_messages.pl
	# to pick these messages up.
	my @keep_me = (
		Wx::gettext('new'),
		Wx::gettext('nothing'),
		Wx::gettext('last'),
		Wx::gettext('no'),
		Wx::gettext('same_level'),
		Wx::gettext('deep'),
		Wx::gettext('alphabetical'),
		Wx::gettext('original'),
		Wx::gettext('alphabetical_private_last'),
	);

	# Startup preparation
	my $main_startup = $config->main_startup;
	my @main_startup_items = (
		$main_startup,
		grep { $_ ne $main_startup } qw{new nothing last}
	);
	my @main_startup_localized = map{Wx::gettext($_)} @main_startup_items;

	# Autoindent preparation
	my $editor_autoindent = $config->editor_autoindent;
	my @editor_autoindent_items = (
		$editor_autoindent,
		grep { $_ ne $editor_autoindent } qw{no same_level deep}
	);
	my @editor_autoindent_localized = map{Wx::gettext($_)} @editor_autoindent_items;

	# Function List Ordering
	my $main_functions_order = $config->main_functions_order;
	my @main_functions_order_items = (
		$main_functions_order,
		grep { $_ ne $main_functions_order }
		qw{alphabetical original alphabetical_private_last}
	);
	my @main_functions_order_localized = map{Wx::gettext($_)} @main_functions_order_items;

	$self->{dialog} = $self->dialog(
		$win,
		\@main_startup_localized,
		\@editor_autoindent_localized,
		\@main_functions_order_localized,
	);
	my $ret = $self->{dialog}->ShowModal;
	if ( $ret eq Wx::wxID_CANCEL ) {
		return;
	}

	my $data = $self->get_widgets_values;
	$config->set(
		'locale_perldiag',
		$data->{locale_perldiag}
	);
	$config->set(
		'editor_indent_auto',
		$data->{editor_indent_auto} ? 1 : 0
	);
	$config->set(
		'editor_indent_tab',
		$data->{editor_indent_tab} ? 1 : 0
	);
	$config->set(
		'editor_indent_tab_width',
		$data->{editor_indent_tab_width}
	);
	$config->set(
		'editor_indent_width',
		$data->{editor_indent_width}
	);
	$config->set(
		'editor_font',
		$data->{editor_font}
	);
	$config->set(
		'editor_wordwrap',
		$data->{editor_wordwrap} ? 1 : 0
	);
	$config->set(
		'editor_beginner',
		$data->{editor_beginner} ? 1 : 0
	);
	$config->set(
		'editor_autoindent',
		$editor_autoindent_items[ $data->{editor_autoindent} ]
	);
	$config->set(
		'main_startup',
		$main_startup_items[ $data->{main_startup} ]
	);
	$config->set(
		'main_functions_order',
		$main_functions_order_items[ $data->{main_functions_order} ]
	);
	$config->set(
		'main_output_ansi',
		$data->{main_output_ansi} ? 1 : 0
	);

	# The slightly different one
	my $editor_currentline_color = $data->{editor_currentline_color};
	$editor_currentline_color =~ s/#//;
	$config->set(
		'editor_currentline_color',
		$editor_currentline_color
	);

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

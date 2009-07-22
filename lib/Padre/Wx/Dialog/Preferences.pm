package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Current                         ();
use Padre::Wx                              ();
use Padre::Wx::Dialog                      ();
use Padre::Wx::Editor                      ();
use Padre::Wx::Dialog::Preferences::Editor ();

our $VERSION = '0.40';
our @ISA     = 'Padre::Wx::Dialog';

=pod

=head1 NAME

Padre::Wx::Dialog::Preferences - window to set the preferences

=head1 details

In order to add a new panel implement the _name_of_the_panel method.
Add to the dialog() sub a call to build the new panel.

In the run() sub add code to take the values from the new panel
and save them to the configuration file.

=cut

sub _new_panel {
	my ( $self, $parent ) = splice( @_, 0, 2 );
	my $cols = shift || 2;

	my $panel = Wx::Panel->new(
		$parent,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTAB_TRAVERSAL,
	);
	my $fgs = Wx::FlexGridSizer->new( 0, $cols, 0, 0 );
	$panel->SetSizer($fgs);

	return $panel;
}

sub _external_tools_panel {
	my ( $self, $treebook ) = @_;

	my $config = Padre->ide->config;
	my $table  = [
		[   [ 'Wx::StaticText', undef,                Wx::gettext('Diff tool:') ],
			[ 'Wx::TextCtrl',   'external_diff_tool', $config->external_diff_tool ]
		],
	];

	my $panel = $self->_new_panel($treebook);
	$self->fill_panel_by_table( $panel, $table );

	return $panel;
}

sub _mime_type_panel {
	my ( $self, $treebook ) = @_;

	my $mime_types = Padre::Document->get_mime_type_names;

	# get list of mime-types
	my $table = [
		[   [ 'Wx::StaticText', undef,       Wx::gettext('Mime type') ],
			[ 'Wx::Choice',     'mime_type', $mime_types ]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Select the highlighter:') ],
			[ 'Wx::Choice', 'highlighters', [] ]
		],
		[   [ 'Wx::StaticText', 'description', [] ],
		],
	];

	my $panel = $self->_new_panel($treebook);
	$self->fill_panel_by_table( $panel, $table );
	Wx::Event::EVT_CHOICE(
		$panel, $self->get_widget('mime_type'),
		sub { _on_mime_type_changed( $self, @_ ) }
	);
	Wx::Event::EVT_CHOICE(
		$panel, $self->get_widget('highlighters'),
		sub { _on_highlighter_changed( $self, @_ ) }
	);
	$self->update_highlighters;
	$self->update_description;
	$self->get_widget('description')->Wrap(200); # TODO should be based on the width of the page !
	return $panel;
}

sub _on_mime_type_changed {
	my ( $self, $panel, $event ) = @_;
	$self->update_highlighters;
	$self->update_description;
}

sub update_highlighters {
	my ($self) = @_;

	my $selection      = $self->get_widget('mime_type')->GetSelection;
	my $mime_types     = Padre::Document->get_mime_type_names;
	my $mime_type_name = $mime_types->[$selection];

	#print "mime '$mime_type_name'\n";
	$self->{_highlighters_}{$mime_type_name} ||= $self->{_start_highlighters_}{$mime_type_name};

	my $highlighters = Padre::Document->get_highlighters_of_mime_type_name($mime_type_name);

	#print "hl '$highlighters'\n";
	my ($id) = grep { $highlighters->[$_] eq $self->{_highlighters_}{$mime_type_name} } ( 0 .. @$highlighters - 1 );
	$id ||= 0;

	my $list = $self->get_widget('highlighters');
	$list->Clear;
	$list->AppendItems($highlighters);
	$list->SetSelection($id);
}

sub _on_highlighter_changed {
	my ( $self, $panel, $event ) = @_;
	$self->update_description;
}

sub update_description {
	my ($self) = @_;

	my $mime_type_selection = $self->get_widget('mime_type')->GetSelection;
	my $mime_types          = Padre::Document->get_mime_type_names;

	my $mime_type_name = $mime_types->[$mime_type_selection];

	my $highlighters          = Padre::Document->get_highlighters_of_mime_type_name($mime_type_name);
	my $highlighter_selection = $self->get_widget('highlighters')->GetSelection;
	my $highlighter           = $highlighters->[$highlighter_selection];

	$self->{_highlighters_}{$mime_type_name} = $highlighter;

	#print "Highlighter $highlighter\n";

	$self->get_widget('description')->SetLabel( Padre::Document->get_highlighter_explanation($highlighter) );
}


sub _indentation_panel {
	my ( $self, $treebook, $editor_autoindent ) = @_;

	my $config = Padre->ide->config;

	my $table = [
		[   [   'Wx::CheckBox', 'editor_indent_auto', ( $config->editor_indent_auto ? 1 : 0 ),
				Wx::gettext('Automatic indentation style detection')
			],
			[]
		],
		[   [ 'Wx::CheckBox', 'editor_indent_tab', ( $config->editor_indent_tab ? 1 : 0 ), Wx::gettext('Use Tabs') ],
			[]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('TAB display size (in spaces):') ],
			[ 'Wx::SpinCtrl', 'editor_indent_tab_width', $config->editor_indent_tab_width, 0, 32 ]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Indentation width (in columns):') ],
			[ 'Wx::SpinCtrl', 'editor_indent_width', $config->editor_indent_width, 0, 32 ]
		],
		[   [ 'Wx::StaticText', undef,     Wx::gettext('Guess from current document:') ],
			[ 'Wx::Button',     '_guess_', Wx::gettext('Guess') ]
		],
		[   [ 'Wx::StaticText', undef,               Wx::gettext('Autoindent:') ],
			[ 'Wx::Choice',     'editor_autoindent', $editor_autoindent ]
		],
	];

	my $panel = $self->_new_panel($treebook);
	$self->fill_panel_by_table( $panel, $table );

	Wx::Event::EVT_BUTTON(
		$panel,
		$self->get_widget('_guess_'),
		sub { $self->guess_indentation_settings },
	);

	return $panel;
}

sub _behaviour_panel {
	my ( $self, $treebook, $main_startup, $main_functions_order, $perldiag_locales ) = @_;

	my $config = Padre->ide->config;

	my $table = [
		[   [   'Wx::CheckBox', 'editor_wordwrap', ( $config->editor_wordwrap ? 1 : 0 ),
				Wx::gettext('Default word wrap on for each file')
			],
			[]
		],
		[   [   'Wx::CheckBox', 'editor_fold_pod', ( $config->editor_fold_pod ? 1 : 0 ),
				Wx::gettext('Auto-fold POD markup when code folding enabled')
			],
			[]
		],
		[   [   'Wx::CheckBox', 'editor_beginner', ( $config->editor_beginner ? 1 : 0 ),
				Wx::gettext('Perl beginner mode')
			],
			[]
		],
		[   [ 'Wx::StaticText', undef,          Wx::gettext('Open files:') ],
			[ 'Wx::Choice',     'main_startup', $main_startup ]
		],
		[   [   'Wx::CheckBox', 'main_singleinstance', ( $config->main_singleinstance ? 1 : 0 ),
				Wx::gettext('Open files in existing Padre')
			],
			[]
		],
		[   [ 'Wx::StaticText', undef,                  Wx::gettext('Methods order:') ],
			[ 'Wx::Choice',     'main_functions_order', $main_functions_order ]
		],
		[   [ 'Wx::StaticText', undef,             Wx::gettext('Preferred language for error diagnostics:') ],
			[ 'Wx::Choice',     'locale_perldiag', $perldiag_locales ]
		],
	];

	my $panel = $self->_new_panel($treebook);
	$self->fill_panel_by_table( $panel, $table );

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
		Wx::wxTAB_TRAVERSAL,
	);
	my $main_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);

	my $font_desc =
		( defined $config->editor_font && length $config->editor_font > 0 )
		? $config->editor_font
		: Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL )->GetNativeFontInfoUserDesc;

	my $bgcolor =
		( defined $config->editor_currentline_color )
		? '#' . $config->editor_currentline_color
		: '#ffff04';

	my $table = [
		[   [   'Wx::CheckBox', 'main_output_ansi', ( $config->main_output_ansi ? 1 : 0 ),
				Wx::gettext('Colored text in output window (ANSI)')
			],
			[]
		],
		[   [ 'Wx::StaticText',     'undef',       Wx::gettext('Editor Font:') ],
			[ 'Wx::FontPickerCtrl', 'editor_font', $font_desc ]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Editor Current Line Background Colour:') ],
			[ 'Wx::ColourPickerCtrl', 'editor_currentline_color', $bgcolor ]
		],
	];

	my $settings_subpanel = $self->_new_panel($panel);
	$self->fill_panel_by_table( $settings_subpanel, $table );

	$main_sizer->Add($settings_subpanel);

	Wx::Event::EVT_FONTPICKER_CHANGED(
		$settings_subpanel,
		$self->get_widget('editor_font'),
		sub {
			my $font = $self->_create_font( $self->get_widget_value('editor_font') );
			$self->get_widget('preview_editor')->SetFont($font);
			foreach my $style ( 0 .. Wx::wxSTC_STYLE_DEFAULT ) {
				$self->get_widget('preview_editor')->StyleSetFont( $style, $font );
			}
		},
	);
	Wx::Event::EVT_COLOURPICKER_CHANGED(
		$settings_subpanel,
		$self->get_widget('editor_currentline_color'),
		sub {
			my $color = $self->get_widget_value('editor_currentline_color');
			$self->get_widget('preview_editor')
				->SetCaretLineBackground( Padre::Wx::Editor::_color( substr( $color, 1 ) ) );
		},
	);

	my $preview_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$main_sizer->Add( $preview_sizer, 3, Wx::wxGROW | Wx::wxALL, 3 );

	my $notebook = Wx::Notebook->new($panel);

	my $editor_panel = Wx::Panel->new( $notebook, -1 );
	my $editor_panel_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$editor_panel->SetSizer($editor_panel_sizer);

	my $editor = Padre::Wx::Dialog::Preferences::Editor->new($editor_panel);
	$self->add_widget( 'preview_editor', $editor );
	$self->_init_preview_editor( $bgcolor, $font_desc );

	$editor_panel_sizer->Add(
		$self->get_widget('preview_editor'),
		5,
		Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL | Wx::wxGROW,
		3
	);
	$notebook->AddPage( $editor_panel, Wx::gettext('Settings Demo') );

	$preview_sizer->Add( $notebook, 1, Wx::wxGROW, 5 );

	$panel->SetSizerAndFit($main_sizer);

	return $panel;
}

sub _init_preview_editor {
	my $self = shift;
	my ( $bgcolor, $font_desc ) = @_;
	require Padre::Document::Perl;
	my $doc    = Padre::Document::Perl->new();
	my $editor = $self->get_widget('preview_editor');
	$editor->{Document} = $doc;
	$doc->set_editor($editor);

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
	$editor->SetWrapMode(Wx::wxSTC_WRAP_WORD);
	$editor->padre_setup;
	$editor->SetCaretLineBackground( Padre::Wx::Editor::_color( substr( $bgcolor, 1 ) ) );
	$editor->SetCaretLineVisible(1);
	my $editor_font = $self->_create_font($font_desc);
	$editor->SetFont($editor_font);
	$editor->StyleSetFont( Wx::wxSTC_STYLE_DEFAULT, $editor_font );
	$editor->SetReadOnly(1);
	$editor->SetExtraStyle(Wx::wxWS_EX_BLOCK_EVENTS);
	Wx::Event::EVT_RIGHT_DOWN( $editor, undef );
	Wx::Event::EVT_LEFT_UP( $editor, undef );
	Wx::Event::EVT_CHAR( $editor, undef );
	Wx::Event::EVT_SET_FOCUS( $editor, undef );

	return;
}

#
# A font description is a string that you get from $font->GetNativeFontInfoUserDesc()
#
# Important Note: You cannot create a font directly from it. This workaround is
# necessary. If you do not believe me, turn Wx debugging and you'll see what I mean :)
#
sub _create_font {
	my ( $self, $font_desc ) = @_;
	my $font = Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL );
	$font->SetNativeFontInfoUserDesc($font_desc);
	return $font;
}

sub _pluginmanager_panel {
	my ( $self, $treebook ) = @_;

	my $panel = $self->_new_panel( $treebook, 3 );
	my $fgs = $panel->GetSizer;

	my $stdStyle = Wx::wxALIGN_LEFT | Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL;

	my $manager = Padre->ide->plugin_manager;

	my $plugins = $manager->plugins;
	foreach my $name ( sort keys %$plugins ) {
		$fgs->Add(
			Wx::StaticText->new(
				$panel,
				Wx::wxID_STATIC,
				$name
			),
			0,
			$stdStyle,
			3
		);

		$self->add_widget(
			'plugin_enable_' . $plugins->{$name}->{class},
			Wx::CheckBox->new(
				$panel,
				-1,
				Wx::gettext('Enable?')
			)
		);
		$self->get_widget( 'plugin_enable_' . $plugins->{$name}->{class} )
			->SetValue( ( $plugins->{$name}->{status} eq 'enabled' ? 1 : 0 ) );
		$fgs->Add( $self->get_widget( 'plugin_enable_' . $plugins->{$name}->{class} ), 0, $stdStyle, 3 );

		if (    $plugins->{$name}->{status} ne 'enabled'
			and $plugins->{$name}->{status} ne 'disabled' )
		{
			$self->add_widget(
				'plugin_info_' . $plugins->{$name}->{class},
				Wx::Button->new(
					$panel,
					-1,
					Wx::gettext('Crashed')
				)
			);
			$fgs->Add( $self->get_widget( 'plugin_info_' . $plugins->{$name}->{class} ), 0, $stdStyle, 3 );
		} else {
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
		$tb->AddSubPage( $panel, $name, 0 );
	}

	return;
}

sub _run_params_panel {
	my ( $self, $treebook ) = @_;

	my $config   = Padre->ide->config;
	my $document = Padre::Current->document;

	my $intrp_args_text = Wx::gettext(<<'END_TEXT');
i.e.
	include directory:  -I<dir>
	enable tainting checks:  -T
	enable many useful warnings:  -w
	enable all warnings:  -W
	disable all warnings:  -X
END_TEXT

	# Default values stored in host configuration
	my $defaults_table = [
		[   [ 'Wx::StaticText', undef,                          Wx::gettext('Interpreter arguments:') ],
			[ 'Wx::TextCtrl',   'run_interpreter_args_default', $config->run_interpreter_args_default ]
		],
		[   [ 'Wx::StaticText', undef, '' ],
			[ 'Wx::StaticText', undef, $intrp_args_text ]
		],
		[   [ 'Wx::StaticText', undef,                     Wx::gettext('Script arguments:') ],
			[ 'Wx::TextCtrl',   'run_script_args_default', $config->run_script_args_default ]
		],
		[   [   'Wx::CheckBox', 'run_use_external_window', ( $config->run_use_external_window ? 1 : 0 ),
				Wx::gettext('Use external window for execution (xterm)')
			],
			[]
		],

	];

	# Per document values (overwrite defaults) stored in history
	my $doc_flag = 0;                     # value of 1 means that there is no document currently open
	my $filename = Wx::gettext('Unsaved');
	my $path     = Wx::gettext('N/A');
	my %run_args = (
		interpreter => '',
		script      => '',
	);

	# Trap exception if there is no document currently open
	eval {
		unless ( $document->is_new )
		{
			( $filename, $path ) = File::Basename::fileparse( Padre::Current->filename );
			foreach my $arg ( keys %run_args ) {
				my $type = "run_${arg}_args_${filename}";
				$run_args{$arg} = Padre::DB::History->previous($type)
					if Padre::DB::History->previous($type);
			}
		}
	};
	if ($@) {
		$filename = Wx::gettext('No Document');
		$doc_flag = 1;
	}

	my $currentdoc_table = [
		[   [ 'Wx::StaticText', undef, Wx::gettext('Document name:') ],
			[ 'Wx::TextCtrl', undef, $filename, Wx::wxTE_READONLY ]
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Document location:') ],
			[ 'Wx::TextCtrl', undef, $path, Wx::wxTE_READONLY ]
		],
		[   [ 'Wx::StaticText', undef,                            Wx::gettext('Interpreter arguments:') ],
			[ 'Wx::TextCtrl',   "run_interpreter_args_$filename", $run_args{interpreter} ]
		],
		[   [ 'Wx::StaticText', undef, '' ],
			[ 'Wx::StaticText', undef, $intrp_args_text ]
		],
		[   [ 'Wx::StaticText', undef,                       Wx::gettext('Script arguments:') ],
			[ 'Wx::TextCtrl',   "run_script_args_$filename", $run_args{script} ]
		],
	];

	my $panel = Wx::Panel->new(
		$treebook,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTAB_TRAVERSAL,
	);
	my $main_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);

	my $notebook = Wx::Notebook->new($panel);

	my $defaults_subpanel = $self->_new_panel($notebook);
	$self->fill_panel_by_table( $defaults_subpanel, $defaults_table );
	$notebook->AddPage( $defaults_subpanel, Wx::gettext('Default') );

	my $currentdoc_subpanel = $self->_new_panel($notebook);
	$self->fill_panel_by_table( $currentdoc_subpanel, $currentdoc_table ) unless $doc_flag;
	$notebook->AddPage(
		$currentdoc_subpanel,
		sprintf( Wx::gettext('Current Document: %s'), $filename )
	);

	$main_sizer->Add( $notebook, 1, Wx::wxGROW );
	$panel->SetSizerAndFit($main_sizer);

	return $panel;
}

sub dialog {
	my ( $self, $win, $main_startup, $editor_autoindent, $main_functions_order, $perldiag_locales ) = @_;

	my $dialog = Wx::Dialog->new(
		$win,
		-1,
		Wx::gettext('Preferences'),
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
		$main_functions_order,
		$perldiag_locales,
	);
	$tb->AddPage( $behaviour, Wx::gettext('Behaviour') );

	my $appearance = $self->_appearance_panel($tb);
	$tb->AddPage( $appearance, Wx::gettext('Appearance') );
	$tb->AddPage(
		$self->_run_params_panel($tb),
		Wx::gettext('Run Parameters')
	);

	my $mime_types = $self->_mime_type_panel($tb);
	$tb->AddPage( $mime_types, Wx::gettext('Mime-types') );

	my $indentation = $self->_indentation_panel( $tb, $editor_autoindent );
	$tb->AddPage( $indentation, Wx::gettext('Indentation') );

	my $external_tools = $self->_external_tools_panel($tb);
	$tb->AddPage( $external_tools, Wx::gettext('External Tools') );

	#my $plugin_manager = $self->_pluginmanager_panel($tb);
	#$tb->AddPage( $plugin_manager, Wx::gettext('Plugin Manager') );
	#$self->_add_plugins($tb);

	$dialog_sizer->Add( $tb, 10, Wx::wxGROW | Wx::wxALL, 5 );

	$dialog_sizer->Add(
		Wx::StaticLine->new(
			$dialog,
			Wx::wxID_STATIC,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			Wx::wxLI_HORIZONTAL | Wx::wxNO_BORDER
		),
		0,
		Wx::wxGROW | Wx::wxALL,
		5
	);

	my $button_row_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$dialog_sizer->Add( $button_row_sizer, 0, Wx::wxALIGN_RIGHT | Wx::wxBOTTOM, 5 );

	my $save = Wx::Button->new(
		$dialog,
		Wx::wxID_OK,
		Wx::gettext('&Save'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0
	);
	$button_row_sizer->Add( $save, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 5 );
	$save->SetDefault;

	my $cancel = Wx::Button->new(
		$dialog,
		Wx::wxID_CANCEL,
		Wx::gettext('&Cancel'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0
	);
	$button_row_sizer->Add( $cancel, 0, Wx::wxALIGN_CENTER_VERTICAL | Wx::wxALL, 5 );
	$cancel->SetFocus;

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

	$self->{_start_highlighters_} = Padre::Document->get_current_highlighter_names;

	# Startup preparation
	my $main_startup       = $config->main_startup;
	my @main_startup_items = (
		$main_startup,
		grep { $_ ne $main_startup } qw{new nothing last}
	);
	my @main_startup_localized = map { Wx::gettext($_) } @main_startup_items;

	# Autoindent preparation
	my $editor_autoindent       = $config->editor_autoindent;
	my @editor_autoindent_items = (
		$editor_autoindent,
		grep { $_ ne $editor_autoindent } qw{no same_level deep}
	);
	my @editor_autoindent_localized = map { Wx::gettext($_) } @editor_autoindent_items;

	# Function List Ordering
	my $main_functions_order       = $config->main_functions_order;
	my @main_functions_order_items = (
		$main_functions_order,
		grep { $_ ne $main_functions_order } qw{alphabetical original alphabetical_private_last}
	);
	my @main_functions_order_localized = map { Wx::gettext($_) } @main_functions_order_items;

	my $perldiag_locale  = $config->locale_perldiag;
	my @perldiag_locales = (
		$perldiag_locale,
		grep { $_ ne $perldiag_locale } ( 'EN', Padre::Util::find_perldiag_translations() )
	);

	$self->{dialog} = $self->dialog(
		$win,
		\@main_startup_localized,
		\@editor_autoindent_localized,
		\@main_functions_order_localized,
		\@perldiag_locales,
	);
	my $ret = $self->{dialog}->ShowModal;
	if ( $ret eq Wx::wxID_CANCEL ) {
		return;
	}

	# Save the highlighters
	my %changed_highlighters;
	foreach my $mime_type_name ( keys %{ $self->{_highlighters_} } ) {
		if ( $self->{_start_highlighters_}{$mime_type_name} ne $self->{_highlighters_}{$mime_type_name} ) {
			$changed_highlighters{$mime_type_name} = $self->{_highlighters_}{$mime_type_name};

			#print "Changing highlighter of $mime_type_name from $self->{_start_highlighters_}{$mime_type_name} to $self->{_highlighters_}{$mime_type_name}\n";
		}
	}
	Padre::Document->change_highlighters( \%changed_highlighters );

	my $data = $self->get_widgets_values;
	$config->set(
		'locale_perldiag',
		$perldiag_locales[ $data->{locale_perldiag} ]
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
		'editor_fold_pod',
		$data->{editor_fold_pod} ? 1 : 0
	);
	$config->set(
		'editor_beginner',
		$data->{editor_beginner} ? 1 : 0
	);
	$config->set(
		'main_singleinstance',
		$data->{main_singleinstance} ? 1 : 0
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
	$config->set(
		'run_interpreter_args_default',
		$data->{run_interpreter_args_default}
	);
	$config->set(
		'run_script_args_default',
		$data->{run_script_args_default}
	);
	$config->set(
		'run_use_external_window',
		$data->{run_use_external_window}
	);

	$config->set(
		'external_diff_tool',
		$data->{external_diff_tool}
	);

	# Quite like in _run_params_panel, trap exception if there
	# is no document currently open
	eval {
		unless ( Padre::Current->document->is_new )
		{

			# These are a bit different as run_* variable name depends
			# on current document's filename
			foreach ( grep { /^run_/ and not /_default$/ } keys %$data ) {
				if ( Padre::DB::History->previous($_) eq $data->{$_} ) {
					next;
				}
				Padre::DB::History->create(
					type => $_,
					name => $data->{$_},
				);
			}
		}
	};

	# The slightly different one
	my $editor_currentline_color = $data->{editor_currentline_color};
	$editor_currentline_color =~ s/#//;
	$config->set(
		'editor_currentline_color',
		$editor_currentline_color
	);

	$config->write;
	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

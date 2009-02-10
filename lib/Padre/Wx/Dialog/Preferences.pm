package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;
use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Padre::Current    ();

our $VERSION = '0.26';

sub get_layout_for_behaviour {
	my ($config, $main_startup, $editor_autoindent, $main_functions_order) = @_;

	return [
		[
			['Wx::CheckBox',    'editor_indent_auto', Wx::gettext('Automatic indentation style'),    ($config->editor_indent_auto ? 1 : 0) ],
			['Wx::CheckBox',    'editor_indent_tab', Wx::gettext('Use Tabs'),    ($config->editor_indent_tab ? 1 : 0) ],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('TAB display size (in spaces)')],
			[ 'Wx::TextCtrl',   'editor_indent_tab_width',  $config->editor_indent_tab_width],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Indentation width (in columns)')],
			[ 'Wx::TextCtrl',   'editor_indent_width', $config->editor_indent_width],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Guess from current document')],
			[ 'Wx::Button',     '_guess_',          Wx::gettext('Guess')     ],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Open files:')],
			[ 'Wx::Choice',     'main_startup',     $main_startup],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Autoindent:')],
			[ 'Wx::Choice',     'editor_autoindent', $editor_autoindent],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Methods order:')],
			[ 'Wx::Choice',     'main_functions_order', $main_functions_order],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Default word wrap on for each file')],
			['Wx::CheckBox',    'editor_wordwrap', '',
				($config->editor_wordwrap ? 1 : 0) ],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Perl beginner mode')],
			['Wx::CheckBox',    'editor_beginner', '',
				($config->editor_beginner ? 1 : 0) ],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Preferred language for error diagnostics:')],
			[ 'Wx::TextCtrl',     'locale_perldiag', $config->locale_perldiag||''],
		],
	];
}

sub get_layout_for_appearance {
	my $config = shift;

	return [
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Editor Font:') ],
			[ 'Wx::FontPickerCtrl', 'editor_font',
				( ( defined $config->editor_font && length $config->editor_font > 0 )
				    ? $config->editor_font
				    : Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL )->GetNativeFontInfoUserDesc
				)
			] 
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Editor Current Line Background Colour:') ],
			[ 'Wx::ColourPickerCtrl', 'editor_currentline_color',
				(defined $config->editor_currentline_color ? '#' . $config->editor_currentline_color : '#ffff04') ]
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Colored text in output window (ANSI): ')],
			['Wx::CheckBox',    'main_output_ansi', '',
				($config->main_output_ansi ? 1 : 0) ],
		],
	];
}

sub dialog {
	my ($class, $win, $main_startup, $editor_autoindent, $main_functions_order) = @_;

	my $config = Padre->ide->config;
	my $behaviour  = get_layout_for_behaviour($config, $main_startup, $editor_autoindent, $main_functions_order);
	my $appearance = get_layout_for_appearance($config);
	my $dialog = Padre::Wx::Dialog->new(
		parent => $win,
		title  => Wx::gettext("Preferences"),
		layout => [ $behaviour, $appearance, ],
		width  => [ 280, 200 ],
		multipage => {
			auto_ok_cancel  => 1,
			ok_widgetid     => '_ok_',
			cancel_widgetid => '_cancel_',
			pagenames       => [ Wx::gettext('Behaviour'), Wx::gettext('Appearance') ]
		},
	);

	$dialog->{_widgets_}->{editor_indent_tab_width}->SetFocus;

	Wx::Event::EVT_BUTTON( $dialog,
		$dialog->{_widgets_}->{_ok_},
		sub { $dialog->EndModal(Wx::wxID_OK) },
	);
	Wx::Event::EVT_BUTTON( $dialog,
		$dialog->{_widgets_}->{_cancel_},
		sub { $dialog->EndModal(Wx::wxID_CANCEL) },
	);
	Wx::Event::EVT_BUTTON( $dialog,
		$dialog->{_widgets_}->{_guess_},
		sub { $class->guess_indentation_settings($dialog) },
	);

	$dialog->{_widgets_}->{_ok_}->SetDefault;

	return $dialog;
}

sub guess_indentation_settings {
	my $class  = shift;
	my $dialog = shift;
	my $doc    = Padre::Current->document;
	my $indent = $doc->guess_indentation_style;
	$dialog->{_widgets_}->{editor_indent_tab}->SetValue( $indent->{use_tabs} );
	$dialog->{_widgets_}->{editor_indent_tab_width}->SetValue( $indent->{tabwidth} );
	$dialog->{_widgets_}->{editor_indent_width}->SetValue( $indent->{indentwidth} );
}

sub run {
	my $class  = shift;
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

	my $dialog = $class->dialog( $win, 
		\@main_startup_localized,
		\@editor_autoindent_localized,
		\@main_functions_order_localized
	);
	$dialog->show_modal or return;

	my $data = $dialog->get_data;
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

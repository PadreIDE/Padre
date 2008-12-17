package Padre::Wx::Dialog::Preferences;

use 5.008;
use strict;
use warnings;

use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.21';

sub get_layout_for_behaviour {
	my ($config, $main_startup, $editor_autoindent, $editor_methods) = @_;

	return [
		[
			['Wx::CheckBox',    'editor_auto_indentation_style', Wx::gettext('Automatic indentation style'),    ($config->{editor_auto_indentation_style} ? 1 : 0) ],
			['Wx::CheckBox',    'editor_use_tabs', Wx::gettext('Use Tabs'),    ($config->{editor_use_tabs} ? 1 : 0) ],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('TAB display size (in spaces)')],
			[ 'Wx::TextCtrl',   'editor_tabwidth',  $config->{editor_tabwidth}],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Indentation width (in columns)')],
			[ 'Wx::TextCtrl',   'editor_indentwidth', $config->{editor_indentwidth}],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Guess from current document')],
			[ 'Wx::Button',     '_guess_',          Wx::gettext('Guess')     ],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Max number of modules')],
			[ 'Wx::TextCtrl',   'pod_maxlist',      $config->{pod_maxlist}],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Min number of modules')],
			[ 'Wx::TextCtrl',   'pod_minlist',      $config->{pod_minlist}],
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
			[ 'Wx::Choice',     'editor_methods', $editor_methods],
		],
		[
			[ 'Wx::StaticText', undef,              Wx::gettext('Default word wrap on for each file')],
			['Wx::CheckBox',    'editor_use_wordwrap', '',
				($config->{editor_use_wordwrap} ? 1 : 0) ],
		],
	];
}

sub get_layout_for_appearance {
	my $config = shift;

	return [
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Editor Font:') ],
			[ 'Wx::FontPickerCtrl', 'editor_font',
				( defined $config->{editor_font}
				    ? $config->{editor_font}
				    : Wx::Font->new( 10, Wx::wxTELETYPE, Wx::wxNORMAL, Wx::wxNORMAL )->GetNativeFontInfoUserDesc
				)
			] 
		],
		[
			[ 'Wx::StaticText', undef, Wx::gettext('Editor Caret Line Background Colour:') ],
			[ 'Wx::ColourPickerCtrl', 'editor_caret_line_background_color',
				(defined $config->{editor_caret_line_background_color} ? $config->{editor_caret_line_background_color} : '#efefef') ]
		],
	];
}

sub dialog {
	my ($class, $win, $main_startup, $editor_autoindent, $editor_methods) = @_;

	my $config = Padre->ide->config;
	my $behaviour  = get_layout_for_behaviour($config, $main_startup, $editor_autoindent, $editor_methods);
	my $appearance = get_layout_for_appearance($config);
	my $dialog = Padre::Wx::Dialog->new(
		parent => $win,
		title  => Wx::gettext("Preferences"),
		layout => [ $behaviour, $appearance, ],
		width  => [280, 200],
		multipage => {
			auto_ok_cancel  => 1,
			ok_widgetid     => '_ok_',
			cancel_widgetid => '_cancel_',
			pagenames       => [ 'Behaviour', 'Appearance' ]
		},
	);

	$dialog->{_widgets_}{editor_tabwidth}->SetFocus;

	Wx::Event::EVT_BUTTON( $dialog,
		$dialog->{_widgets_}{_ok_},
		sub { $dialog->EndModal(Wx::wxID_OK) },
	);
	Wx::Event::EVT_BUTTON( $dialog,
		$dialog->{_widgets_}{_cancel_},
		sub { $dialog->EndModal(Wx::wxID_CANCEL) },
	);
	Wx::Event::EVT_BUTTON( $dialog,
		$dialog->{_widgets_}{_guess_},
		sub { $class->guess_indentation_settings($dialog) },
	);

	$dialog->{_widgets_}{_ok_}->SetDefault;

	return $dialog;
}

sub guess_indentation_settings {
	my $class  = shift;
	my $dialog = shift;
	my $doc    = Padre::Documents->current;

	my $indent_style = $doc->guess_indentation_style();
	
	$dialog->{_widgets_}{editor_use_tabs}->SetValue( $indent_style->{use_tabs} );
	$dialog->{_widgets_}{editor_tabwidth}->SetValue( $indent_style->{tabwidth} );
	$dialog->{_widgets_}{editor_indentwidth}->SetValue( $indent_style->{indentwidth} );
}


sub run {
	my ( $class, $win ) = @_;

	my $config = Padre->ide->config;

	my @main_startup = (
		$config->{main_startup},
		grep { $_ ne $config->{main_startup} } qw( new nothing last )
	);
	my @editor_autoindent = (
		$config->{editor_autoindent},
		grep { $_ ne $config->{editor_autoindent} } qw( no same_level deep )
	);
	my @editor_methods = (
		$config->{editor_methods},
		grep { $_ ne $config->{editor_methods} } qw( alphabetical original alphabetical_private_last )
	);

	my $dialog = $class->dialog( $win, \@main_startup, \@editor_autoindent, \@editor_methods );
	return if not $dialog->show_modal;

	my $data = $dialog->get_data;

	foreach my $f (
		qw( pod_maxlist
			pod_minlist
			editor_tabwidth
			editor_indentwidth
			editor_font
			editor_caret_line_background_color
		)
	) {
		$config->{$f} = $data->{$f};
	}
	foreach my $f (qw(editor_use_tabs editor_use_wordwrap editor_auto_indentation_style)) {
		$config->{$f} = $data->{$f} ? 1 : 0;
	}

	$config->{main_startup}        = $main_startup[ $data->{main_startup} ];
	$config->{editor_autoindent}   = $editor_autoindent[ $data->{editor_autoindent} ];
	$config->{editor_methods}      = $editor_methods[ $data->{editor_methods} ];

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

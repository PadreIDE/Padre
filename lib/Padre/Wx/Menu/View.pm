package Padre::Wx::Menu::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use File::Glob      ();
use Padre::Constant ();
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Locale   ();

our $VERSION = '0.54';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = Padre->ide->config;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Can the user move stuff around
	$self->{lockinterface} = $self->add_menu_action(
		$self,
		'view.lockinterface',
	);

	$self->AppendSeparator;

	# Show or hide GUI elements
	$self->{output} = $self->add_menu_action(
		$self,
		'view.output',
	);

	$self->{functions} = $self->add_menu_action(
		$self,
		'view.functions',
	);

	# Show or hide GUI elements
	$self->{outline} = $self->add_menu_action(
		$self,
		'view.outline',
	);

	$self->{directory} = $self->add_menu_action(
		$self,
		'view.directory',
	);

	$self->{show_syntaxcheck} = $self->add_menu_action(
		$self,
		'view.show_syntaxcheck',
	);

	$self->{show_errorlist} = $self->add_menu_action(
		$self,
		'view.show_errorlist',
	);

	$self->{statusbar} = $self->add_menu_action(
		$self,
		'view.statusbar',
	);

	$self->{toolbar} = $self->add_menu_action(
		$self,
		'view.toolbar',
	);

	$self->AppendSeparator;

	# View as (Highlighting File Type)
	$self->{view_as_highlighting} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("View Document As..."),
		$self->{view_as_highlighting}
	);

	my %mimes = Padre::Document::menu_view_mimes();
	foreach my $name ( sort keys %mimes ) {
		my $label = $name;
		$label =~ s/^\d+//;
		my $tag = "view.view_as" . lc $label;
		$tag =~ s/\s/_/g;
		$self->add_radio_menu_item(
			$self->{view_as_highlighting},
			name       => $tag,
			label      => $label,
			comment    => sprintf( Wx::gettext('Switch document type to %s'), $label ),
			menu_event => sub { $_[0]->set_mimetype( $mimes{$name} ) },
		);
	}

	$self->AppendSeparator;

	# Editor Functionality
	$self->{lines} = $self->add_menu_action(
		$self,
		'view.lines',
	);

	$self->{folding} = $self->add_menu_action(
		$self,
		'view.folding',
	);

	$self->{show_calltips} = $self->add_menu_action(
		$self,
		'view.show_calltips',
	);

	$self->{currentline} = $self->add_menu_action(
		$self,
		'view.currentline',
	);

	$self->{rightmargin} = $self->add_menu_action(
		$self,
		'view.rightmargin',
	);

	$self->AppendSeparator;

	# Editor Whitespace Layout
	$self->{eol} = $self->add_menu_action(
		$self,
		'view.eol',
	);

	$self->{whitespaces} = $self->add_menu_action(
		$self,
		'view.whitespaces',
	);

	$self->{indentation_guide} = $self->add_menu_action(
		$self,
		'view.indentation_guide',
	);

	$self->{word_wrap} = $self->add_menu_action(
		$self,
		'view.word_wrap',
	);

	$self->AppendSeparator;


	# Font Size
	$self->{font_size} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Font Size"),
		$self->{font_size}
	);
	$self->{font_increase} = $self->add_menu_action(
		$self->{font_size},
		'view.font_increase',
	);

	$self->{font_decrease} = $self->add_menu_action(
		$self->{font_size},
		'view.font_decrease',
	);

	$self->{font_reset} = $self->add_menu_action(
		$self->{font_size},
		'view.font_reset',
	);

	if ( $config->func_bookmark ) {

		$self->AppendSeparator;

		# Bookmark Support
		$self->{bookmark_set} = $self->add_menu_action(
			$self,
			'view.bookmark_set',
		);

		$self->{bookmark_goto} = $self->add_menu_action(
			$self,
			'view.bookmark_goto',
		);

		$self->AppendSeparator;

	}

	# Editor Look and Feel
	$self->{style} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Style"),
		$self->{style}
	);
	my %styles = (
		default   => Wx::gettext('Padre'),
		evening   => Wx::gettext('Evening'),
		night     => Wx::gettext('Night'),
		ultraedit => Wx::gettext('Ultraedit'),
		notepad   => Wx::gettext('Notepad++'),
	);
	my @order = sort { ( $b eq 'default' ) <=> ( $a eq 'default' ) or $styles{$a} cmp $styles{$b} } keys %styles;
	foreach my $name (@order) {
		my $label = $styles{$name};
		my $tag   = "view.view_as_" . lc $label;
		$tag =~ s/\s/_/g;
		my $radio = $self->add_radio_menu_item(
			$self->{style},
			name       => $tag,
			label      => $label,
			comment    => sprintf( Wx::gettext('Switch highlighting colors to %s style'), $label ),
			menu_event => sub {
				$_[0]->change_style($name);
			},
		);
		if ( $config->editor_style and $config->editor_style eq $name ) {
			$radio->Check(1);
		}
	}


	my $dir = File::Spec->catdir( Padre::Constant::CONFIG_DIR, 'styles' );
	my @private =
		map { substr( File::Basename::basename($_), 0, -4 ) } File::Glob::glob( File::Spec->catdir( $dir, '*.yml' ) );
	if (@private) {
		$self->{style}->AppendSeparator;
		foreach my $name (@private) {
			my $label = $name;
			my $tag   = "view.view_as_" . lc $label;
			$tag =~ s/\s/_/g;
			my $radio = $self->add_radio_menu_item(
				$self->{style},
				name       => $tag,
				label      => $label,
				comment    => sprintf( Wx::gettext('Switch highlighting colors to %s style'), $label ),
				menu_event => sub {
					$_[0]->change_style( $name, 1 );
				},
			);
			if ( $config->editor_style and $config->editor_style eq $name ) {
				$radio->Check(1);
			}
		}
	}

	# Language Support
	# TO DO: God this is horrible, there has to be a better way
	my $default  = Padre::Locale::system_rfc4646() || 'x-unknown';
	my $current  = Padre::Locale::rfc4646();
	my %language = Padre::Locale::menu_view_languages();

	# Parent Menu
	$self->{language} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Language"),
		$self->{language}
	);

	# Default menu entry
	$self->{language_default} = $self->add_checked_menu_item(
		$self->{language},
		name       => 'view.language_default',
		label      => Wx::gettext('System Default') . " ($default)",
		comment    => sprintf( Wx::gettext('Switch menus to the default %s'), $default ),
		menu_event => sub {
			$_[0]->change_locale;
		},
	);
	if ( defined $config->locale and $config->locale eq $default ) {
		$self->{language_default}->Check(1);
	}

	$self->{language}->AppendSeparator;

	foreach my $name ( sort { $language{$a} cmp $language{$b} } keys %language ) {
		my $label = $language{$name};

		# Calculate the tag name before we apply any humour :/
		my $tag = "view.view_as_" . lc $label;
		$tag =~ s/\s/_/g;

		if ( $label eq 'English (United Kingdom)' ) {

			# NOTE: A dose of fun in a mostly boring application.
			# With more Padre developers, more countries, and more
			# people in total British English instead of American
			# English CLEARLY it is a FAR better default for us to
			# use.
			# Because it's something of an in joke to English
			# speakers, non-English localisations do NOT show this.
			$label = "English (New Britstralian)";
		}

		my $radio = $self->add_radio_menu_item(
			$self->{language},
			name       => $tag,
			label      => $label,
			comment    => sprintf( Wx::gettext('Switch menus to %s'), $label ),
			menu_event => sub {
				$_[0]->change_locale($name);
			},
		);
		if ( $current eq $name ) {
			$radio->Check(1);
		}
	}

	$self->AppendSeparator;

	# Window Effects
	$self->add_menu_action(
		$self,
		'view.full_screen',
	);

	return $self;
}

sub title {
	my $self = shift;

	return Wx::gettext('&View');
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $config   = $current->config;
	my $document = $current->document;
	my $doc      = $document ? 1 : 0;

	# Simple check state cases from configuration
	$self->{statusbar}->Check( $config->main_statusbar );

	$self->{lines}->Check( $config->editor_linenumbers );
	$self->{folding}->Check( $config->editor_folding );
	$self->{currentline}->Check( $config->editor_currentline );
	$self->{rightmargin}->Check( $config->editor_right_margin_enable );
	$self->{eol}->Check( $config->editor_eol );
	$self->{whitespaces}->Check( $config->editor_whitespace );
	$self->{output}->Check( $config->main_output );
	$self->{outline}->Check( $config->main_outline );
	$self->{directory}->Check( $config->main_directory );
	$self->{functions}->Check( $config->main_functions );
	$self->{lockinterface}->Check( $config->main_lockinterface );
	$self->{indentation_guide}->Check( $config->editor_indentationguides );
	$self->{show_calltips}->Check( $config->editor_calltips );
	$self->{show_syntaxcheck}->Check( $config->main_syntaxcheck );
	$self->{show_errorlist}->Check( $config->main_errorlist );
	$self->{toolbar}->Check( $config->main_toolbar );

	# Check state for word wrap is document-specific
	if ($document) {
		my $editor = $document->editor;
		my $mode   = $editor->GetWrapMode;
		my $wrap   = $self->{word_wrap};
		if ( $mode eq Wx::wxSTC_WRAP_WORD and not $wrap->IsChecked ) {
			$wrap->Check(1);
		} elsif ( $mode eq Wx::wxSTC_WRAP_NONE and $wrap->IsChecked ) {
			$wrap->Check(0);
		}

		# Set mimetype
		my $has_checked = 0;
		if ( $document->get_mimetype ) {
			my %mimes = Padre::Document::menu_view_mimes();
			my @mimes = sort keys %mimes;
			foreach my $pos ( 0 .. scalar @mimes - 1 ) {
				my $radio = $self->{view_as_highlighting}->FindItemByPosition($pos);
				if ( $document->get_mimetype eq $mimes{ $mimes[$pos] } ) {
					$radio->Check(1);
					$has_checked = 1;
				}
			}
		}

		# By default 'Plain Text';
		$self->{view_as_highlighting}->FindItemByPosition(0)->Check(1) unless $has_checked;
	}

	# Disable zooming and bookmarks if there's no current document
	defined( $self->{font_increase} ) and $self->{font_increase}->Enable($doc);
	defined( $self->{font_decrease} ) and $self->{font_decrease}->Enable($doc);
	defined( $self->{font_reset} )    and $self->{font_reset}->Enable($doc);

	# You cannot set a bookmark unless the current document is on disk.
	if ( defined( $self->{bookmark_set} ) ) {
		my $set = ( $doc and defined $document->filename ) ? 1 : 0;
		$self->{bookmark_set}->Enable($set);
	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Menu::View;

# Fully encapsulated View menu

use 5.008;
use strict;
use warnings;
use File::Glob               ();
use Padre::Constant          ();
use Padre::Current           ();
use Padre::Config::Style     ();
use Padre::Wx                ();
use Padre::Wx::ActionLibrary ();
use Padre::Wx::Menu          ();
use Padre::Locale            ();

our $VERSION = '0.66';
our @ISA     = 'Padre::Wx::Menu';

my @GUI_ELEMENTS = qw{
	functions
	todo
	outline
	directory
	output
	show_syntaxcheck
	show_errorlist
	statusbar
	toolbar
};





#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = $main->config;

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
	foreach my $element (@GUI_ELEMENTS) {
		next unless defined $element;

		my $action = 'view.' . $element;

		if ( ref($element) eq 'ARRAY' ) {
			( $element, $action ) = @{$element};
		}

		$self->{$element} = $self->add_menu_action(
			$self,
			$action,
		);
	}

	$self->AppendSeparator;

	SCOPE: {

		# View as (Highlighting File Type)
		$self->{view_as_highlighting} = Wx::Menu->new;
		$self->Append(
			-1,
			Wx::gettext("View Document As..."),
			$self->{view_as_highlighting}
		);

		my %mimes = Padre::MimeTypes::menu_view_mimes();
		foreach my $name ( sort { Wx::gettext( $mimes{$a} ) cmp Wx::gettext( $mimes{$b} ) } keys %mimes ) {
			my $radio = $self->add_menu_action(
				$self->{view_as_highlighting},
				"view.mime.$name",
			);
		}
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

	if ( $config->feature_bookmark ) {

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

	# Font Size
	if ( $config->feature_fontsize ) {
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
	}

	# Editor Look and Feel
	$self->{style} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Style"),
		$self->{style}
	);

	SCOPE: {
		my %styles = Padre::Config::Style->core_styles;
		my @order =
			sort { ( $b eq 'default' ) <=> ( $a eq 'default' ) or $styles{$a} cmp $styles{$b} } keys %styles;

		foreach my $name (@order) {
			my $radio = $self->add_menu_action(
				$self->{style},
				"view.style.$name",
			);
			if ( $config->editor_style and $config->editor_style eq $name ) {
				$radio->Check(1);
			}
		}
	}

	SCOPE: {
		my @styles = Padre::Config::Style->user_styles;
		if (@styles) {
			$self->{style}->AppendSeparator;
			foreach my $name (@styles) {
				my $radio = $self->add_menu_action(
					$self->{style},
					"view.style.$name",
				);
				if ( $config->editor_style and $config->editor_style eq $name ) {
					$radio->Check(1);
				}
			}
		}
	}

	# Language Support
	Padre::Wx::ActionLibrary->init_language_actions;

	# TO DO: God this is horrible, there has to be a better way
	my $default  = Padre::Locale::system_rfc4646() || 'x-unknown';
	my $current  = Padre::Locale::rfc4646();
	my %language = Padre::Locale::menu_view_languages();

	# Parent Menu
	$self->{language} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Language'),
		$self->{language}
	);

	# Default menu entry
	$self->{language_default} = $self->add_menu_action(
		$self->{language},
		'view.language.default',
	);
	if ( defined $config->locale and $config->locale eq $default ) {
		$self->{language_default}->Check(1);
	}

	$self->{language}->AppendSeparator;

	foreach my $name ( sort { $language{$a} cmp $language{$b} } keys %language ) {
		my $radio = $self->add_menu_action(
			$self->{language},
			"view.language.$name",
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
	Wx::gettext('&View');
}

sub refresh {
	my $self     = shift;
	my $current  = Padre::Current::_CURRENT(@_);
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
	$self->{todo}->Check( $config->main_todo );
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
		if ( $document->mimetype ) {
			my %mimes = Padre::MimeTypes::menu_view_mimes();
			my @mimes = sort { lc($a) cmp lc($b) } keys %mimes;
			foreach my $pos ( 0 .. scalar @mimes - 1 ) {
				my $radio = $self->{view_as_highlighting}->FindItemByPosition($pos);
				if ( $document->mimetype eq $mimes{ $mimes[$pos] } ) {
					$radio->Check(1);
					$has_checked = 1;
				}
			}
		}

		# By default 'Plain Text';
		unless ($has_checked) {
			$self->{view_as_highlighting}->FindItemByPosition(0)->Check(1);
		}
	}

	# Disable zooming and bookmarks if there's no current document
	$self->{font_increase}->Enable($doc) if defined $self->{font_increase};
	$self->{font_decrease}->Enable($doc) if defined $self->{font_decrease};
	$self->{font_reset}->Enable($doc)    if defined $self->{font_reset};

	# You cannot set a bookmark unless the current document is on disk.
	if ( defined $self->{bookmark_set} ) {
		my $set = ( $doc and defined $document->filename ) ? 1 : 0;
		$self->{bookmark_set}->Enable($set);
	}

	return;
}

sub gui_element_add {
	my $self = shift;
	my $id   = $_[2];

	# Don't add duplicates
	foreach (@GUI_ELEMENTS) {
		next unless ref $_ eq 'ARRAY';
		return 1 if $_->[2] =~ /^\Q$id\E$/;
	}

	push @GUI_ELEMENTS, [@_];

	return 1;
}

sub gui_element_remove {
	my $self = shift;
	my $id   = shift;

	my @new_gui_elements;

	for (@GUI_ELEMENTS) {
		next if ( ref($_) eq 'ARRAY' ) and ( $_->[2] eq $id );
		push @new_gui_elements, $_;
	}

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

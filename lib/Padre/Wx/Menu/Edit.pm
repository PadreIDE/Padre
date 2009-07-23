package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.41';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Undo/Redo
	$self->{undo} = $self->Append(
		Wx::wxID_UNDO,
		Wx::gettext("&Undo")
	);
	Wx::Event::EVT_MENU(
		$main, # Ctrl-Z
		$self->{undo},
		sub {
			Padre::Current->editor->Undo;
		},
	);

	$self->{redo} = $self->Append(
		Wx::wxID_REDO,
		Wx::gettext("&Redo")
	);
	Wx::Event::EVT_MENU(
		$main, # Ctrl-Y
		$self->{redo},
		sub {
			Padre::Current->editor->Redo;
		},
	);

	$self->AppendSeparator;

	# Selection
	my $edit_select = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Select"),
		$edit_select
	);
	Wx::Event::EVT_MENU(
		$main,
		$edit_select->Append(
			Wx::wxID_SELECTALL,
			Wx::gettext("Select all\tCtrl-A")
		),
		sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_select_all(@_);
		},
	);

	$edit_select->AppendSeparator;
	Wx::Event::EVT_MENU(
		$main,
		$edit_select->Append(
			-1,
			Wx::gettext("Mark selection start\tCtrl-[")
		),
		sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_start;
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$edit_select->Append(
			-1,
			Wx::gettext("Mark selection end\tCtrl-]")
		),
		sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_end;
		},
	);

	Wx::Event::EVT_MENU(
		$main,
		$edit_select->Append(
			-1,
			Wx::gettext("Clear selection marks")
		),
		sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_selection_clear_marks(@_);
		},
	);

	# Cut and Paste
	$self->{cut} = $self->Append(
		Wx::wxID_CUT,
		Wx::gettext("Cu&t\tCtrl-X")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{cut},
		sub {
			my $editor = Padre::Current->editor or return;
			$editor->Cut;
		}
	);

	$self->{copy} = $self->Append(
		Wx::wxID_COPY,
		Wx::gettext("&Copy\tCtrl-C")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{copy},
		sub {
			my $editor = Padre::Current->editor or return;
			$editor->Copy;
		}
	);

	$self->{paste} = $self->Append(
		Wx::wxID_PASTE,
		Wx::gettext("&Paste\tCtrl-V")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{paste},
		sub {
			my $editor = Padre::Current->editor or return;
			$editor->Paste;
		},
	);

	$self->AppendSeparator;

	# Miscellaneous Actions
	$self->{goto} = $self->Append(
		-1,
		Wx::gettext("&Goto\tCtrl-G")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{goto},
		sub {
			Padre::Wx::Main::on_goto(@_);
		},
	);

	$self->{autocomp} = $self->Append(
		-1,
		Wx::gettext("&AutoComp\tCtrl-P")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{autocomp},
		sub {
			Padre::Wx::Main::on_autocompletition(@_);
		},
	);

	$self->{brace_match} = $self->Append(
		-1,
		Wx::gettext("&Brace matching\tCtrl-1")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{brace_match},
		sub {
			Padre::Wx::Main::on_brace_matching(@_);
		},
	);

	$self->{join_lines} = $self->Append(
		-1,
		Wx::gettext("&Join lines\tCtrl-J")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{join_lines},
		sub {
			Padre::Wx::Main::on_join_lines(@_);
		},
	);

	$self->{snippets} = $self->Append(
		-1,
		Wx::gettext("Snippets\tCtrl-Shift-A")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{snippets},
		sub {
			require Padre::Wx::Dialog::Snippets;
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	);

	$self->AppendSeparator;

	# Commenting
	$self->{comment_toggle} = $self->Append(
		-1,
		Wx::gettext("&Toggle Comment\tCtrl-Shift-C")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{comment_toggle},
		sub {
			Padre::Wx::Main::on_comment_toggle_block(@_);
		},
	);

	$self->{comment_out} = $self->Append(
		-1,
		Wx::gettext("&Comment Selected Lines\tCtrl-M")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{comment_out},
		sub {
			Padre::Wx::Main::on_comment_out_block(@_);
		},
	);

	$self->{uncomment} = $self->Append(
		-1,
		Wx::gettext("&Uncomment Selected Lines\tCtrl-Shift-M")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{uncomment},
		sub {
			Padre::Wx::Main::on_uncomment_block(@_);
		},
	);
	$self->AppendSeparator;

	# Conversions and Transforms
	$self->{convert_encoding} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Convert Encoding"),
		$self->{convert_encoding}
	);

	$self->{convert_encoding_system} = $self->{convert_encoding}->Append(
		-1,
		Wx::gettext('Encode document to System Default')
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{convert_encoding_system},
		sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_system_default(@_);
		},
	);

	$self->{convert_encoding_utf8} = $self->{convert_encoding}->Append(
		-1,
		Wx::gettext('Encode document to utf-8')
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{convert_encoding_utf8},
		sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_utf8(@_);
		},
	);

	$self->{convert_encoding_to} = $self->{convert_encoding}->Append(
		-1,
		Wx::gettext('Encode document to...')
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{convert_encoding_to},
		sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to(@_);
		},
	);

	$self->{convert_nl} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Convert EOL"),
		$self->{convert_nl}
	);

	$self->{convert_nl_windows} = $self->{convert_nl}->Append(
		-1,
		Wx::gettext("EOL to Windows")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{convert_nl_windows},
		sub {
			$_[0]->convert_to("WIN");
		},
	);

	$self->{convert_nl_unix} = $self->{convert_nl}->Append(
		-1,
		Wx::gettext("EOL to Unix")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{convert_nl_unix},
		sub {
			$_[0]->convert_to("UNIX");
		},
	);

	$self->{convert_nl_mac} = $self->{convert_nl}->Append(
		-1,
		Wx::gettext("EOL to Mac Classic")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{convert_nl_mac},
		sub {
			$_[0]->convert_to("MAC");
		},
	);

	# Tabs And Spaces
	$self->{tabs} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Tabs and Spaces"),
		$self->{tabs},
	);

	$self->{tabs_to_spaces} = $self->{tabs}->Append(
		-1,
		Wx::gettext("Tabs to Spaces...")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{tabs_to_spaces},
		sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);

	$self->{spaces_to_tabs} = $self->{tabs}->Append(
		-1,
		Wx::gettext("Spaces to Tabs...")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{spaces_to_tabs},
		sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);

	$self->{tabs}->AppendSeparator;

	$self->{delete_trailing} = $self->{tabs}->Append(
		-1,
		Wx::gettext("Delete Trailing Spaces")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{delete_trailing},
		sub {
			$_[0]->on_delete_ending_space;
		},
	);

	$self->{delete_leading} = $self->{tabs}->Append(
		-1,
		Wx::gettext("Delete Leading Spaces")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{delete_leading},
		sub {
			$_[0]->on_delete_leading_space;
		},
	);

	# Upper and Lower Case
	$self->{case} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Upper/Lower Case"),
		$self->{case},
	);

	$self->{case_upper} = $self->{case}->Append(
		-1,
		Wx::gettext("Upper All\tCtrl-Shift-U"),
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{case_upper},
		sub {
			$_[0]->current->editor->UpperCase;
		},
	);

	$self->{case_lower} = $self->{case}->Append(
		-1,
		Wx::gettext("Lower All\tCtrl-U"),
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{case_lower},
		sub {
			$_[0]->current->editor->LowerCase;
		},
	);

	$self->AppendSeparator;

	# Diff tools
	$self->{diff} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Diff Tools"),
		$self->{diff},
	);

	$self->{diff2saved} = $self->{diff}->Append(
		-1,
		Wx::gettext("Diff to Saved Version")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{diff2saved},
		sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	$self->{diff}->AppendSeparator;
	$self->{applydiff2file} = $self->{diff}->Append(
		-1,
		Wx::gettext("Apply Diff to File")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{applydiff2file},
		sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	$self->{applydiff2project} = $self->{diff}->Append(
		-1,
		Wx::gettext("Apply Diff to Project")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{applydiff2project},
		sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);

	$self->{insert_from_file} = $self->Append(
		-1,
		Wx::gettext("Insert From File...")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{insert_from_file},
		sub {
			Padre::Wx::Main::on_insert_from_file(@_);
		},
	);

	$self->AppendSeparator;

	$self->{show_as_number} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Show as ..."),
		$self->{show_as_number}
	);

	$self->{show_as_hex} = $self->{show_as_number}->Append(
		-1,
		Wx::gettext("Show as hexa")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{show_as_hex},
		sub {
			Padre::Wx::Main::show_as_numbers( @_, 'hex' );
		},
	);

	$self->{show_as_decimal} = $self->{show_as_number}->Append(
		-1,
		Wx::gettext("Show as decimal")
	);
	Wx::Event::EVT_MENU(
		$main,
		$self->{show_as_decimal},
		sub {
			Padre::Wx::Main::show_as_numbers( @_, 'decimal' );
		},
	);

	$self->AppendSeparator;

	# User Preferences
	Wx::Event::EVT_MENU(
		$main,
		$self->Append(
			-1,
			Wx::gettext("Preferences")
		),
		sub {
			Padre::Wx::Main::on_preferences(@_);
		},
	);

	return $self;
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $editor   = $current->editor || 0;
	my $text     = $current->text;
	my $document = $current->document;
	my $hasdoc   = $document ? 1 : 0;
	my $newline  = $hasdoc ? $document->get_newline_type : '';

	# Handle the simple cases
	$self->{goto}->Enable($hasdoc);
	$self->{autocomp}->Enable($hasdoc);
	$self->{brace_match}->Enable($hasdoc);
	$self->{join_lines}->Enable($hasdoc);
	$self->{snippets}->Enable($hasdoc);
	$self->{comment_toggle}->Enable($hasdoc);
	$self->{comment_out}->Enable($hasdoc);
	$self->{uncomment}->Enable($hasdoc);
	$self->{diff2saved}->Enable($hasdoc);
	$self->{applydiff2file}->Enable(0);
	$self->{applydiff2project}->Enable(0);
	$self->{insert_from_file}->Enable($hasdoc);
	$self->{case_upper}->Enable($hasdoc);
	$self->{case_lower}->Enable($hasdoc);

	unless ( $newline eq 'WIN' ) {
		$self->{convert_nl_windows}->Enable($hasdoc);
	}
	unless ( $newline eq 'UNIX' ) {
		$self->{convert_nl_unix}->Enable($hasdoc);
	}
	unless ( $newline eq 'MAC' ) {
		$self->{convert_nl_mac}->Enable($hasdoc);
	}
	$self->{tabs_to_spaces}->Enable($hasdoc);
	$self->{spaces_to_tabs}->Enable($hasdoc);
	$self->{delete_leading}->Enable($hasdoc);
	$self->{delete_trailing}->Enable($hasdoc);

	# Handle the complex cases
	my $selection = !!( defined $text and $text ne '' );
	$self->{undo}->Enable( $editor and $editor->CanUndo );
	$self->{redo}->Enable( $editor and $editor->CanRedo );
	$self->{paste}->Enable($editor);

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

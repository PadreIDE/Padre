package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.43';
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
	$self->{undo} = $self->add_menu_item(
		$self,
		name       => 'edit.undo',
		id         => Wx::wxID_UNDO,
		label      => Wx::gettext('&Undo'),
		shortcut   => 'Ctrl-Z',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Undo;
		},
	);

	$self->{redo} = $self->add_menu_item(
		$self,
		name       => 'edit.redo',
		id         => Wx::wxID_REDO,
		label      => Wx::gettext('&Redo'),
		shortcut   => 'Ctrl-Y',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Redo;
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
	$self->add_menu_item(
		$edit_select,
		name       => 'edit.select_all',
		id         => Wx::wxID_SELECTALL,
		label      => Wx::gettext('Select all'),
		shortcut   => 'Ctrl-A',
		menu_event => sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_select_all(@_);
		},
	);

	$edit_select->AppendSeparator;
	$self->add_menu_item(
		$edit_select,
		name       => 'edit.mark_selection_start',
		label      => Wx::gettext('Mark selection start'),
		shortcut   => 'Ctrl-[',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_start;
		},
	);

	$self->add_menu_item(
		$edit_select,
		name       => 'edit.mark_selection_end',
		label      => Wx::gettext('Mark selection end'),
		shortcut   => 'Ctrl-]',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_end;
		},
	);

	$self->add_menu_item(
		$edit_select,
		name       => 'edit.clear_selection_marks',
		label      => Wx::gettext('Clear selection marks'),
		menu_event => sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_selection_clear_marks(@_);
		},
	);

	# Cut and Paste
	$self->{cut} = $self->add_menu_item(
		$self,
		name       => 'edit.cut',
		id         => Wx::wxID_CUT,
		label      => Wx::gettext('Cu&t'),
		shortcut   => 'Ctrl-X',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Cut;
		},
	);

	$self->{copy} = $self->add_menu_item(
		$self,
		name       => 'edit.copy',
		id         => Wx::wxID_COPY,
		label      => Wx::gettext('&Copy'),
		shortcut   => 'Ctrl-C',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Copy;
		},
	);

	$self->{paste} = $self->add_menu_item(
		$self,
		name       => 'edit.paste',
		id         => Wx::wxID_PASTE,
		label      => Wx::gettext('&Paste'),
		shortcut   => 'Ctrl-V',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Paste;
		},
	);

	$self->AppendSeparator;

	# Miscellaneous Actions
	$self->{goto} = $self->add_menu_item(
		$self,
		name       => 'edit.goto',
		label      => Wx::gettext('&Goto Line'),
		shortcut   => 'Ctrl-G',
		menu_event => sub {
			Padre::Wx::Main::on_goto(@_);
		},
	);

	$self->{next_problem} = $self->add_menu_item(
		$self,
		name       => 'edit.next_problem',
		label      => Wx::gettext('&Next Problem'),
		shortcut   => 'Ctrl-.',
		menu_event => sub {
			$main->{syntax}->select_next_problem;
		},
	);

	$self->{quick_fix} = $self->add_menu_item(
		$self,
		name       => 'edit.quick_fix',
		label      => Wx::gettext('&Quick Fix'),
		shortcut   => 'Ctrl-2',
		menu_event => sub {

			my $doc = Padre::Current->document;
			return if not $doc;
			my $editor = $doc->editor;
			$editor->AutoCompSetSeparator(ord '|');
			my @list = ();
			if ( $doc->can('event_on_quick_fix') ) {

				# add list items from callbacks
				my @items = $doc->event_on_quick_fix($editor);
				foreach my $item (@items) {

					# add the list
					push @list, $item->{text};

					# and register its action
					#$listeners{$item_count} = $item->{listener};
				}
				if(scalar @items == 0) {
					@list = (Wx::gettext('No suggestions'));
				}
			}
			my $words = join('|', @list);
			Wx::Event::EVT_STC_USERLISTSELECTION(
				$main, $editor, sub {
					my ($self, $event) = @_;
					print "selected " . $event->GetText ."\n";
				},
			);
			$editor->UserListShow(1, $words);

		},
	);

	$self->{autocomp} = $self->add_menu_item(
		$self,
		name       => 'edit.autocomp',
		label      => Wx::gettext('&AutoComplete'),
		shortcut   => 'Ctrl-P',
		menu_event => sub {
			Padre::Wx::Main::on_autocompletion(@_);
		},
	);

	$self->{brace_match} = $self->add_menu_item(
		$self,
		name       => 'edit.brace_match',
		label      => Wx::gettext('&Brace matching'),
		shortcut   => 'Ctrl-1',
		menu_event => sub {
			Padre::Wx::Main::on_brace_matching(@_);
		},
	);

	$self->{join_lines} = $self->add_menu_item(
		$self,
		name       => 'edit.join_lines',
		label      => Wx::gettext('&Join lines'),
		shortcut   => 'Ctrl-J',
		menu_event => sub {
			Padre::Wx::Main::on_join_lines(@_);
		},
	);

	$self->{snippets} = $self->add_menu_item(
		$self,
		name       => 'edit.snippets',
		label      => Wx::gettext('Snippets'),
		shortcut   => 'Ctrl-Shift-A',
		menu_event => sub {
			require Padre::Wx::Dialog::Snippets;
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	);

	$self->AppendSeparator;

	# Commenting
	$self->{comment_toggle} = $self->add_menu_item(
		$self,
		name       => 'edit.comment_toggle',
		label      => Wx::gettext('&Toggle Comment'),
		shortcut   => 'Ctrl-Shift-C',
		menu_event => sub {
			Padre::Wx::Main::on_comment_toggle_block(@_);
		},
	);

	$self->{comment_out} = $self->add_menu_item(
		$self,
		name       => 'edit.comment_out',
		label      => Wx::gettext('&Comment Selected Lines'),
		shortcut   => 'Ctrl-M',
		menu_event => sub {
			Padre::Wx::Main::on_comment_out_block(@_);
		},
	);

	$self->{uncomment} = $self->add_menu_item(
		$self,
		name       => 'edit.uncomment',
		label      => Wx::gettext('&Uncomment Selected Lines'),
		shortcut   => 'Ctrl-Shift-M',
		menu_event => sub {
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

	$self->{convert_encoding_system} = $self->add_menu_item(
		$self->{convert_encoding},
		name       => 'edit.convert_encoding_system',
		label      => Wx::gettext('Encode document to System Default'),
		menu_event => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_system_default(@_);
		},
	);

	$self->{convert_encoding_utf8} = $self->add_menu_item(
		$self->{convert_encoding},
		name       => 'edit.convert_encoding_utf8',
		label      => Wx::gettext('Encode document to utf-8'),
		menu_event => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_utf8(@_);
		},
	);

	$self->{convert_encoding_to} = $self->add_menu_item(
		$self->{convert_encoding},
		name       => 'edit.convert_encoding_to',
		label      => Wx::gettext('Encode document to...'),
		menu_event => sub {
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

	$self->{convert_nl_windows} = $self->add_menu_item(
		$self->{convert_nl},
		name       => 'edit.convert_nl_windows',
		label      => Wx::gettext('EOL to Windows'),
		menu_event => sub {
			$_[0]->convert_to("WIN");
		},
	);

	$self->{convert_nl_unix} = $self->add_menu_item(
		$self->{convert_nl},
		name       => 'edit.convert_nl_unix',
		label      => Wx::gettext('EOL to Unix'),
		menu_event => sub {
			$_[0]->convert_to("UNIX");
		},
	);

	$self->{convert_nl_mac} = $self->add_menu_item(
		$self->{convert_nl},
		name       => 'edit.convert_nl_mac',
		label      => Wx::gettext('EOL to Mac Classic'),
		menu_event => sub {
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

	$self->{tabs_to_spaces} = $self->add_menu_item(
		$self->{tabs},
		name       => 'edit.tabs_to_spaces',
		label      => Wx::gettext('Tabs to Spaces...'),
		menu_event => sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);

	$self->{spaces_to_tabs} = $self->add_menu_item(
		$self->{tabs},
		name       => 'edit.spaces_to_tabs',
		label      => Wx::gettext('Spaces to Tabs...'),
		menu_event => sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);

	$self->{tabs}->AppendSeparator;

	$self->{delete_trailing} = $self->add_menu_item(
		$self->{tabs},
		name       => 'edit.delete_trailing',
		label      => Wx::gettext('Delete Trailing Spaces'),
		menu_event => sub {
			$_[0]->on_delete_ending_space;
		},
	);

	$self->{delete_leading} = $self->add_menu_item(
		$self->{tabs},
		name       => 'edit.delete_leading',
		label      => Wx::gettext('Delete Leading Spaces'),
		menu_event => sub {
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

	$self->{case_upper} = $self->add_menu_item(
		$self->{case},
		name       => 'edit.case_upper',
		label      => Wx::gettext('Upper All'),
		shortcut   => 'Ctrl-Shift-U',
		menu_event => sub {
			$_[0]->current->editor->UpperCase;
		},
	);

	$self->{case_lower} = $self->add_menu_item(
		$self->{case},
		name       => 'edit.case_lower',
		label      => Wx::gettext('Lower All'),
		shortcut   => 'Ctrl-U',
		menu_event => sub {
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

	$self->{diff2saved} = $self->add_menu_item(
		$self->{diff},
		name       => 'edit.diff2saved',
		label      => Wx::gettext('Diff to Saved Version'),
		menu_event => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	$self->{diff}->AppendSeparator;
	$self->{applydiff2file} = $self->add_menu_item(
		$self->{diff},
		name       => 'edit.applydiff2file',
		label      => Wx::gettext('Apply Diff to File'),
		menu_event => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	$self->{applydiff2project} = $self->add_menu_item(
		$self->{diff},
		name       => 'edit.applydiff2project',
		label      => Wx::gettext('Apply Diff to Project'),
		menu_event => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);

	$self->{insert_from_file} = $self->add_menu_item(
		$self,
		name       => 'edit.insert_from_file',
		label      => Wx::gettext('Insert From File...'),
		menu_event => sub {
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

	$self->{show_as_hex} = $self->add_menu_item(
		$self->{show_as_number},
		name       => 'edit.show_as_hex',
		label      => Wx::gettext('Show as hexa'),
		menu_event => sub {
			Padre::Wx::Main::show_as_numbers( @_, 'hex' );
		},
	);

	$self->{show_as_decimal} = $self->add_menu_item(
		$self->{show_as_number},
		name       => 'edit.show_as_decimal',
		label      => Wx::gettext('Show as decimal'),
		menu_event => sub {
			Padre::Wx::Main::show_as_numbers( @_, 'decimal' );
		},
	);

	$self->AppendSeparator;

	# User Preferences
	$self->add_menu_item(
		$self,
		name       => 'edit.preferences',
		label      => Wx::gettext('Preferences'),
		menu_event => sub {
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
	$self->{next_problem}->Enable($hasdoc);
	$self->{autocomp}->Enable($hasdoc);
	$self->{brace_match}->Enable($hasdoc);
	$self->{join_lines}->Enable($hasdoc);
	$self->{snippets}->Enable($hasdoc);
	$self->{comment_toggle}->Enable($hasdoc);
	$self->{comment_out}->Enable($hasdoc);
	$self->{uncomment}->Enable($hasdoc);
	$self->{convert_encoding_system}->Enable($hasdoc);
	$self->{convert_encoding_utf8}->Enable($hasdoc);
	$self->{convert_encoding_to}->Enable($hasdoc);
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
	$self->{show_as_hex}->Enable($hasdoc);
	$self->{show_as_decimal}->Enable($hasdoc);

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

package Padre::Action::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Util     ('_T');
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.53';


#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	my $self = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

	# Undo/Redo
	Padre::Action->new(
		name        => 'edit.undo',
		id          => Wx::wxID_UNDO,
		need_editor => 1,

		#		need        => sub {
		#			my %objects = @_;
		#			return 0 if !defined( $objects{editor} );
		#			return $objects{editor}->CanUndo;
		#		},
		label      => _T('&Undo'),
		comment    => _T('Undo last change in current file'),
		shortcut   => 'Ctrl-Z',
		toolbar    => 'actions/edit-undo',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Undo;
		},
	);

	Padre::Action->new(
		name        => 'edit.redo',
		id          => Wx::wxID_REDO,
		need_editor => 1,

		#		need        => sub {
		#			my %objects = @_;
		#			return 0 if !defined( $objects{editor} );
		#			return $objects{editor}->CanRedo;
		#		},
		label      => _T('&Redo'),
		comment    => _T('Redo last undo'),
		shortcut   => 'Ctrl-Y',
		toolbar    => 'actions/edit-redo',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Redo;
		},
	);

	Padre::Action->new(
		name        => 'edit.select_all',
		id          => Wx::wxID_SELECTALL,
		need_editor => 1,
		label       => _T('Select all'),
		comment     => _T('Select all the text in the current document'),
		shortcut    => 'Ctrl-A',
		toolbar     => 'actions/edit-select-all',
		menu_event  => sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_select_all(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.mark_selection_start',
		need_editor => 1,
		label       => _T('Mark selection start'),
		comment     => _T('Mark the place where the selection should start'),
		shortcut    => 'Ctrl-[',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_start;
		},
	);

	Padre::Action->new(
		name        => 'edit.mark_selection_end',
		need_editor => 1,
		label       => _T('Mark selection end'),
		comment     => _T('Mark the place where the selection should end'),
		shortcut    => 'Ctrl-]',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_end;
		},
	);

	Padre::Action->new(
		name        => 'edit.clear_selection_marks',
		need_editor => 1,
		label       => _T('Clear selection marks'),
		comment     => _T('Remove all the selection marks'),
		menu_event  => sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_selection_clear_marks(@_);
		},
	);

	# Cut and Paste
	Padre::Action->new(
		name           => 'edit.cut',
		id             => Wx::wxID_CUT,
		need_editor    => 1,
		need_selection => 1,
		label          => _T('Cu&t'),
		comment        => _T('Remove the current selection and put it in the clipboard'),
		shortcut       => 'Ctrl-X',
		toolbar        => 'actions/edit-cut',
		menu_event     => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Cut;
		},
	);

	Padre::Action->new(
		name           => 'edit.copy',
		id             => Wx::wxID_COPY,
		need_editor    => 1,
		need_selection => 1,
		label          => _T('&Copy'),
		comment        => _T('Put the current selection in the clipboard'),
		shortcut       => 'Ctrl-C',
		toolbar        => 'actions/edit-copy',
		menu_event     => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Copy;
		},
	);

	# Special copy

	Padre::Action->new(
		name        => 'edit.copy_filename',
		need_editor => 1,
		need_file   => 1,
		label       => _T('Copy full filename'),
		comment     => _T('Put the full path of the current file in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->{file}->{filename} );
		},
	);

	Padre::Action->new(
		name        => 'edit.copy_basename',
		need_editor => 1,
		need_file   => 1,
		label       => _T('Copy filename'),
		comment     => _T('Put the name of the current file in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->{file}->basename );
		},
	);

	Padre::Action->new(
		name        => 'edit.copy_dirname',
		need_file   => 1,
		need_editor => 1,
		label       => _T('Copy directory name'),
		comment     => _T('Put the full path of the directory of the current file in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->{file}->dirname );
		},
	);

	Padre::Action->new(
		name        => 'edit.copy_content',
		need_editor => 1,
		label       => _T('Copy editor content'),
		comment     => _T('Put the content of the current document in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->text_get );
		},
	);

	# Paste
	Padre::Action->new(
		name        => 'edit.paste',
		need_editor => 1,
		id          => Wx::wxID_PASTE,
		label       => _T('&Paste'),
		comment     => _T('Paste the clipboard to the current location'),
		shortcut    => 'Ctrl-V',
		toolbar     => 'actions/edit-paste',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Paste;
		},
	);

	# Miscellaneous Actions
	Padre::Action->new(
		name       => 'edit.goto',
		label      => _T('&Goto Line'),
		comment    => _T('Ask the user for a row number and jump there'),
		shortcut   => 'Ctrl-G',
		menu_event => sub {
			Padre::Wx::Main::on_goto(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.next_problem',
		need_editor => 1,
		label       => _T('&Next Problem'),
		comment     => _T('Jumpt to the code that triggered the next error'),
		shortcut    => 'Ctrl-.',
		menu_event  => sub {
			$main->{syntax}->select_next_problem;
		},
	);

	Padre::Action->new(
		name        => 'edit.quick_fix',
		need_editor => 1,
		label       => _T('&Quick Fix'),
		comment     => _T('Apply one of the quick fixes for the current document'),
		shortcut    => 'Ctrl-2',
		menu_event  => sub {

			my $doc = Padre::Current->document;
			return if not $doc;
			my $editor = $doc->editor;
			$editor->AutoCompSetSeparator( ord '|' );
			my @list  = ();
			my @items = ();
			eval {

				# Find available quick fixes from provider
				my $provider = $doc->get_quick_fix_provider;
				@items = $provider->quick_fix_list( $doc, $editor );

				# Add quick list items from document's quick fix provider
				foreach my $item (@items) {
					push @list, $item->{text};
				}
			};
			if ($@) {
				warn "Error while calling get_quick_fix_provider: $@\n";
			}
			my $empty_list = ( scalar @list == 0 );
			if ($empty_list) {
				@list = ( _T('No suggestions') );
			}
			my $words = join( '|', @list );
			Wx::Event::EVT_STC_USERLISTSELECTION(
				$main, $editor,
				sub {
					my ( $self, $event ) = @_;
					return if $empty_list;
					my $text = $event->GetText;
					my $selection;
					for my $item (@items) {
						if ( $item->{text} eq $text ) {
							$selection = $item;
							last;
						}
					}
					if ($selection) {
						eval { &{ $selection->{listener} }(); };
						if ($@) {
							warn "Failed while calling Quick fix " . $selection->{text} . "\n";
						}
					}
				},
			);
			$editor->UserListShow( 1, $words );
		},
	);

	Padre::Action->new(
		name        => 'edit.autocomp',
		need_editor => 1,
		label       => _T('&AutoComplete'),
		comment     => _T('Offer completions to the current string. See Preferences'),
		shortcut    => 'Ctrl-Space',
		menu_event  => sub {
			Padre::Wx::Main::on_autocompletion(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.brace_match',
		need_editor => 1,
		label       => _T('&Brace matching'),
		comment     => _T('Jump to the matching opening or closing brace: {, }, (, )'),
		shortcut    => 'Ctrl-1',
		menu_event  => sub {
			Padre::Wx::Main::on_brace_matching(@_);
		},
	);

	Padre::Action->new(
		name           => 'edit.join_lines',
		need_editor    => 1,
		need_selection => 1,
		label          => _T('&Join lines'),
		comment        => _T('Join the next line to the end of the current line.'),
		shortcut       => 'Ctrl-J',
		menu_event     => sub {
			Padre::Wx::Main::on_join_lines(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.insert.insert_special',
		need_editor => 1,
		label       => _T('Insert Special Value'),
		comment     => _T('Select a Date, Filename or other value and insert at the current location'),
		shortcut    => 'Ctrl-Shift-I',
		menu_event  => sub {
			require Padre::Wx::Dialog::SpecialValues;
			Padre::Wx::Dialog::SpecialValues->insert_special(@_);
		},

	);

	Padre::Action->new(
		name        => 'edit.insert.snippets',
		need_editor => 1,
		label       => _T('Snippets'),
		comment     => _T('Select and insert a snippet at the current location'),
		shortcut    => 'Ctrl-Shift-A',
		menu_event  => sub {
			require Padre::Wx::Dialog::Snippets;
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.insert.from_file',
		need_editor => 1,
		label       => _T('Insert From File...'),
		comment     => _T('Select a file and insert its content at the current location'),
		menu_event  => sub {
			Padre::Wx::Main::on_insert_from_file(@_);
		},
	);

	# Commenting
	Padre::Action->new(
		name           => 'edit.comment_toggle',
		need_editor    => 1,
		need_selection => 1,
		label          => _T('&Toggle Comment'),
		comment        => _T('Comment out or remove comment out of selected lines in the document'),
		shortcut       => 'Ctrl-Shift-C',
		toolbar        => 'actions/toggle-comments',
		menu_event     => sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'TOGGLE' );
		},
	);

	Padre::Action->new(
		name           => 'edit.comment',
		need_editor    => 1,
		need_selection => 1,
		label          => _T('&Comment Selected Lines'),
		comment        => _T('Comment out selected lines in the document'),
		shortcut       => 'Ctrl-M',
		menu_event     => sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'COMMENT' );
		},
	);

	Padre::Action->new(
		name           => 'edit.uncomment',
		need_editor    => 1,
		need_selection => 1,
		label          => _T('&Uncomment Selected Lines'),
		comment        => _T('Remove comment out of selected lines in the document'),
		shortcut       => 'Ctrl-Shift-M',
		menu_event     => sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'UNCOMMENT' );
		},
	);

	# Conversions and Transforms
	Padre::Action->new(
		name        => 'edit.convert_encoding_system',
		need_editor => 1,
		label       => _T('Encode document to System Default'),
		comment     => _T('Change the encoding of the current document to the default of the operating system'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_system_default(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_encoding_utf8',
		need_editor => 1,
		label       => _T('Encode document to utf-8'),
		comment     => _T('Change the encoding of the current document to utf-8'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_utf8(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_encoding_to',
		need_editor => 1,
		label       => _T('Encode document to...'),
		comment     => _T('Select an encoding and encode the document to that'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_nl_windows',
		need_editor => 1,
		label       => _T('EOL to Windows'),
		comment => _T('Change the end of line character of the current document to those used in files on MS Windows'),
		menu_event => sub {
			$_[0]->convert_to('WIN');
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_nl_unix',
		need_editor => 1,
		label       => _T('EOL to Unix'),
		comment => _T('Change the end of line character of the current document to that used on Unix, Linux, Mac OSX'),
		menu_event => sub {
			$_[0]->convert_to('UNIX');
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_nl_mac',
		need_editor => 1,
		label       => _T('EOL to Mac Classic'),
		comment     => _T('Change the end of line character of the current document to that used on Mac Classic'),
		menu_event  => sub {
			$_[0]->convert_to('MAC');
		},
	);

	# Tabs And Spaces
	Padre::Action->new(
		name        => 'edit.tabs_to_spaces',
		need_editor => 1,
		label       => _T('Tabs to Spaces...'),
		comment     => _T('Convert all tabs to spaces in the current document'),
		menu_event  => sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);

	Padre::Action->new(
		name        => 'edit.spaces_to_tabs',
		need_editor => 1,
		label       => _T('Spaces to Tabs...'),
		comment     => _T('Convert all the spaces to tabs in the current document'),
		menu_event  => sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);

	Padre::Action->new(
		name        => 'edit.delete_trailing',
		need_editor => 1,
		label       => _T('Delete Trailing Spaces'),
		comment     => _T('Remove the spaces from the end of the selected lines'),
		menu_event  => sub {
			$_[0]->on_delete_ending_space;
		},
	);

	Padre::Action->new(
		name        => 'edit.delete_leading',
		need_editor => 1,
		label       => _T('Delete Leading Spaces'),
		comment     => _T('Remove the spaces from the beginning of the selected lines'),
		menu_event  => sub {
			$_[0]->on_delete_leading_space;
		},
	);

	# Upper and Lower Case
	Padre::Action->new(
		name        => 'edit.case_upper',
		need_editor => 1,
		label       => _T('Upper All'),
		comment     => _T('Change the current selection to upper case'),
		shortcut    => 'Ctrl-Shift-U',
		menu_event  => sub {
			$_[0]->current->editor->UpperCase;
		},
	);

	Padre::Action->new(
		name        => 'edit.case_lower',
		need_editor => 1,
		label       => _T('Lower All'),
		comment     => _T('Change the current selection to lower case'),
		shortcut    => 'Ctrl-U',
		menu_event  => sub {
			$_[0]->current->editor->LowerCase;
		},
	);

	Padre::Action->new(
		name        => 'edit.diff2saved',
		need_editor => 1,
		label       => _T('Diff to Saved Version'),
		comment     => _T('Compare the file in the editor to that on the disk and show the diff in the output window'),
		menu_event  => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	Padre::Action->new(
		name        => 'edit.applydiff2file',
		need_editor => 1,
		label       => _T('Apply Diff to File'),
		comment     => _T('Apply a patch file to the current document'),
		menu_event  => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	Padre::Action->new(
		name        => 'edit.applydiff2project',
		need_editor => 1,
		label       => _T('Apply Diff to Project'),
		comment     => _T('Apply a patch file to the current project'),
		menu_event  => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);

	# End diff tools

	Padre::Action->new(
		name        => 'edit.filter_tool',
		need_editor => 1,
		label       => _T('Filter through external tool'),
		comment     => _T('Filters the selection (or the whole document) through any external command.'),
		menu_event  => sub {
			Padre::Wx::Main::on_filter_tool(@_);
		},
	);

	Padre::Action->new(
		name    => 'edit.regex',
		label   => _T('Regex editor'),
		comment => _T('Open the regular expression editing window'),

		menu_event => sub {
			Padre::Wx::Main::open_regex_editor(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.show_as_hex',
		need_editor => 1,
		label       => _T('Show as hexa'),
		comment     => _T('Show the ASCII values of the selected text in hexa in the output window'),
		menu_event  => sub {
			Padre::Wx::Main::show_as_numbers( @_, 'hex' );
		},
	);

	Padre::Action->new(
		name        => 'edit.show_as_decimal',
		need_editor => 1,
		label       => _T('Show as decimal'),
		comment     => _T('Show the ASCII values of the selected text in decimal numbers in the output window'),
		menu_event  => sub {
			Padre::Wx::Main::show_as_numbers( @_, 'decimal' );
		},
	);

	# User Preferences
	Padre::Action->new(
		name       => 'edit.preferences',
		label      => _T('Preferences'),
		comment    => _T('Edit the user preferences'),
		menu_event => sub {
			Padre::Wx::Main::on_preferences(@_);
		},
	);

	return $self;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

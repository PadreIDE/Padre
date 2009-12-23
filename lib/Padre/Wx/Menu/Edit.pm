package Padre::Wx::Menu::Edit;

# Fully encapsulated Edit menu

use 5.008;
use strict;
use warnings;
use Padre::Current qw{_CURRENT};
use Padre::Wx       ();
use Padre::Wx::Menu ();

our $VERSION = '0.52';
our @ISA     = 'Padre::Wx::Menu';





#####################################################################
# Padre::Wx::Menu Methods

sub new {

	# TO DO: Convert this to Padre::Action::Edit

	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Undo/Redo
	$self->{undo} = $self->add_menu_item(
		$self,
		name        => 'edit.undo',
		id          => Wx::wxID_UNDO,
		need_editor => 1,

		#		need        => sub {
		#			my %objects = @_;
		#			return 0 if !defined( $objects{editor} );
		#			return $objects{editor}->CanUndo;
		#		},
		label      => Wx::gettext('&Undo'),
		comment    => Wx::gettext('Undo last change in current file'),
		shortcut   => 'Ctrl-Z',
		menu_event => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Undo;
		},
	);

	$self->{redo} = $self->add_menu_item(
		$self,
		name        => 'edit.redo',
		id          => Wx::wxID_REDO,
		need_editor => 1,

		#		need        => sub {
		#			my %objects = @_;
		#			return 0 if !defined( $objects{editor} );
		#			return $objects{editor}->CanRedo;
		#		},
		label      => Wx::gettext('&Redo'),
		comment    => Wx::gettext('Redo last undo'),
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
		name        => 'edit.select_all',
		id          => Wx::wxID_SELECTALL,
		need_editor => 1,
		label       => Wx::gettext('Select all'),
		comment     => Wx::gettext('Select all the text in the current document'),
		shortcut    => 'Ctrl-A',
		menu_event  => sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_select_all(@_);
		},
	);

	$edit_select->AppendSeparator;

	$self->add_menu_item(
		$edit_select,
		name        => 'edit.mark_selection_start',
		need_editor => 1,
		label       => Wx::gettext('Mark selection start'),
		comment     => Wx::gettext('Mark the place where the selection should start'),
		shortcut    => 'Ctrl-[',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_start;
		},
	);

	$self->add_menu_item(
		$edit_select,
		name        => 'edit.mark_selection_end',
		need_editor => 1,
		label       => Wx::gettext('Mark selection end'),
		comment     => Wx::gettext('Mark the place where the selection should end'),
		shortcut    => 'Ctrl-]',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_end;
		},
	);

	$self->add_menu_item(
		$edit_select,
		name        => 'edit.clear_selection_marks',
		need_editor => 1,
		label       => Wx::gettext('Clear selection marks'),
		comment     => Wx::gettext('Remove all the selection marks'),
		menu_event  => sub {
			require Padre::Wx::Editor;
			Padre::Wx::Editor::text_selection_clear_marks(@_);
		},
	);

	# Cut and Paste
	$self->{cut} = $self->add_menu_item(
		$self,
		name           => 'edit.cut',
		id             => Wx::wxID_CUT,
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('Cu&t'),
		comment        => Wx::gettext('Remove the current selection and put it in the clipboard'),
		shortcut       => 'Ctrl-X',
		menu_event     => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Cut;
		},
	);

	$self->{copy} = $self->add_menu_item(
		$self,
		name           => 'edit.copy',
		id             => Wx::wxID_COPY,
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Copy'),
		comment        => Wx::gettext('Put the current selection in the clipboard'),
		shortcut       => 'Ctrl-C',
		menu_event     => sub {
			my $editor = Padre::Current->editor or return;
			$editor->Copy;
		},
	);

	# Special copy
	my $edit_copy = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Copy specials"),
		$edit_copy
	);

	$self->add_menu_item(
		$edit_copy,
		name        => 'edit.copy_filename',
		need_editor => 1,
		need_file   => 1,
		label       => Wx::gettext('Copy full filename'),
		comment        => Wx::gettext('Put the full path of the current file in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->{file}->{filename} );
		},
	);

	$self->add_menu_item(
		$edit_copy,
		name        => 'edit.copy_basename',
		need_editor => 1,
		need_file   => 1,
		label       => Wx::gettext('Copy filename'),
		comment     => Wx::gettext('Put the name of the current file in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->{file}->basename );
		},
	);

	$self->add_menu_item(
		$edit_copy,
		name        => 'edit.copy_dirname',
		need_file   => 1,
		need_editor => 1,
		label       => Wx::gettext('Copy directory name'),
		comment     => Wx::gettext('Put the full path of the directory of the current file in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->{file}->dirname );
		},
	);

	$self->add_menu_item(
		$edit_copy,
		name        => 'edit.copy_content',
		need_editor => 1,
		label       => Wx::gettext('Copy editor content'),
		comment     => Wx::gettext('Put the content of the current document in the clipboard'),
		menu_event  => sub {
			my $document = Padre::Current->document;
			return if !defined( $document->{file} );
			my $editor = Padre::Current->editor;
			$editor->put_text_to_clipboard( $document->text_get );
		},
	);

	# Paste
	$self->{paste} = $self->add_menu_item(
		$self,
		name        => 'edit.paste',
		need_editor => 1,
		id          => Wx::wxID_PASTE,
		label       => Wx::gettext('&Paste'),
		comment     => Wx::gettext('Paste the clipboard to the current location'),
		shortcut    => 'Ctrl-V',
		menu_event  => sub {
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
		comment    => Wx::gettext('Ask the user for a row number and jump there'),
		shortcut   => 'Ctrl-G',
		menu_event => sub {
			Padre::Wx::Main::on_goto(@_);
		},
	);

	$self->{next_problem} = $self->add_menu_item(
		$self,
		name        => 'edit.next_problem',
		need_editor => 1,
		label       => Wx::gettext('&Next Problem'),
		comment     => Wx::gettext('Jumpt to the code  that triggered the next error'),
		shortcut    => 'Ctrl-.',
		menu_event  => sub {
			$main->{syntax}->select_next_problem;
		},
	);

	$self->{quick_fix} = $self->add_menu_item(
		$self,
		name        => 'edit.quick_fix',
		need_editor => 1,
		label       => Wx::gettext('&Quick Fix'),
		comment     => Wx::gettext('Apply one of the quick fixes for the current document'),
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
				@list = ( Wx::gettext('No suggestions') );
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

	$self->{autocomp} = $self->add_menu_item(
		$self,
		name        => 'edit.autocomp',
		need_editor => 1,
		label       => Wx::gettext('&AutoComplete'),
		comment     => Wx::gettext('Offer completions to the current string. See Preferences'),
		shortcut    => 'Ctrl-Space',
		menu_event  => sub {
			Padre::Wx::Main::on_autocompletion(@_);
		},
	);

	$self->{brace_match} = $self->add_menu_item(
		$self,
		name        => 'edit.brace_match',
		need_editor => 1,
		label       => Wx::gettext('&Brace matching'),
		comment     => Wx::gettext('Jump to the matching opening or closing brace: {, }, (, )'),
		shortcut    => 'Ctrl-1',
		menu_event  => sub {
			Padre::Wx::Main::on_brace_matching(@_);
		},
	);

	$self->{join_lines} = $self->add_menu_item(
		$self,
		name           => 'edit.join_lines',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Join lines'),
		comment        => Wx::gettext('Join the next line to the end of the current line.'),
		shortcut       => 'Ctrl-J',
		menu_event     => sub {
			Padre::Wx::Main::on_join_lines(@_);
		},
	);

	my $submenu = Wx::Menu->new;
	$self->{insert_submenu} = $self->AppendSubMenu( $submenu, Wx::gettext('Insert') );

	$self->{insert_special} = $self->add_menu_item(
		$submenu,
		name        => 'edit.insert.insert_special',
		need_editor => 1,
		label       => Wx::gettext('Insert Special Value'),
		comment     => Wx::gettext('Select a Date, Filename or other value and insert at the current location'),
		shortcut    => 'Ctrl-Shift-I',
		menu_event  => sub {
			require Padre::Wx::Dialog::SpecialValues;
			Padre::Wx::Dialog::SpecialValues->insert_special(@_);
		},

	);

	$self->{snippets} = $self->add_menu_item(
		$submenu,
		name        => 'edit.insert.snippets',
		need_editor => 1,
		label       => Wx::gettext('Snippets'),
		comment     => Wx::gettext('Select and insert a snippet at the current location'),
		shortcut    => 'Ctrl-Shift-A',
		menu_event  => sub {
			require Padre::Wx::Dialog::Snippets;
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	);

	$self->{insert_from_file} = $self->add_menu_item(
		$submenu,
		name        => 'edit.insert.from_file',
		need_editor => 1,
		label       => Wx::gettext('Insert From File...'),
		comment     => Wx::gettext('Select a file and insert its content at the current location'),
		menu_event  => sub {
			Padre::Wx::Main::on_insert_from_file(@_);
		},
	);

	$self->AppendSeparator;

	# Commenting
	$self->{comment_toggle} = $self->add_menu_item(
		$self,
		name           => 'edit.comment_toggle',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Toggle Comment'),
		comment     => Wx::gettext('Comment out or remove comment out of selected lines in the docuemnt'),
		shortcut       => 'Ctrl-Shift-C',
		menu_event     => sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'TOGGLE' );
		},
	);

	$self->{comment} = $self->add_menu_item(
		$self,
		name           => 'edit.comment',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Comment Selected Lines'),
		comment        => Wx::gettext('Comment out selected lines in the document'),
		shortcut       => 'Ctrl-M',
		menu_event     => sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'COMMENT' );
		},
	);

	$self->{uncomment} = $self->add_menu_item(
		$self,
		name           => 'edit.uncomment',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Uncomment Selected Lines'),
		comment        => Wx::gettext('Remove comment out of selected lines in the document'),
		shortcut       => 'Ctrl-Shift-M',
		menu_event     => sub {
			Padre::Wx::Main::on_comment_block( $_[0], 'UNCOMMENT' );
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
		name        => 'edit.convert_encoding_system',
		need_editor => 1,
		label       => Wx::gettext('Encode document to System Default'),
		comment     => Wx::gettext('Change the encoding of the current document to the default of the operating system'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_system_default(@_);
		},
	);

	$self->{convert_encoding_utf8} = $self->add_menu_item(
		$self->{convert_encoding},
		name        => 'edit.convert_encoding_utf8',
		need_editor => 1,
		label       => Wx::gettext('Encode document to utf-8'),
		comment     => Wx::gettext('Change the encoding of the current document to utf-8'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_utf8(@_);
		},
	);

	$self->{convert_encoding_to} = $self->add_menu_item(
		$self->{convert_encoding},
		name        => 'edit.convert_encoding_to',
		need_editor => 1,
		label       => Wx::gettext('Encode document to...'),
		comment     => Wx::gettext('Select an encoding and encode the document to that'),
		menu_event  => sub {
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
		name        => 'edit.convert_nl_windows',
		need_editor => 1,
		label       => Wx::gettext('EOL to Windows'),
		comment     => Wx::gettext('Change the end of line character of the current document to those used in files on MS Windows'),
		menu_event  => sub {
			$_[0]->convert_to('WIN');
		},
	);

	$self->{convert_nl_unix} = $self->add_menu_item(
		$self->{convert_nl},
		name        => 'edit.convert_nl_unix',
		need_editor => 1,
		label       => Wx::gettext('EOL to Unix'),
		comment     => Wx::gettext('Change the end of line character of the current document to that used on Unix, Linux, Mac OSX'),
		menu_event  => sub {
			$_[0]->convert_to('UNIX');
		},
	);

	$self->{convert_nl_mac} = $self->add_menu_item(
		$self->{convert_nl},
		name        => 'edit.convert_nl_mac',
		need_editor => 1,
		label       => Wx::gettext('EOL to Mac Classic'),
		comment     => Wx::gettext('Change the end of line character of the current document to that used on Mac Classic'),
		menu_event  => sub {
			$_[0]->convert_to('MAC');
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
		name        => 'edit.tabs_to_spaces',
		need_editor => 1,
		label       => Wx::gettext('Tabs to Spaces...'),
		comment     => Wx::gettext('Convert all tabs to spaces in the current document'),
		menu_event  => sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);

	$self->{spaces_to_tabs} = $self->add_menu_item(
		$self->{tabs},
		name        => 'edit.spaces_to_tabs',
		need_editor => 1,
		label       => Wx::gettext('Spaces to Tabs...'),
		comment     => Wx::gettext('Convert all the spaces to tabs in the current document'),
		menu_event  => sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);

	$self->{tabs}->AppendSeparator;

	$self->{delete_trailing} = $self->add_menu_item(
		$self->{tabs},
		name        => 'edit.delete_trailing',
		need_editor => 1,
		label       => Wx::gettext('Delete Trailing Spaces'),
		comment     => Wx::gettext('Remove the spaces from the end of the selected lines'),
		menu_event  => sub {
			$_[0]->on_delete_ending_space;
		},
	);

	$self->{delete_leading} = $self->add_menu_item(
		$self->{tabs},
		name        => 'edit.delete_leading',
		need_editor => 1,
		label       => Wx::gettext('Delete Leading Spaces'),
		comment     => Wx::gettext('Remove the spaces from the beginning of the selected lines'),
		menu_event  => sub {
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
		name        => 'edit.case_upper',
		need_editor => 1,
		label       => Wx::gettext('Upper All'),
		comment     => Wx::gettext('Change the current selection to upper case'),
		shortcut    => 'Ctrl-Shift-U',
		menu_event  => sub {
			$_[0]->current->editor->UpperCase;
		},
	);

	$self->{case_lower} = $self->add_menu_item(
		$self->{case},
		name        => 'edit.case_lower',
		need_editor => 1,
		label       => Wx::gettext('Lower All'),
		comment     => Wx::gettext('Change the current selection to lower case'),
		shortcut    => 'Ctrl-U',
		menu_event  => sub {
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
		name        => 'edit.diff2saved',
		need_editor => 1,
		label       => Wx::gettext('Diff to Saved Version'),
		comment     => Wx::gettext('Compare the file in the editor to that on the disk and show the diff in the output window'),
		menu_event  => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	$self->{diff}->AppendSeparator;
	$self->{applydiff2file} = $self->add_menu_item(
		$self->{diff},
		name        => 'edit.applydiff2file',
		need_editor => 1,
		label       => Wx::gettext('Apply Diff to File'),
		comment    => Wx::gettext('Apply a patch file to a the current document'),
		menu_event  => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);
	$self->{applydiff2project} = $self->add_menu_item(
		$self->{diff},
		name        => 'edit.applydiff2project',
		need_editor => 1,
		label       => Wx::gettext('Apply Diff to Project'),
		comment    => Wx::gettext('Apply a patch file to a the current project'),
		menu_event  => sub {
			Padre::Wx::Main::on_diff(@_);
		},
	);

	# End diff tools


	$self->{filter_tool} = $self->add_menu_item(
		$self,
		name        => 'edit.filter_tool',
		need_editor => 1,
		label       => Wx::gettext('Filter through external tool'),
		comment     => Wx::gettext('Filters the selection (or the whole document) through any external command.'),
		menu_event  => sub {
			Padre::Wx::Main::on_filter_tool(@_);
		},
	);

	$self->AppendSeparator;

	$self->add_menu_item(
		$self,
		name       => 'edit.regex',
		label      => Wx::gettext('Regex editor'),
		comment    => Wx::gettext('Open the regular expression editing window'),

		menu_event => sub {
			Padre::Wx::Main::open_regex_editor(@_);
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
		name        => 'edit.show_as_hex',
		need_editor => 1,
		label       => Wx::gettext('Show as hexa'),
		comment     => Wx::gettext('Show the ASCII values of the selected text in hexa in the output window'),
		menu_event  => sub {
			Padre::Wx::Main::show_as_numbers( @_, 'hex' );
		},
	);

	$self->{show_as_decimal} = $self->add_menu_item(
		$self->{show_as_number},
		name        => 'edit.show_as_decimal',
		need_editor => 1,
		label       => Wx::gettext('Show as decimal'),
		comment     => Wx::gettext('Show the ASCII values of the selected text in decimal numbers in the output window'),
		menu_event  => sub {
			Padre::Wx::Main::show_as_numbers( @_, 'decimal' );
		},
	);

	$self->AppendSeparator;

	# User Preferences
	$self->add_menu_item(
		$self,
		name       => 'edit.preferences',
		label      => Wx::gettext('Preferences'),
		comment    => Wx::gettext('Edit the user preferences'),
		menu_event => sub {
			Padre::Wx::Main::on_preferences(@_);
		},
	);

	return $self;
}

sub title {
	my $self = shift;

	return Wx::gettext('&Edit');
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
	$self->{quick_fix}->Enable($hasdoc);
	$self->{autocomp}->Enable($hasdoc);
	$self->{brace_match}->Enable($hasdoc);
	$self->{join_lines}->Enable($hasdoc);

	$self->{insert_special}->Enable($hasdoc);
	$self->{snippets}->Enable($hasdoc);
	$self->{comment_toggle}->Enable($hasdoc);
	$self->{comment}->Enable($hasdoc);
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
	$self->{undo}->Enable($editor);
	$self->{redo}->Enable($editor);
	$self->{paste}->Enable($editor);

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

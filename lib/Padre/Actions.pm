package Padre::Actions;

# Defines all the core actions for Padre.
# It's a little on the bloaty side, but splitting it into different files
# won't make it any better.

use 5.008005;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ();
use Padre::Action   ();
use Padre::Logger;

our $VERSION = '0.66';





######################################################################
# Action Database

sub init {
	my $class  = shift;
	my $main   = shift;
	my $config = $main->config;

	# Script Execution

	Padre::Action->new(
		name       => 'internal.dump_padre',
		label      => Wx::gettext('Dump the Padre object to STDOUT'),
		comment    => Wx::gettext('Dumps the complete Padre object to STDOUT for testing/debugging.'),
		menu_event => sub {
			require File::Spec;
			require Data::Dumper;
			open(
				my $dumpfh,
				'>',
				File::Spec->catfile(
					Padre::Constant::PADRE_HOME,
					'padre.dump',
				),
			);
			print $dumpfh "# Begin Padre dump\n" . Data::Dumper::Dumper( $_[0]->ide ) . "# End Padre dump\n" . "1;\n";
			close $dumpfh;
		},
	);

	# Delay the action queue

	Padre::Action->new(
		name       => 'internal.wait10',
		label      => Wx::gettext('Delay the action queue for 10 seconds'),
		comment    => Wx::gettext('Stops processing of other action queue items for 10 seconds'),
		menu_event => sub {
			sleep 10;
		},
	);

	Padre::Action->new(
		name       => 'internal.wait30',
		label      => Wx::gettext('Delay the action queue for 30 seconds'),
		comment    => Wx::gettext('Stops processing of other action queue items for 30 seconds'),
		menu_event => sub {
			sleep 30;
		},
	);

	# Create new things

	Padre::Action->new(
		name       => 'file.new',
		label      => Wx::gettext('&New'),
		comment    => Wx::gettext('Open a new empty document'),
		shortcut   => 'Ctrl-N',
		toolbar    => 'actions/document-new',
		menu_event => sub {
			$_[0]->on_new;
		},
	);

	Padre::Action->new(
		name       => 'file.new_p5_script',
		label      => Wx::gettext('Perl 5 Script'),
		comment    => Wx::gettext('Open a document with a skeleton Perl 5 script'),
		menu_event => sub {
			$_[0]->on_new_from_template('pl');
		},
	);

	Padre::Action->new(
		name       => 'file.new_p5_module',
		label      => Wx::gettext('Perl 5 Module'),
		comment    => Wx::gettext('Open a document with a skeleton Perl 5 module'),
		menu_event => sub {
			$_[0]->on_new_from_template('pm');
		},
	);

	Padre::Action->new(
		name       => 'file.new_p5_test',
		label      => Wx::gettext('Perl 5 Test'),
		comment    => Wx::gettext('Open a document with a skeleton Perl 5 test  script'),
		menu_event => sub {
			$_[0]->on_new_from_template('t');
		},
	);

	# Split by language

	Padre::Action->new(
		name       => 'file.new_p6_script',
		label      => Wx::gettext('Perl 6 Script'),
		comment    => Wx::gettext('Open a document with a skeleton Perl 6 script'),
		menu_event => sub {
			$_[0]->on_new_from_template('p6');
		},
	);

	# Split projects from files

	Padre::Action->new(
		name       => 'file.new_p5_distro',
		label      => Wx::gettext('Perl Distribution...'),
		comment    => Wx::gettext('Setup a skeleton Perl module distribution'),
		menu_event => sub {
			require Padre::Wx::Dialog::ModuleStart;
			Padre::Wx::Dialog::ModuleStart->start($_[0]);
		},
	);

	### NOTE: Add support for plugins here

	# Open things

	Padre::Action->new(
		name       => 'file.open',
		id         => Wx::wxID_OPEN,
		label      => Wx::gettext('&Open'),
		comment    => Wx::gettext('Browse directory of the current document to open one or several files'),
		shortcut   => 'Ctrl-O',
		toolbar    => 'actions/document-open',
		menu_event => sub {
			$_[0]->on_open;
		},
	);

	Padre::Action->new(
		name    => 'file.openurl',
		label   => Wx::gettext('Open &URL...'),
		comment => Wx::gettext('Open a file from a remote location'),

		# Is shown as Ctrl-O and I don't know why
		# shortcut => 'Ctrl-Shift-O',
		menu_event => sub {
			$_[0]->on_open_url;
		},
	);

	Padre::Action->new(
		name        => 'file.open_in_file_browser',
		need_editor => 1,
		need_file   => 1,
		label       => Wx::gettext('Open in File Browser'),
		comment     => Wx::gettext('Opens the current document using the file browser'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$_[0]->on_open_in_file_browser( $document->filename );
		},
	);

	Padre::Action->new(
		name        => 'file.open_with_default_system_editor',
		label       => Wx::gettext('Open with Default System Editor'),
		need_editor => 1,
		need_file   => 1,
		comment     => Wx::gettext('Opens the file with the default system editor'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$_[0]->on_open_with_default_system_editor( $document->filename );
		},
	);

	Padre::Action->new(
		name        => 'file.open_in_command_line',
		need_editor => 1,
		need_file   => 1,
		label       => Wx::gettext('Open in Command Line'),
		comment     => Wx::gettext('Opens a command line using the current document folder'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$_[0]->on_open_in_command_line( $document->filename );
		},
	);

	Padre::Action->new(
		name       => 'file.open_example',
		label      => Wx::gettext('Open Example'),
		comment    => Wx::gettext('Browse the directory of the installed examples to open one file'),
		toolbar    => 'stock/generic/stock_example',
		menu_event => sub {
			$_[0]->on_open_example;
		},
	);

	Padre::Action->new(
		name        => 'file.close',
		id          => Wx::wxID_CLOSE,
		need_editor => 1,
		label       => Wx::gettext('&Close'),
		comment     => Wx::gettext('Close current document'),
		shortcut    => 'Ctrl-W',
		toolbar     => 'actions/x-document-close',
		menu_event  => sub {
			$_[0]->close;
		},
	);

	# Close things

	Padre::Action->new(
		name        => 'file.close_current_project',
		need_editor => 1,
		label       => Wx::gettext('Close this Project'),
		comment     => Wx::gettext('Close all the files belonging to the current project'),
		shortcut    => 'Ctrl-Shift-W',
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			my $dir      = $document->project_dir;
			unless ( defined $dir ) {
				$_[0]->error( Wx::gettext("File is not in a project") );
			}
			$_[0]->close_where(
				sub {
					defined $_[0]->project_dir
					and
					$_[0]->project_dir eq $dir;
				}
			);
		},
	);

	Padre::Action->new(
		name        => 'file.close_other_projects',
		need_editor => 1,
		label       => Wx::gettext('Close other Projects'),
		comment     => Wx::gettext('Close all the files that do not belong to the current project'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			my $dir      = $document->project_dir;
			unless ( defined $dir ) {
				$_[0]->error( Wx::gettext("File is not in a project") );
			}
			$_[0]->close_where(
				sub {
					$_[0]->project_dir
					and
					$_[0]->project_dir ne $dir;
				}
			);
		},
	);

	Padre::Action->new(
		name        => 'file.close_all',
		need_editor => 1,
		label       => Wx::gettext('Close all Files'),
		comment     => Wx::gettext('Close all the files open in the editor'),
		menu_event  => sub {
			$_[0]->close_all;
		},
	);

	Padre::Action->new(
		name        => 'file.close_all_but_current',
		need_editor => 1,
		label       => Wx::gettext('Close all other Files'),
		comment     => Wx::gettext('Close all the files except the current one'),
		menu_event  => sub {
			$_[0]->close_all( $_[0]->notebook->GetSelection );
		},
	);

	Padre::Action->new(
		name        => 'file.close_some',
		need_editor => 1,
		label       => Wx::gettext('Close Files...'),
		comment     => Wx::gettext('Select some open files for closing'),
		menu_event  => sub {
			$_[0]->on_close_some;
		},
	);

	Padre::Action->new(
		name        => 'file.reload_file',
		need_editor => 1,
		label       => Wx::gettext('Reload File'),
		comment     => Wx::gettext('Reload current file from disk'),
		menu_event  => sub {
			$_[0]->on_reload_file;
		},
	);

	Padre::Action->new(
		name        => 'file.reload_all',
		need_editor => 1,
		label       => Wx::gettext('Reload All'),
		comment     => Wx::gettext('Reload all files currently open'),
		menu_event  => sub {
			$_[0]->on_reload_all;
		},
	);

	Padre::Action->new(
		name        => 'file.reload_some',
		need_editor => 1,
		label       => Wx::gettext('Reload Some...'),
		comment     => Wx::gettext('Select some open files for reload'),
		menu_event  => sub {
			$_[0]->on_reload_some;
		},
	);

	# Save files

	Padre::Action->new(
		name          => 'file.save',
		id            => Wx::wxID_SAVE,
		need_editor   => 1,
		need_modified => 1,
		label         => Wx::gettext('&Save'),
		comment       => Wx::gettext('Save current document'),
		shortcut      => 'Ctrl-S',
		toolbar       => 'actions/document-save',
		menu_event    => sub {
			$_[0]->on_save;
		},
	);

	Padre::Action->new(
		name        => 'file.save_as',
		id          => Wx::wxID_SAVEAS,
		need_editor => 1,
		label       => Wx::gettext('Save &As...'),
		comment     => Wx::gettext('Allow the selection of another name to save the current document'),
		shortcut    => 'F12',
		toolbar     => 'actions/document-save-as',
		menu_event  => sub {
			$_[0]->on_save_as;
		},
	);

	Padre::Action->new(
		name        => 'file.save_intuition',
		id          => -1,
		need_editor => 1,
		label       => Wx::gettext('Save Intuition'),
		comment =>
			Wx::gettext('For new document try to guess the filename based on the file content and offer to save it.'),
		shortcut   => 'Ctrl-Shift-S',
		menu_event => sub {
			$_[0]->on_save_intuition;
		},
	);

	Padre::Action->new(
		name        => 'file.save_all',
		need_editor => 1,
		label       => Wx::gettext('Save All'),
		comment     => Wx::gettext('Save all the files'),
		toolbar     => 'actions/stock_data-save',
		menu_event  => sub {
			$_[0]->on_save_all;
		},
	);

	# Specialised open and close functions

	Padre::Action->new(
		name       => 'file.open_selection',
		label      => Wx::gettext('Open Selection'),
		comment    => Wx::gettext('List the files that match the current selection and let the user pick one to open'),
		shortcut   => 'Ctrl-Shift-O',
		menu_event => sub {
			$_[0]->on_open_selection;
		},
	);

	Padre::Action->new(
		name    => 'file.open_session',
		label   => Wx::gettext('Open Session...'),
		comment =>
			Wx::gettext('Select a session. Close all the files currently open and open all the listed in the session'),
		shortcut   => 'Ctrl-Alt-O',
		menu_event => sub {
			require Padre::Wx::Dialog::SessionManager;
			Padre::Wx::Dialog::SessionManager->new($_[0])->show;
		},
	);

	Padre::Action->new(
		name       => 'file.save_session',
		label      => Wx::gettext('Save Session...'),
		comment    => Wx::gettext('Ask for a session name and save the list of files currently opened'),
		shortcut   => 'Ctrl-Alt-S',
		menu_event => sub {
			require Padre::Wx::Dialog::SessionSave;
			Padre::Wx::Dialog::SessionSave->new($_[0])->show;
		},
	);

	# Print files

	Padre::Action->new(
		name => 'file.print',

		# TO DO: As long as the ID is here, the shortcut won't work on Ubuntu.
		id         => Wx::wxID_PRINT,
		label      => Wx::gettext('&Print...'),
		comment    => Wx::gettext('Print the current document'),
		shortcut   => 'Ctrl-P',
		menu_event => sub {
			require Wx::Print;
			require Padre::Wx::Printout;
			my $printer  = Wx::Printer->new;
			my $printout = Padre::Wx::Printout->new(
				$_[0]->current->editor, "Print",
			);
			$printer->Print( $_[0], $printout, 1 );
			$printout->Destroy;
			return;
		},
	);

	# Recent things

	Padre::Action->new(
		name       => 'file.open_recent_files',
		label      => Wx::gettext('Open All Recent Files'),
		comment    => Wx::gettext('Open all the files listed in the recent files list'),
		menu_event => sub {
			$_[0]->on_open_all_recent_files;
		},
	);

	Padre::Action->new(
		name       => 'file.clean_recent_files',
		label      => Wx::gettext('Clean Recent Files List'),
		comment    => Wx::gettext('Remove the entries from the recent files list'),
		menu_event => sub {
			my $lock = Padre::Current->main->lock( 'UPDATE', 'DB', 'refresh_recent' );
			Padre::DB::History->delete( 'where type = ?', 'files' );
		},
	);

	# Word Stats

	Padre::Action->new(
		name        => 'file.doc_stat',
		label       => Wx::gettext('Document Statistics'),
		comment     => Wx::gettext('Word count and other statistics of the current document'),
		need_editor => 1,
		toolbar     => 'actions/document-properties',
		menu_event  => sub {
			$_[0]->on_doc_stats;
		},
	);

	# Exiting

	Padre::Action->new(
		name       => 'file.quit',
		label      => Wx::gettext('&Quit'),
		comment    => Wx::gettext('Ask if unsaved files should be saved and then exit Padre'),
		shortcut   => 'Ctrl-Q',
		menu_event => sub {
			$_[0]->Close;
		},
	);

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
		label      => Wx::gettext('&Undo'),
		comment    => Wx::gettext('Undo last change in current file'),
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
		label      => Wx::gettext('&Redo'),
		comment    => Wx::gettext('Redo last undo'),
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
		label       => Wx::gettext('Select All'),
		comment     => Wx::gettext('Select all the text in the current document'),
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
		label       => Wx::gettext('Mark Selection Start'),
		comment     => Wx::gettext('Mark the place where the selection should start'),
		shortcut    => 'Ctrl-[',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_start;
		},
	);

	Padre::Action->new(
		name        => 'edit.mark_selection_end',
		need_editor => 1,
		label       => Wx::gettext('Mark Selection End'),
		comment     => Wx::gettext('Mark the place where the selection should end'),
		shortcut    => 'Ctrl-]',
		menu_event  => sub {
			my $editor = Padre::Current->editor or return;
			$editor->text_selection_mark_end;
		},
	);

	Padre::Action->new(
		name        => 'edit.clear_selection_marks',
		need_editor => 1,
		label       => Wx::gettext('Clear Selection Marks'),
		comment     => Wx::gettext('Remove all the selection marks'),
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
		label          => Wx::gettext('Cu&t'),
		comment        => Wx::gettext('Remove the current selection and put it in the clipboard'),
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
		label          => Wx::gettext('&Copy'),
		comment        => Wx::gettext('Put the current selection in the clipboard'),
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
		label       => Wx::gettext('Copy Full Filename'),
		comment     => Wx::gettext('Put the full path of the current file in the clipboard'),
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
		label       => Wx::gettext('Copy Filename'),
		comment     => Wx::gettext('Put the name of the current file in the clipboard'),
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
		label       => Wx::gettext('Copy Directory Name'),
		comment     => Wx::gettext('Put the full path of the directory of the current file in the clipboard'),
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
		label       => Wx::gettext('Copy Editor Content'),
		comment     => Wx::gettext('Put the content of the current document in the clipboard'),
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
		label       => Wx::gettext('&Paste'),
		comment     => Wx::gettext('Paste the clipboard to the current location'),
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
		label      => Wx::gettext('&Go To...'),
		comment    => Wx::gettext('Jump to a specific line number or character position'),
		shortcut   => 'Ctrl-G',
		menu_event => sub {
			shift->on_goto(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.next_problem',
		need_editor => 1,
		label       => Wx::gettext('&Next Problem'),
		comment     => Wx::gettext('Jump to the code that triggered the next error'),
		shortcut    => 'Ctrl-.',
		menu_event  => sub {
			$_[0]->{syntax}->select_next_problem if $_[0]->{syntax};
		},
	);

	Padre::Action->new(
		name        => 'edit.quick_fix',
		need_editor => 1,
		label       => Wx::gettext('&Quick Fix'),
		comment     => Wx::gettext('Apply one of the quick fixes for the current document'),
		shortcut    => 'Ctrl-2',
		menu_event  => sub {
			my $main     = shift;
			my $document = $main->current->document or return;
			my $editor   = $document->editor;
			$editor->AutoCompSetSeparator( ord '|' );
			my @list  = ();
			my @items = ();
			eval {

				# Find available quick fixes from provider
				my $provider = $document->get_quick_fix_provider;
				@items = $provider->quick_fix_list( $document, $editor );

				# Add quick list items from document's quick fix provider
				foreach my $item ( @items ) {
					push @list, $item->{text};
				}
			};
			warn "Error while calling get_quick_fix_provider: $@\n" if $@;
			my $empty_list = ( scalar @list == 0 );
			if ($empty_list) {
				@list = ( Wx::gettext('No suggestions') );
			}
			my $words = join( '|', @list );

			Wx::Event::EVT_STC_USERLISTSELECTION(
				$main,
				$editor,
				sub {
					return if $empty_list;
					my $text = $_[1]->GetText;
					my $selection;
					foreach my $item (@items) {
						if ( $item->{text} eq $text ) {
							$selection = $item;
							last;
						}
					}
					if ($selection) {
						eval {
							&{ $selection->{listener} }();
						};
						warn "Failed while calling Quick fix $selection->{text}\n" if $@;
					}
				},
			);
			$editor->UserListShow( 1, $words );
		},
	);

	Padre::Action->new(
		name        => 'edit.autocomp',
		need_editor => 1,
		label       => Wx::gettext('&Autocomplete'),
		comment     => Wx::gettext('Offer completions to the current string. See Preferences'),
		shortcut    => 'Ctrl-Space',
		menu_event  => sub {
			shift->on_autocompletion(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.brace_match',
		need_editor => 1,
		label       => Wx::gettext('&Brace Matching'),
		comment     => Wx::gettext('Jump to the matching opening or closing brace: { }, ( ), [ ], < >'),
		shortcut    => 'Ctrl-1',
		menu_event  => sub {
			shift->on_brace_matching(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.brace_match_select',
		need_editor => 1,
		label       => Wx::gettext('&Select to Matching Brace'),
		comment     => Wx::gettext('Select to the matching opening or closing brace'),
		shortcut    => 'Ctrl-4',
		menu_event  => sub {
			shift->current->editor->select_to_matching_brace;
		}
	);

	Padre::Action->new(
		name           => 'edit.join_lines',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Join Lines'),
		comment        => Wx::gettext('Join the next line to the end of the current line.'),
		shortcut       => 'Ctrl-J',
		menu_event     => sub {
			shift->on_join_lines(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.insert.insert_special',
		need_editor => 1,
		label       => Wx::gettext('Special Value...'),
		comment     => Wx::gettext('Select a date, filename or other value and insert at the current location'),
		shortcut    => 'Ctrl-Shift-I',
		menu_event  => sub {
			require Padre::Wx::Dialog::SpecialValues;
			Padre::Wx::Dialog::SpecialValues->insert_special(@_);
		},

	);

	Padre::Action->new(
		name        => 'edit.insert.snippets',
		need_editor => 1,
		label       => Wx::gettext('Snippets...'),
		comment     => Wx::gettext('Select and insert a snippet at the current location'),
		shortcut    => 'Ctrl-Shift-A',
		menu_event  => sub {
			require Padre::Wx::Dialog::Snippets;
			Padre::Wx::Dialog::Snippets->snippets(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.insert.from_file',
		need_editor => 1,
		label       => Wx::gettext('File...'),
		comment     => Wx::gettext('Select a file and insert its content at the current location'),
		menu_event  => sub {
			shift->on_insert_from_file(@_);
		},
	);

	# Commenting

	Padre::Action->new(
		name           => 'edit.comment_toggle',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Toggle Comment'),
		comment        => Wx::gettext('Comment out or remove comment out of selected lines in the document'),
		shortcut       => 'Ctrl-Shift-C',
		toolbar        => 'actions/toggle-comments',
		menu_event     => sub {
			shift->on_comment_block('TOGGLE');
		},
	);

	Padre::Action->new(
		name           => 'edit.comment',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Comment Selected Lines'),
		comment        => Wx::gettext('Comment out selected lines in the document'),
		shortcut       => 'Ctrl-M',
		menu_event     => sub {
			shift->on_comment_block('COMMENT');
		},
	);

	Padre::Action->new(
		name           => 'edit.uncomment',
		need_editor    => 1,
		need_selection => 1,
		label          => Wx::gettext('&Uncomment Selected Lines'),
		comment        => Wx::gettext('Remove comment out of selected lines in the document'),
		shortcut       => 'Ctrl-Shift-M',
		menu_event     => sub {
			shift->on_comment_block('UNCOMMENT');
		},
	);

	# Conversions and Transforms

	Padre::Action->new(
		name        => 'edit.convert_encoding_system',
		need_editor => 1,
		label       => Wx::gettext('Encode Document to System Default'),
		comment    => Wx::gettext('Change the encoding of the current document to the default of the operating system'),
		menu_event => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_system_default(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_encoding_utf8',
		need_editor => 1,
		label       => Wx::gettext('Encode Document to utf-8'),
		comment     => Wx::gettext('Change the encoding of the current document to utf-8'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to_utf8(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_encoding_to',
		need_editor => 1,
		label       => Wx::gettext('Encode Document to...'),
		comment     => Wx::gettext('Select an encoding and encode the document to that'),
		menu_event  => sub {
			require Padre::Wx::Dialog::Encode;
			Padre::Wx::Dialog::Encode::encode_document_to(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_nl_windows',
		need_editor => 1,
		label       => Wx::gettext('EOL to Windows'),
		comment     => Wx::gettext(
			'Change the end of line character of the current document to those used in files on MS Windows'),
		menu_event => sub {
			$_[0]->convert_to('WIN');
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_nl_unix',
		need_editor => 1,
		label       => Wx::gettext('EOL to Unix'),
		comment     => Wx::gettext(
			'Change the end of line character of the current document to that used on Unix, Linux, Mac OSX'),
		menu_event => sub {
			$_[0]->convert_to('UNIX');
		},
	);

	Padre::Action->new(
		name        => 'edit.convert_nl_mac',
		need_editor => 1,
		label       => Wx::gettext('EOL to Mac Classic'),
		comment => Wx::gettext('Change the end of line character of the current document to that used on Mac Classic'),
		menu_event => sub {
			$_[0]->convert_to('MAC');
		},
	);

	# Tabs And Spaces

	Padre::Action->new(
		name        => 'edit.tabs_to_spaces',
		need_editor => 1,
		label       => Wx::gettext('Tabs to Spaces...'),
		comment     => Wx::gettext('Convert all tabs to spaces in the current document'),
		menu_event  => sub {
			$_[0]->on_tab_and_space('Tab_to_Space');
		},
	);

	Padre::Action->new(
		name        => 'edit.spaces_to_tabs',
		need_editor => 1,
		label       => Wx::gettext('Spaces to Tabs...'),
		comment     => Wx::gettext('Convert all the spaces to tabs in the current document'),
		menu_event  => sub {
			$_[0]->on_tab_and_space('Space_to_Tab');
		},
	);

	Padre::Action->new(
		name        => 'edit.delete_trailing',
		need_editor => 1,
		label       => Wx::gettext('Delete Trailing Spaces'),
		comment     => Wx::gettext('Remove the spaces from the end of the selected lines'),
		menu_event  => sub {
			$_[0]->on_delete_ending_space;
		},
	);

	Padre::Action->new(
		name        => 'edit.delete_leading',
		need_editor => 1,
		label       => Wx::gettext('Delete Leading Spaces'),
		comment     => Wx::gettext('Remove the spaces from the beginning of the selected lines'),
		menu_event  => sub {
			$_[0]->on_delete_leading_space;
		},
	);

	# Upper and Lower Case

	Padre::Action->new(
		name        => 'edit.case_upper',
		need_editor => 1,
		label       => Wx::gettext('Upper All'),
		comment     => Wx::gettext('Change the current selection to upper case'),
		shortcut    => 'Ctrl-Shift-U',
		menu_event  => sub {
			$_[0]->current->editor->UpperCase;
		},
	);

	Padre::Action->new(
		name        => 'edit.case_lower',
		need_editor => 1,
		label       => Wx::gettext('Lower All'),
		comment     => Wx::gettext('Change the current selection to lower case'),
		shortcut    => 'Ctrl-U',
		menu_event  => sub {
			$_[0]->current->editor->LowerCase;
		},
	);

	Padre::Action->new(
		name        => 'edit.diff2saved',
		need_editor => 1,
		label       => Wx::gettext('Diff to Saved Version'),
		comment =>
			Wx::gettext('Compare the file in the editor to that on the disk and show the diff in the output window'),
		menu_event => sub {
			shift->on_diff(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.applydiff2file',
		need_editor => 1,
		label       => Wx::gettext('Apply Diff to File'),
		comment     => Wx::gettext('Apply a patch file to the current document'),
		menu_event  => sub {
			shift->on_diff(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.applydiff2project',
		need_editor => 1,
		label       => Wx::gettext('Apply Diff to Project'),
		comment     => Wx::gettext('Apply a patch file to the current project'),
		menu_event  => sub {
			shift->on_diff(@_);
		},
	);

	# End diff tools

	Padre::Action->new(
		name        => 'edit.filter_tool',
		need_editor => 1,
		label       => Wx::gettext('Filter through External Tool...'),
		comment     => Wx::gettext('Filters the selection (or the whole document) through any external command.'),
		menu_event  => sub {
			shift->on_filter_tool(@_);
		},
	);

	Padre::Action->new(
		name       => 'edit.regex',
		label      => Wx::gettext('Regex Editor'),
		comment    => Wx::gettext('Open the regular expression editing window'),
		menu_event => sub {
			shift->open_regex_editor(@_);
		},
	);

	Padre::Action->new(
		name        => 'edit.show_as_hex',
		need_editor => 1,
		label       => Wx::gettext('Show as Hexadecimal'),
		comment     =>
			Wx::gettext('Show the ASCII values of the selected text in hexadecimal notation in the output window'),
		menu_event => sub {
			shift->show_as_numbers( @_, 'hex' );
		},
	);

	Padre::Action->new(
		name        => 'edit.show_as_decimal',
		need_editor => 1,
		label       => Wx::gettext('Show as Decimal'),
		comment     => Wx::gettext('Show the ASCII values of the selected text in decimal numbers in the output window'),
		menu_event  => sub {
			shift->show_as_numbers( @_, 'decimal' );
		},
	);

	# User Preferences

	Padre::Action->new(
		name       => 'edit.preferences',
		label      => Wx::gettext('Preferences'),
		comment    => Wx::gettext('Edit the user preferences'),
		menu_event => sub {
			shift->on_preferences(@_);
		},
	);

	# Search

	Padre::Action->new(
		name        => 'search.find',
		id          => Wx::wxID_FIND,
		need_editor => 1,
		label       => Wx::gettext('&Find...'),
		comment     => Wx::gettext('Find text or regular expressions using a traditional dialog'),
		shortcut    => 'Ctrl-F',
		toolbar     => 'actions/edit-find',
		menu_event  => sub {
			$_[0]->find->find;
		},
	);

	Padre::Action->new(
		name        => 'search.find_next',
		label       => Wx::gettext('Find Next'),
		need_editor => 1,
		comment     => Wx::gettext('Repeat the last find to find the next match'),
		shortcut    => 'F3',
		menu_event  => sub {
			my $editor = $_[0]->current->editor or return;

			# Handle the obvious case with nothing selected
			my ( $position1, $position2 ) = $editor->GetSelection;
			if ( $position1 == $position2 ) {
				return $_[0]->search_next;
			}

			# Multiple lines are also done the obvious way
			my $line1 = $editor->LineFromPosition($position1);
			my $line2 = $editor->LineFromPosition($position2);
			unless ( $line1 == $line2 ) {
				return $_[0]->search_next;
			}

			# Special case. Make and save a non-regex
			# case-insensitive search and advance to the next hit.
			my $search = Padre::Search->new(
				find_case    => 0,
				find_regex   => 0,
				find_reverse => 0,
				find_term    => $editor->GetTextRange(
					$position1, $position2,
				),
			);
			$_[0]->search_next($search);

			# If we can't find another match, show a message
			if ( ( $editor->GetSelection )[0] == $position1 ) {
				$_[0]->message( Wx::gettext('Failed to find any matches') );
			}
		},
	);

	Padre::Action->new(
		name        => 'search.find_previous',
		need_editor => 1,
		label       => Wx::gettext('&Find Previous'),
		comment     => Wx::gettext('Repeat the last find, but backwards to find the previous match'),
		shortcut    => 'Shift-F3',
		menu_event  => sub {
			$_[0]->search_previous;
		},
	);

	# Quick Find: starts search with selected text

	Padre::Action->new(
		name        => 'search.quick_find',
		need_editor => 1,
		label       => Wx::gettext('Quick Find'),
		comment     => Wx::gettext('Incremental search seen at the bottom of the window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->config->set(
				'find_quick',
				$_[1]->IsChecked ? 1 : 0,
			);
			return;
		},
		checked_default => $config->find_quick,
	);

	# We should be able to remove F4 and Shift+F4 and hook this functionality
	# to F3 and Shift+F3 Incremental find (#60)
	Padre::Action->new(
		name        => 'search.quick_find_next',
		need_editor => 1,
		label       => Wx::gettext('Find Next'),
		comment     => Wx::gettext('Find next matching text using a toolbar-like dialog at the bottom of the editor'),
		shortcut    => 'F4',
		menu_event  => sub {
			$_[0]->fast_find->search('next');
		},
	);

	Padre::Action->new(
		name        => 'search.quick_find_previous',
		need_editor => 1,
		label       => Wx::gettext('Find Previous'),
		comment  => Wx::gettext('Find previous matching text using a toolbar-like dialog at the bottom of the editor'),
		shortcut => 'Shift-F4',
		menu_event => sub {
			$_[0]->fast_find->search('previous');
		},
	);

	# Search and Replace

	Padre::Action->new(
		name        => 'search.replace',
		need_editor => 1,
		label       => Wx::gettext('Replace...'),
		comment     => Wx::gettext('Find a text and replace it'),
		shortcut    => 'Ctrl-R',
		toolbar     => 'actions/edit-find-replace',
		menu_event  => sub {
			$_[0]->replace->find;
		},
	);

	# Recursive Search

	Padre::Action->new(
		name       => 'search.find_in_files',
		label      => Wx::gettext('Find in Fi&les...'),
		comment    => Wx::gettext('Search for a text in all files below a given directory'),
		shortcut   => 'Ctrl-Shift-F',
		menu_event => sub {
			require Padre::Wx::Ack;
			Padre::Wx::Ack::on_ack(@_);
		},
	);

	Padre::Action->new(
		name       => 'search.open_resource',
		label      => Wx::gettext('Open Resource...'),
		comment    => Wx::gettext('Type in a filter to select a file'),
		shortcut   => 'Ctrl-Shift-R',
		toolbar    => 'places/folder-saved-search',
		menu_event => sub {
			#Create and show the dialog
			my $open_resource_dialog = $_[0]->open_resource;
			$open_resource_dialog->show;
		},
	);

	Padre::Action->new(
		name       => 'search.quick_menu_access',
		label      => Wx::gettext('Quick Menu Access...'),
		comment    => Wx::gettext('Quick access to all menu functions'),
		shortcut   => 'Ctrl-3',
		toolbar    => 'status/info',
		menu_event => sub {
			#Create and show the dialog
			require Padre::Wx::Dialog::QuickMenuAccess;
			Padre::Wx::Dialog::QuickMenuAccess->new($_[0])->ShowModal;
		},
	);

	return 1;
}

1;

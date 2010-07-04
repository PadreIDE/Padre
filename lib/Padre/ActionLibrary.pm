package Padre::ActionLibrary;

# Defines all the core actions for Padre.
# It's a little on the bloaty side, but splitting it into different files
# won't make it any better.

use 5.008005;
use strict;
use warnings;
use File::Spec      ();
use Params::Util    ();
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Constant ();
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

	# Can the user move stuff around

	Padre::Action->new(
		name        => 'view.lockinterface',
		label       => Wx::gettext('Lock User Interface'),
		comment     => Wx::gettext('If activated, do not allow moving around some of the windows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			shift->on_toggle_lockinterface(@_);
		},
	);

	# Visible GUI Elements

	Padre::Action->new(
		name  => 'view.output',
		label => Wx::gettext('Show Output'),
		comment =>
			Wx::gettext('Show the window displaying the standard output and standard error of the running scripts'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_output( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.functions',
		label       => Wx::gettext('Show Functions'),
		comment     => Wx::gettext('Show a window listing all the functions in the current document'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_functions( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.todo',
		label       => Wx::gettext('Show To-do List'),
		comment     => Wx::gettext('Show a window listing all todo items in the current document'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_todo( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name    => 'view.outline',
		label   => Wx::gettext('Show Outline'),
		comment => Wx::gettext('Show a window listing all the parts of the current file (functions, pragmas, modules)'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_outline( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.directory',
		label       => Wx::gettext('Show Directory Tree'),
		comment     => Wx::gettext('Show a window with a directory browser of the current project'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_directory( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.show_syntaxcheck',
		label       => Wx::gettext('Show Syntax Check'),
		comment     => Wx::gettext('Turn on syntax checking of the current document and show output in a window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_syntax( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.show_errorlist',
		label       => Wx::gettext('Show Errors'),
		comment     => Wx::gettext('Show the list of errors received during execution of a script'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->show_errorlist( $_[1]->IsChecked );
		},
	);

	Padre::Action->new(
		name        => 'view.statusbar',
		label       => Wx::gettext('Show Status Bar'),
		comment     => Wx::gettext('Show/hide the status bar at the bottom of the screen'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_statusbar( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.toolbar',
		label       => Wx::gettext('Show Toolbar'),
		comment     => Wx::gettext('Show/hide the toolbar at the top of the editor'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_toolbar( $_[1] );
		},
	);

	# Editor Functionality

	Padre::Action->new(
		name        => 'view.lines',
		label       => Wx::gettext('Show Line Numbers'),
		comment     => Wx::gettext('Show/hide the line numbers of all the documents on the left side of the window'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_line_numbers( $_[1] );
		},
	);

	Padre::Action->new(
		name    => 'view.folding',
		label   => Wx::gettext('Show Code Folding'),
		comment => Wx::gettext('Show/hide a vertical line on the left hand side of the window to allow folding rows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_code_folding( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.fold_all',
		label       => Wx::gettext('Fold all'),
		comment     => Wx::gettext('Fold all the blocks that can be folded (need folding to be enabled)'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->current->editor->fold_all;
		},
	);

	Padre::Action->new(
		name        => 'view.unfold_all',
		label       => Wx::gettext('Unfold all'),
		comment     => Wx::gettext('Unfold all the blocks that can be folded (need folding to be enabled)'),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->current->editor->unfold_all;
		},
	);

	Padre::Action->new(
		name        => 'view.show_calltips',
		label       => Wx::gettext('Show Call Tips'),
		comment     => Wx::gettext('When typing in functions allow showing short examples of the function'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->config->set(
				'editor_calltips',
				$_[1]->IsChecked ? 1 : 0,
			);
			$_[0]->config->write;
		},
	);

	Padre::Action->new(
		name        => 'view.currentline',
		label       => Wx::gettext('Show Current Line'),
		comment     => Wx::gettext('Highlight the line where the cursor is'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_currentline( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.rightmargin',
		label       => Wx::gettext('Show Right Margin'),
		comment     => Wx::gettext('Show a vertical line indicating the right margin'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_right_margin( $_[1] );
		},
	);

	# Editor Whitespace Layout

	Padre::Action->new(
		name        => 'view.eol',
		label       => Wx::gettext('Show Newlines'),
		comment     => Wx::gettext('Show/hide the newlines with special character'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_eol( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.whitespaces',
		label       => Wx::gettext('Show Whitespaces'),
		comment     => Wx::gettext('Show/hide the tabs and the spaces with special characters'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_whitespaces( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.indentation_guide',
		label       => Wx::gettext('Show Indentation Guide'),
		comment     => Wx::gettext('Show/hide vertical bars at every indentation position on the left of the rows'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_toggle_indentation_guide( $_[1] );
		},
	);

	Padre::Action->new(
		name        => 'view.word_wrap',
		label       => Wx::gettext('Word-Wrap'),
		comment     => Wx::gettext('Wrap long lines'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			$_[0]->on_word_wrap( $_[1]->IsChecked );
		},
	);

	# Font Size

	Padre::Action->new(
		name       => 'view.font_increase',
		label      => Wx::gettext('Increase Font Size'),
		comment    => Wx::gettext('Make the letters bigger in the editor window'),
		shortcut   => 'Ctrl-+',
		menu_event => sub {
			$_[0]->zoom(+1);
		},
	);

	Padre::Action->new(
		name       => 'view.font_decrease',
		label      => Wx::gettext('Decrease Font Size'),
		comment    => Wx::gettext('Make the letters smaller in the editor window'),
		shortcut   => 'Ctrl--',
		menu_event => sub {
			$_[0]->zoom(-1);
		},
	);

	Padre::Action->new(
		name       => 'view.font_reset',
		label      => Wx::gettext('Reset Font Size'),
		comment    => Wx::gettext('Reset the size of the letters to the default in the editor window'),
		shortcut   => 'Ctrl-0',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$_[0]->zoom( -1 * $editor->GetZoom );
		},
	);

	# Bookmark Support

	Padre::Action->new(
		name       => 'view.bookmark_set',
		label      => Wx::gettext('Set Bookmark'),
		comment    => Wx::gettext('Create a bookmark in the current file current row'),
		shortcut   => 'Ctrl-B',
		menu_event => sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->set_bookmark( $_[0] );
		},
	);

	Padre::Action->new(
		name       => 'view.bookmark_goto',
		label      => Wx::gettext('Goto Bookmark'),
		comment    => Wx::gettext('Select a bookmark created earlier and jump to that position'),
		shortcut   => 'Ctrl-Shift-B',
		menu_event => sub {
			require Padre::Wx::Dialog::Bookmarks;
			Padre::Wx::Dialog::Bookmarks->goto_bookmark( $_[0] );
		},
	);

	# Window Effects

	Padre::Action->new(
		name        => 'view.full_screen',
		label       => Wx::gettext('&Full Screen'),
		comment     => Wx::gettext('Set Padre in full screen mode'),
		shortcut    => 'F11',
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			if ( $_[0]->IsFullScreen ) {
				$_[0]->ShowFullScreen(0);
			} else {
				$_[0]->ShowFullScreen(
					1,
					Wx::wxFULLSCREEN_NOCAPTION | Wx::wxFULLSCREEN_NOBORDER
				);
			}
			return;
		},
	);

	# Perl-Specific Searches

	Padre::Action->new(
		name        => 'perl.beginner_check',
		need_editor => 1,
		label       => Wx::gettext('Check for Common (Beginner) Errors'),
		comment     => Wx::gettext('Check the current file for common beginner errors'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->beginner_check;
		},
	);

	Padre::Action->new(
		name        => 'perl.find_brace',
		need_editor => 1,
		label       => Wx::gettext('Find Unmatched Brace'),
		comment    => Wx::gettext('Searches the source code for brackets with lack a matching (opening/closing) part.'),
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->find_unmatched_brace;
		},
	);

	Padre::Action->new(
		name        => 'perl.find_variable',
		need_editor => 1,
		label       => Wx::gettext('Find Variable Declaration'),
		comment     => Wx::gettext('Find where the selected variable was declared using "my" and put the focus there.'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->find_variable_declaration;
		},
	);

	Padre::Action->new(
		name        => 'perl.find_method',
		need_editor => 1,
		label       => Wx::gettext('Find Method Declaration'),
		comment     => Wx::gettext('Find where the selected function was defined and put the focus there.'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->find_method_declaration;
		},
	);

	Padre::Action->new(
		name        => 'perl.vertically_align_selected',
		need_editor => 1,
		label       => Wx::gettext('Vertically Align Selected'),
		comment     => Wx::gettext('Align a selection of text to the same left column.'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->editor->vertically_align;
		},
	);

	Padre::Action->new(
		name        => 'perl.newline_keep_column',
		need_editor => 1,
		label       => Wx::gettext('Newline Same Column'),
		comment     => Wx::gettext(
			'Like pressing ENTER somewhere on a line, but use the current position as ident for the new line.'),
		shortcut   => 'Ctrl-Enter',
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->newline_keep_column;
		},
	);

	Padre::Action->new(
		name        => 'perl.create_tagsfile',
		need_editor => 1,
		label       => Wx::gettext('Create Project Tagsfile'),
		comment =>
			Wx::gettext('Creates a perltags - file for the current project supporting find_method and autocomplete.'),
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			$document->isa('Padre::Document::Perl') or return;
			$document->project_create_tagsfile;
		},
	);

	Padre::Action->new(
		name        => 'perl.autocomplete_brackets',
		need_editor => 1,
		label       => Wx::gettext('Automatic Bracket Completion'),
		comment     => Wx::gettext('When typing { insert a closing } automatically'),
		menu_method => 'AppendCheckItem',
		menu_event  => sub {
			# Update the saved config setting
			my $checked = $_[1]->IsChecked ? 1 : 0;
			$_[0]->config->set(
				autocomplete_brackets => $checked,
			);
		}
	);

	# Perl-Specific Refactoring

	Padre::Action->new(
		name        => 'refactor.rename_variable',
		need_editor => 1,
		label       => Wx::gettext('Rename Variable...'),
		comment => Wx::gettext('Prompt for a replacement variable name and replace all occurrences of this variable'),
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			$document->can('lexical_variable_replacement') or return;
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				Wx::gettext('New name'),
				Wx::gettext('Rename variable'),
				'$foo',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $replacement = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $replacement;
			$document->lexical_variable_replacement($replacement);
		},
	);

	Padre::Action->new(
		name        => 'refactor.extract_subroutine',
		need_editor => 1,
		label       => Wx::gettext('Extract Subroutine...'),
		comment     => Wx::gettext(
			      'Cut the current selection and create a new sub from it. '
				. 'A call to this sub is added in the place where the selection was.'
		),
		menu_event => sub {
			my $document = $_[0]->current->document or return;
			$document->can('extract_subroutine') or return;
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				Wx::gettext('Name for the new subroutine'),
				Wx::gettext('Extract Subroutine'),
				'$foo',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $newname = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $newname;
			$document->extract_subroutine($newname);
		},
	);

	Padre::Action->new(
		name        => 'refactor.introduce_temporary',
		need_editor => 1,
		label       => Wx::gettext('Introduce Temporary Variable...'),
		comment     => Wx::gettext('Assign the selected expression to a newly declared variable'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$document->can('introduce_temporary_variable') or return;
			require Padre::Wx::History::TextEntryDialog;
			my $dialog = Padre::Wx::History::TextEntryDialog->new(
				$_[0],
				Wx::gettext('Variable Name'),
				Wx::gettext('Introduce Temporary Variable'),
				'$tmp',
			);
			return if $dialog->ShowModal == Wx::wxID_CANCEL;
			my $replacement = $dialog->GetValue;
			$dialog->Destroy;
			return unless defined $replacement;
			$document->introduce_temporary_variable($replacement);
		},
	);

	# Script Execution

	Padre::Action->new(
		name         => 'run.run_document',
		need_editor  => 1,
		need_runable => 1,
		label        => Wx::gettext('Run Script'),
		comment      => Wx::gettext('Runs the current document and shows its output in the output panel.'),
		shortcut     => 'F5',
		need_file    => 1,
		toolbar      => 'actions/player_play',
		menu_event   => sub {
			$_[0]->run_document;
			$_[0]->refresh_toolbar( $_[0]->current );
		},
	);

	Padre::Action->new(
		name         => 'run.run_document_debug',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Run Script (Debug Info)'),
		comment      => Wx::gettext( 'Run the current document but include ' . 'debug info in the output.' ),
		shortcut     => 'Shift-F5',
		menu_event   => sub {
			# Enable debug info
			$_[0]->run_document(1);
		},
	);

	Padre::Action->new(
		name       => 'run.run_command',
		label      => Wx::gettext('Run Command'),
		comment    => Wx::gettext('Runs a shell command and shows the output.'),
		shortcut   => 'Ctrl-F5',
		menu_event => sub {
			$_[0]->on_run_command;
		},
	);
	Padre::Action->new(
		name        => 'run.run_tdd_tests',
		need_file   => 1,
		need_editor => 1,
		label       => Wx::gettext('Run Build and Tests'),
		comment     => Wx::gettext('Builds the current project, then run all tests.'),
		shortcut    => 'Ctrl-Shift-F5',
		menu_event  => sub {
			$_[0]->on_run_tdd_tests;
		},
	);

	Padre::Action->new(
		name        => 'run.run_tests',
		need_editor => 1,
		need_file   => 1,
		label       => Wx::gettext('Run Tests'),
		comment     => Wx::gettext(
			'Run all tests for the current project or document and show the results in ' . 'the output panel.'
		),
		need_editor => 1,
		menu_event  => sub {
			$_[0]->on_run_tests;
		},
	);

	Padre::Action->new(
		name         => 'run.run_this_test',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		need         => sub {
			my %objects = @_;
			return 0 unless defined $objects{document};
			return 0 unless defined $objects{document}->{file};
			return $objects{document}->{file}->{filename} =~ /\.t$/;
		},
		label      => Wx::gettext('Run This Test'),
		comment    => Wx::gettext('Run the current test if the current document is a test. (prove -bv)'),
		menu_event => sub {
			$_[0]->on_run_this_test;
		},
	);

	Padre::Action->new(
		name => 'run.stop',
		need => sub {
			my %objects = @_;
			return $main->{command} ? 1 : 0;
		},
		label      => Wx::gettext('Stop Execution'),
		comment    => Wx::gettext('Stop a running task.'),
		shortcut   => 'F6',
		toolbar    => 'actions/stop',
		menu_event => sub {
			if ( $_[0]->{command} ) {
				if ( Padre::Constant::WIN32 ) {
					$_[0]->{command}->KillProcess;
				} else {
					$_[0]->{command}->TerminateProcess;
				}
			}
			delete $_[0]->{command};
			$_[0]->refresh_toolbar( $_[0]->current );
			return;
		},
	);

	# Debugging

	Padre::Action->new(
		name         => 'debug.step_in',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-stop-after-command',
		label        => Wx::gettext('Step In') . ' (&s) ',
		comment      => Wx::gettext(
			'Execute the next statement, enter subroutine if needed. (Start debugger if it is not yet running)'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_step_in;
		},
	);

	Padre::Action->new(
		name         => 'debug.step_over',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-stop-after-procedure',
		label        => Wx::gettext('Step Over') . ' (&n) ',
		comment      => Wx::gettext(
			'Execute the next statement. If it is a subroutine call, stop only after it returned. (Start debugger if it is not yet running)'
		),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_step_over;
		},
	);


	Padre::Action->new(
		name         => 'debug.step_out',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-jump-back',
		label        => Wx::gettext('Step Out') . ' (&r) ',
		comment      => Wx::gettext('If within a subroutine, run till return is called and then stop.'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_step_out;
		},
	);

	Padre::Action->new(
		name         => 'debug.run',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_tools-macro',
		label        => Wx::gettext('Run till Breakpoint') . ' (&c) ',
		comment      => Wx::gettext('Start running and/or continue running till next breakpoint or watch'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_run;
		},
	);

	Padre::Action->new(
		name         => 'debug.jump_to',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Jump to Current Execution Line'),
		comment      => Wx::gettext('Set focus to the line where the current statement is in the debugging process'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_jumpt_to;
		},
	);

	Padre::Action->new(
		name         => 'debug.set_breakpoint',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-insert-breakpoint',
		label        => Wx::gettext('Set Breakpoint') . ' (&b) ',
		comment      => Wx::gettext('Set a breakpoint to the current location of the cursor with a condition'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_set_breakpoint;
		},
	);

	Padre::Action->new(
		name         => 'debug.remove_breakpoint',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Remove Breakpoint'),
		comment      => Wx::gettext('Remove the breakpoint at the current location of the cursor'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_remove_breakpoint;
		},
	);

	Padre::Action->new(
		name         => 'debug.list_breakpoints',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('List All Breakpoints'),
		comment      => Wx::gettext('List all the breakpoints on the console'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_list_breakpoints;
		},
	);

	Padre::Action->new(
		name         => 'debug.run_to_cursor',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Run to Cursor'),
		comment      => Wx::gettext('Set a breakpoint at the line where to cursor is and run till there'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_run_to_cursor;
		},
	);


	Padre::Action->new(
		name         => 'debug.show_stack_trace',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Show Stack Trace') . ' (&T) ',
		comment      => Wx::gettext('When in a subroutine call show all the calls since the main of the program'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_show_stack_trace;
		},
	);

	Padre::Action->new(
		name         => 'debug.display_value',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'stock/code/stock_macro-watch-variable',
		label        => Wx::gettext('Display Value'),
		comment      => Wx::gettext('Display the current value of a variable in the right hand side debugger pane'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_display_value;
		},
	);

	Padre::Action->new(
		name         => 'debug.show_value',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Show Value Now') . ' (&x) ',
		comment      => Wx::gettext('Show the value of a variable now in a pop-up window.'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_show_value;
		},
	);

	Padre::Action->new(
		name         => 'debug.evaluate_expression',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		label        => Wx::gettext('Evaluate Expression...'),
		comment      => Wx::gettext('Type in any expression and evaluate it in the debugged process'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_evaluate_expression;
		},
	);

	Padre::Action->new(
		name         => 'debug.quit',
		need_editor  => 1,
		need_runable => 1,
		need_file    => 1,
		toolbar      => 'actions/stop',
		label        => Wx::gettext('Quit Debugger') . ' (&q) ',
		comment      => Wx::gettext('Quit the process being debugged'),

		#shortcut     => 'Shift-F5',
		menu_event => sub {
			$_[0]->{_debugger_} or return;
			$_[0]->{_debugger_}->debug_perl_quit;
		},
	);

	# Key Bindings action

	Padre::Action->new(
		name       => 'tools.key_bindings',
		label      => Wx::gettext('Key Bindings'),
		comment    => Wx::gettext('Show the key bindings dialog to configure Padre shortcuts'),
		menu_event => sub {
			$_[0]->on_key_bindings;
		},
	);

	# Link to the Plugin Manager

	Padre::Action->new(
		name       => 'plugins.plugin_manager',
		label      => Wx::gettext('Plug-in Manager'),
		comment    => Wx::gettext('Show the Padre plug-in manager to enable or disable plug-ins'),
		menu_event => sub {
			require Padre::Wx::Dialog::PluginManager;
			Padre::Wx::Dialog::PluginManager->new(
				$_[0],
				$_[0]->ide->plugin_manager,
			)->show;
		},
	);

	# TO DO: should be replaced by a link to http://cpan.uwinnipeg.ca/chapter/World_Wide_Web_HTML_HTTP_CGI/Padre
	# better yet, by a window that also allows the installation of all the plug-ins that can take into account
	# the type of installation we have (ppm, stand alone, rpm, deb, CPAN, etc.)
	Padre::Action->new(
		name       => 'plugins.plugin_list',
		label      => Wx::gettext('Plug-in List (CPAN)'),
		comment    => Wx::gettext('Open browser to a CPAN search showing the Padre::Plugin packages'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://cpan.uwinnipeg.ca/search?query=Padre%3A%3APlugin%3A%3A&mode=dist');
		},
	);

	Padre::Action->new(
		name       => 'plugins.edit_my_plugin',
		label      => Wx::gettext('Edit My Plug-in'),
		comment    => Wx::gettext('My Plug-in is a plug-in where developers could extend their Padre installation'),
		menu_event => sub {
			my $file = File::Spec->catfile(
				Padre::Constant::CONFIG_DIR,
				qw{ plugins Padre Plugin My.pm }
			);
			return $_[0]->error(
				Wx::gettext("Could not find the Padre::Plugin::My plug-in")
			) unless -e $file;

			# Use the plural so we get the "close single unused document"
			# behaviour, and so we get a free freezing and refresh calls.
			$_[0]->setup_editors($file);
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_my_plugin',
		label      => Wx::gettext('Reload My Plug-in'),
		comment    => Wx::gettext('This function reloads the My plug-in without restarting Padre'),
		menu_event => sub {
			$_[0]->ide->plugin_manager->reload_plugin('Padre::Plugin::My');
		},
	);

	Padre::Action->new(
		name       => 'plugins.reset_my_plugin',
		label      => Wx::gettext('Reset My plug-in'),
		comment    => Wx::gettext('Reset the My plug-in to the default'),
		menu_event => sub {
			my $ret = Wx::MessageBox(
				Wx::gettext("Reset My plug-in"),
				Wx::gettext("Reset My plug-in"),
				Wx::wxOK | Wx::wxCANCEL | Wx::wxCENTRE,
				$main,
			);
			if ( $ret == Wx::wxOK ) {
				my $manager = $_[0]->ide->plugin_manager;
				$manager->unload_plugin('Padre::Plugin::My');
				$manager->reset_my_plugin(1);
				$manager->load_plugin('Padre::Plugin::My');
			}
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_all_plugins',
		label      => Wx::gettext('Reload All Plug-ins'),
		comment    => Wx::gettext('Reload all plug-ins from disk'),
		menu_event => sub {
			$_[0]->ide->plugin_manager->reload_plugins;
		},
	);

	Padre::Action->new(
		name       => 'plugins.reload_current_plugin',
		label      => Wx::gettext('(Re)load Current Plug-in'),
		comment    => Wx::gettext('Reloads (or initially loads) the current plug-in'),
		menu_event => sub {
			$_[0]->ide->plugin_manager->reload_current_plugin;
		},
	);

	Padre::Action->new(
		name       => 'plugins.install_cpan',
		label      => Wx::gettext("Install CPAN Module"),
		comment    => Wx::gettext('Install a Perl module from CPAN'),
		menu_event => sub {
			require Padre::CPAN;
			require Padre::Wx::CPAN;
			my $cpan = Padre::CPAN->new;
			my $gui  = Padre::Wx::CPAN->new( $cpan, $_[0] );
			$gui->show;
		}
	);

	Padre::Action->new(
		name       => 'plugins.install_local',
		label      => Wx::gettext("Install Local Distribution"),
		comment    => Wx::gettext('Using CPAN.pm to install a CPAN like package opened locally'),
		menu_event => sub {
			require Padre::CPAN;
			Padre::CPAN->install_file($_[0]);
		},
	);

	Padre::Action->new(
		name       => 'plugins.install_remote',
		label      => Wx::gettext("Install Remote Distribution"),
		comment    => Wx::gettext('Using pip to download a tar.gz file and install it using CPAN.pm'),
		menu_event => sub {
			require Padre::CPAN;
			Padre::CPAN->install_url($_[0]);
		},
	);

	Padre::Action->new(
		name       => 'plugins.cpan_config',
		label      => Wx::gettext("Open CPAN Config File"),
		comment    => Wx::gettext('Open CPAN::MyConfig.pm for manual editing by experts'),
		menu_event => sub {
			require Padre::CPAN;
			Padre::CPAN->cpan_config($_[0]);
		},
	);

	# File Navigation

	Padre::Action->new(
		name        => 'window.last_visited_file',
		label       => Wx::gettext('Last Visited File'),
		comment     => Wx::gettext('Switch to edit the file that was previously edited (can switch back and forth)'),
		shortcut    => 'Ctrl-Tab',
		need_editor => 1,
		menu_event  => sub {
			shift->on_last_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.oldest_visited_file',
		label       => Wx::gettext('Oldest Visited File'),
		comment     => Wx::gettext('Put focus on tab visited the longest time ago.'),
		shortcut    => 'Ctrl-Shift-Tab',
		need_editor => 1,
		menu_event  => sub {
			shift->on_oldest_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.next_file',
		label       => Wx::gettext('Next File'),
		comment     => Wx::gettext('Put focus on the next tab to the right'),
		shortcut    => 'Alt-Right',
		need_editor => 1,
		menu_event  => sub {
			shift->on_next_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.previous_file',
		label       => Wx::gettext('Previous File'),
		comment     => Wx::gettext('Put focus on the previous tab to the left'),
		shortcut    => 'Alt-Left',
		need_editor => 1,
		menu_event  => sub {
			shift->on_prev_pane(@_);
		},
	);

	# TODO: Remove this and the menu option as soon as #750 is fixed
	#       as it's the same like Ctrl-Tab
	Padre::Action->new(
		name        => 'window.last_visited_file_old',
		label       => Wx::gettext('Last Visited File'),
		comment     => Wx::gettext('???'),
		shortcut    => 'Ctrl-Shift-P',
		need_editor => 1,
		menu_event  => sub {
			shift->on_last_visited_pane(@_);
		},
	);

	Padre::Action->new(
		name        => 'window.right_click',
		label       => Wx::gettext('Right Click'),
		comment     => Wx::gettext('Imitate clicking on the right mouse button'),
		shortcut    => 'Alt-/',
		need_editor => 1,
		menu_event  => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->on_right_down( $_[1] );
		},
	);

	# Window Navigation

	Padre::Action->new(
		name       => 'window.goto_functions_window',
		label      => Wx::gettext('Go to Functions Window'),
		comment    => Wx::gettext('Set the focus to the "Functions" window'),
		shortcut   => 'Alt-N',
		menu_event => sub {
			$_[0]->refresh_functions( $_[0]->current );
			$_[0]->show_functions(1);
			$_[0]->functions->focus_on_search;
		},
	);

	# Window Navigation

	Padre::Action->new(
		name       => 'window.goto_todo_window',
		label      => Wx::gettext('Go to Todo Window'),
		comment    => Wx::gettext('Set the focus to the "Todo" window'),
		shortcut   => 'Alt-T',
		menu_event => sub {
			$_[0]->refresh_todo( $_[0]->current );
			$_[0]->show_todo(1);
			$_[0]->todo->focus_on_search;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_outline_window',
		label      => Wx::gettext('Go to Outline Window'),
		comment    => Wx::gettext('Set the focus to the "Outline" window'),
		shortcut   => 'Alt-L',
		menu_event => sub {
			$_[0]->show_outline(1);
			$_[0]->outline->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_output_window',
		label      => Wx::gettext('Go to Output Window'),
		comment    => Wx::gettext('Set the focus to the "Output" window'),
		shortcut   => 'Alt-O',
		menu_event => sub {
			$_[0]->show_output(1);
			$_[0]->output->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_syntax_check_window',
		label      => Wx::gettext('Go to Syntax Check Window'),
		comment    => Wx::gettext('Set the focus to the "Syntax Check" window'),
		shortcut   => 'Alt-C',
		menu_event => sub {
			$_[0]->show_syntax(1);
			$_[0]->syntax->SetFocus;
		},
	);

	Padre::Action->new(
		name       => 'window.goto_main_window',
		label      => Wx::gettext('Go to Main Window'),
		comment    => Wx::gettext('Set the focus to the main editor window'),
		shortcut   => 'Alt-M',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->SetFocus;
		},
	);

	# Add the POD-based help launchers

	Padre::Action->new(
		name       => 'help.help',
		id         => Wx::wxID_HELP,
		label      => Wx::gettext('Help'),
		comment    => Wx::gettext('Show the Padre help'),
		menu_event => sub {
			$_[0]->help('Padre');
		},
	);

	Padre::Action->new(
		name       => 'help.context_help',
		label      => Wx::gettext('Search Help'),
		comment    => Wx::gettext('Search the Perl help pages (perldoc)'),
		shortcut   => 'F1',
		menu_event => sub {
			my $focus = Wx::Window::FindFocus();
			if ( Params::Util::_INSTANCE($focus, 'Padre::Wx::ErrorList') ){
				$_[0]->errorlist->on_menu_help_context_help;
			} else {
				# Show help for selected text
				$_[0]->help( $_[0]->current->text );
				return;
			}
		},
	);

	Padre::Action->new(
		name       => 'help.search',
		label      => Wx::gettext('Context Help'),
		comment    => Wx::gettext('Show the help article for the current context'),
		shortcut   => 'F2',
		menu_event => sub {
			# Show Help Search with no topic...
			$_[0]->help_search;
		},
	);

	Padre::Action->new(
		name        => 'help.current',
		need_editor => 1,
		label       => Wx::gettext('Current Document'),
		comment     => Wx::gettext('Show the POD (Perldoc) version of the current document'),
		menu_event  => sub {
			$_[0]->help( $_[0]->current->document );
		},
	);

	# Live Support

	Padre::Action->new(
		name    => 'help.live_support',
		label   => Wx::gettext('Padre Support (English)'),
		comment => Wx::gettext(
			'Open the Padre live support chat in your web browser '
			. 'and talk to others who may help you with your problem'
		),
		menu_event => sub {
			Padre::Wx::launch_irc('padre');
		},
	);

	Padre::Action->new(
		name    => 'help.perl_help',
		label   => Wx::gettext('Perl Help'),
		comment => Wx::gettext(
			'Open the Perl live support chat in your web browser '
			. 'and talk to others who may help you with your problem'
		),
		menu_event => sub {
			Padre::Wx::launch_irc('general');
		},
	);

	Padre::Action->new(
		name    => 'help.win32_questions',
		label   => Wx::gettext('Win32 Questions (English)'),
		comment => Wx::gettext(
			'Open the Perl/Win32 live support chat in your web browser '
			. 'and talk to others who may help you with your problem'
		),
		menu_event => sub {
			Padre::Wx::launch_irc('win32');
		},
	);

	# Add interesting and helpful websites

	Padre::Action->new(
		name    => 'help.visit_perlmonks',
		label   => Wx::gettext('Visit the PerlMonks'),
		comment => Wx::gettext(
			'Open perlmonks.org, one of the biggest Perl community sites, '
			. 'in your default web browser'
		),
		menu_event => sub {
			Padre::Wx::launch_browser('http://perlmonks.org/');
		},
	);

	# Add Padre website tools

	Padre::Action->new(
		name       => 'help.report_a_bug',
		label      => Wx::gettext('Report a New &Bug'),
		comment    => Wx::gettext('Send a bug report to the Padre developer team'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/Tickets');
		},
	);
	Padre::Action->new(
		name       => 'help.view_all_open_bugs',
		label      => Wx::gettext('View All &Open Bugs'),
		comment    => Wx::gettext('View all known and currently unsolved bugs in Padre'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/report/1');
		},
	);

	Padre::Action->new(
		name       => 'help.translate_padre',
		label      => Wx::gettext('&Translate Padre...'),
		comment    => Wx::gettext('Help by translating Padre to your local language'),
		menu_event => sub {
			Padre::Wx::launch_browser('http://padre.perlide.org/trac/wiki/TranslationIntro');
		},
	);

	# Add the About

	Padre::Action->new(
		name       => 'help.about',
		id         => Wx::wxID_ABOUT,
		label      => Wx::gettext('&About'),
		comment    => Wx::gettext('Show information about Padre'),
		menu_event => sub {
			$_[0]->about->ShowModal;
		},
	);

	# This is made for usage by the developers to create a complete
	# list of all actions used in Padre. It outputs some warnings
	# while dumping, but they're ignored for now as it should never
	# run within a productional copy.
	if ( $ENV{PADRE_EXPORT_ACTIONS} ) {
		require Data::Dumper;
		$Data::Dumper::Purity = 1;
		open(
			my $action_export_fh,
			'>',
			File::Spec->catfile(
				Padre::Constant::CONFIG_DIR,
				'actions.dump',
			),
		);
		print $action_export_fh Data::Dumper::Dumper( $_[0]->ide->actions );
		close $action_export_fh;
	}

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

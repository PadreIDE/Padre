package Padre::Action::File;

# Fully encapsulated File menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ('_CURRENT');
use Padre::Logger;

our $VERSION = '0.59';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = Padre->ide->config;
	my $self   = bless {}, $class;

	# Add additional properties
	$self->{main} = $main;

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
			Padre::Wx::Dialog::ModuleStart->start( $_[0] );
		},
	);

	### NOTE: Add support for plugins here

	# Open things

	Padre::Action->new(
		name       => 'file.open',
		id         => Wx::wxID_OPEN,
		label      => Wx::gettext('&Open'),
		comment    => Wx::gettext('Browse directory of the current document to open a file'),
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
		label       => Wx::gettext('Open In File Browser'),
		comment     => Wx::gettext('Opens the current document using the file browser'),
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			$_[0]->on_open_in_file_browser( $document->filename );
		},
	);

	Padre::Action->new(
		name        => 'file.open_with_default_system_editor',
		label       => Wx::gettext('Open With Default System Editor'),
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
		label       => Wx::gettext('Open In Command Line'),
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
		label       => Wx::gettext('Close This Project'),
		comment     => Wx::gettext('Close all the files belonging to the current project'),
		shortcut    => 'Ctrl-Shift-W',
		menu_event  => sub {
			my $document = $_[0]->current->document or return;
			my $dir = $document->project_dir;
			unless ( defined $dir ) {
				$_[0]->error( Wx::gettext("File is not in a project") );
			}
			$_[0]->close_where(
				sub {
					defined $_[0]->project_dir
						and $_[0]->project_dir eq $dir;
				}
			);
		},
	);

	Padre::Action->new(
		name        => 'file.close_other_projects',
		need_editor => 1,
		label       => Wx::gettext('Close Other Projects'),
		comment     => Wx::gettext('Close all the files that do not belong to the current project'),
		menu_event  => sub {
			my $doc = $_[0]->current->document;
			return if not $doc;
			my $dir = $doc->project_dir;
			unless ( defined $dir ) {
				$_[0]->error( Wx::gettext("File is not in a project") );
			}
			$_[0]->close_where(
				sub {
					$_[0]->project_dir
						and $_[0]->project_dir ne $dir;
				}
			);
		},
	);

	Padre::Action->new(
		name        => 'file.close_all',
		need_editor => 1,
		label       => Wx::gettext('Close All Files'),
		comment     => Wx::gettext('Close all the files open in the editor'),
		menu_event  => sub {
			$_[0]->close_all;
		},
	);

	Padre::Action->new(
		name        => 'file.close_all_but_current',
		need_editor => 1,
		label       => Wx::gettext('Close All Other Files'),
		comment     => Wx::gettext('Close all the files except the current one'),
		menu_event  => sub {
			$_[0]->close_all( $_[0]->notebook->GetSelection );
		},
	);

	Padre::Action->new(
		name        => 'file.close_some',
		need_editor => 1,
		label       => Wx::gettext('Close Files Dialog...'),
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
		label       => Wx::gettext('Reload Some Dialog...'),
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
		name  => 'file.open_session',
		label => Wx::gettext('Open Session...'),
		comment =>
			Wx::gettext('Select a session. Close all the files currently open and open all the listed in the session'),
		shortcut   => 'Ctrl-Alt-O',
		menu_event => sub {
			require Padre::Wx::Dialog::SessionManager;
			Padre::Wx::Dialog::SessionManager->new( $_[0] )->show;
		},
	);

	Padre::Action->new(
		name       => 'file.save_session',
		label      => Wx::gettext('Save Session...'),
		comment    => Wx::gettext('Ask for a session name and save the list of files currently opened'),
		shortcut   => 'Ctrl-Alt-S',
		menu_event => sub {
			require Padre::Wx::Dialog::SessionSave;
			Padre::Wx::Dialog::SessionSave->new( $_[0] )->show;
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

	return $self;
}


1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

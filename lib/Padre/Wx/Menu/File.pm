package Padre::Wx::Menu::File;

# Fully encapsulated File menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.46';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	my $config = Padre->ide->config;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;

	# Create new things

	$self->{new} = $self->add_menu_item(
		$self,
		name       => 'file.new',
		label      => Wx::gettext('&New'),
		shortcut   => 'Ctrl-N',
		menu_event => sub {
			$_[0]->on_new;
		},
	);

	my $file_new = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("New..."),
		$file_new,
	);
	$self->add_menu_item(
		$file_new,
		name       => 'file.new_p5_script',
		label      => Wx::gettext('Perl 5 Script'),
		menu_event => sub {
			$_[0]->on_new_from_template('pl');
		},
	);
	$self->add_menu_item(
		$file_new,
		name       => 'file.new_p5_module',
		label      => Wx::gettext('Perl 5 Module'),
		menu_event => sub {
			$_[0]->on_new_from_template('pm');
		},
	);
	$self->add_menu_item(
		$file_new,
		name       => 'file.new_p5_test',
		label      => Wx::gettext('Perl 5 Test'),
		menu_event => sub {
			$_[0]->on_new_from_template('t');
		},
	);
	$self->add_menu_item(
		$file_new,
		name       => 'file.new_p6_script',
		label      => Wx::gettext('Perl 6 Script'),
		menu_event => sub {
			$_[0]->on_new_from_template('p6');
		},
	);
	$self->add_menu_item(
		$file_new,
		name       => 'file.new_p5_distro',
		label      => Wx::gettext('Perl Distribution (Module::Starter)'),
		menu_event => sub {
			require Padre::Wx::Dialog::ModuleStart;
			Padre::Wx::Dialog::ModuleStart->start( $_[0] );
		},
	);

	# Open things

	$self->add_menu_item(
		$self,
		name       => 'file.open',
		id         => Wx::wxID_OPEN,
		label      => Wx::gettext('&Open...'),
		shortcut   => 'Ctrl-O',
		menu_event => sub {
			$_[0]->on_open;
		},
	);

	$self->add_menu_item(
		$self,
		name  => 'file.openurl',
		label => Wx::gettext('Open &URL...'),

		# Is shown as Ctrl-O and I don't know why
		# shortcut => 'Ctrl-Shift-O',
		menu_event => sub {
			$_[0]->on_open_url;
		},
	);

	$self->{open_example} = $self->add_menu_item(
		$self,
		name       => 'file.open_example',
		label      => Wx::gettext('Open Example'),
		menu_event => sub {
			$_[0]->on_open_example;
		},
	);

	$self->{close} = $self->add_menu_item(
		$self,
		name       => 'file.close',
		id         => Wx::wxID_CLOSE,
		label      => Wx::gettext('&Close'),
		shortcut   => 'Ctrl-W',
		menu_event => sub {
			$_[0]->on_close;
		},
	);

	# Close things

	my $file_close = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("Close..."),
		$file_close,
	);

	$self->{close_current_project} = $self->add_menu_item(
		$file_close,
		name       => 'file.close_current_project',
		label      => Wx::gettext('Close This Project'),
		menu_event => sub {
			my $doc = $_[0]->current->document;
			return if not $doc;
			my $dir = $doc->project_dir;
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

	$self->{close_other_projects} = $self->add_menu_item(
		$file_close,
		name       => 'file.close_other_projects',
		label      => Wx::gettext('Close Other Projects'),
		menu_event => sub {
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

	$file_close->AppendSeparator;

	$self->{close_all} = $self->add_menu_item(
		$file_close,
		name       => 'file.close_all',
		label      => Wx::gettext('Close All Files'),
		menu_event => sub {
			$_[0]->close_all;
		},
	);

	$self->{close_all_but_current} = $self->add_menu_item(
		$file_close,
		name       => 'file.close_all_but_current',
		label      => Wx::gettext('Close All Other Files'),
		menu_event => sub {
			$_[0]->close_all( $_[0]->notebook->GetSelection );
		},
	);

	$self->{reload_file} = $self->add_menu_item(
		$self,
		name       => 'file.reload_file',
		label      => Wx::gettext('Reload File'),
		menu_event => sub {
			$_[0]->on_reload_file;
		},
	);

	$self->AppendSeparator;

	# Save files
	$self->{save} = $self->add_menu_item(
		$self,
		name       => 'file.save',
		id         => Wx::wxID_SAVE,
		label      => Wx::gettext('&Save'),
		shortcut   => 'Ctrl-S',
		menu_event => sub {
			$_[0]->on_save;
		},
	);

	$self->{save_as} = $self->add_menu_item(
		$self,
		name       => 'file.save_as',
		id         => Wx::wxID_SAVEAS,
		label      => Wx::gettext('Save &As'),
		shortcut   => 'F12',
		menu_event => sub {
			$_[0]->on_save_as;
		},
	);

	$self->{save_all} = $self->add_menu_item(
		$self,
		name       => 'file.save_all',
		label      => Wx::gettext('Save All'),
		menu_event => sub {
			$_[0]->on_save_all;
		},
	);

	if ( $config->func_session ) {

		$self->AppendSeparator;

		# Specialised open and close functions
		$self->{open_selection} = $self->add_menu_item(
			$self,
			name       => 'file.open_selection',
			label      => Wx::gettext('Open Selection'),
			shortcut   => 'Ctrl-Shift-O',
			menu_event => sub {
				$_[0]->on_open_selection;
			},
		);

		$self->{open_session} = $self->add_menu_item(
			$self,
			name       => 'file.open_session',
			label      => Wx::gettext('Open Session'),
			shortcut   => 'Ctrl-Alt-O',
			menu_event => sub {
				require Padre::Wx::Dialog::SessionManager;
				Padre::Wx::Dialog::SessionManager->new( $_[0] )->show;
			},
		);

		$self->{save_session} = $self->add_menu_item(
			$self,
			name       => 'file.save_session',
			label      => Wx::gettext('Save Session'),
			shortcut   => 'Ctrl-Alt-S',
			menu_event => sub {
				require Padre::Wx::Dialog::SessionSave;
				Padre::Wx::Dialog::SessionSave->new( $_[0] )->show;
			},
		);

	}

	$self->AppendSeparator;

	# Print files
	$self->{print} = $self->add_menu_item(
		$self,
		name       => 'file.print',
		id         => Wx::wxID_PRINT,
		label      => Wx::gettext('&Print'),
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

	$self->AppendSeparator;

	# Recent things
	$self->{recentfiles} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("&Recent Files"),
		$self->{recentfiles}
	);
	$self->add_menu_item(
		$self->{recentfiles},
		name       => 'file.open_recent_files',
		label      => Wx::gettext('Open All Recent Files'),
		menu_event => sub {
			$_[0]->on_open_all_recent_files;
		},
	);
	$self->add_menu_item(
		$self->{recentfiles},
		name       => 'file.clean_recent_files',
		label      => Wx::gettext('Clean Recent Files List'),
		menu_event => sub {
			Padre::DB::History->delete( 'where type = ?', 'files' );
			$self->update_recentfiles;
		},
	);

	$self->{recentfiles}->AppendSeparator;

	$self->update_recentfiles;

	$self->AppendSeparator;

	# Word Stats
	$self->{docstat} = $self->add_menu_item(
		$self,
		name       => 'file.doc_stat',
		label      => Wx::gettext('Document Statistics'),
		menu_event => sub {
			$_[0]->on_doc_stats;
		},
	);

	$self->AppendSeparator;

	# Exiting
	$self->add_menu_item(
		$self,
		name       => 'file.quit',
		label      => Wx::gettext('&Quit'),
		shortcut   => 'Ctrl-Q',
		menu_event => sub {
			$_[0]->Close;
		},
	);

	return $self;
}

sub refresh {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $doc     = $current->document ? 1 : 0;

	$self->{close}->Enable($doc);
	$self->{close_all}->Enable($doc);
	$self->{close_all_but_current}->Enable($doc);
	$self->{reload_file}->Enable($doc);
	$self->{save}->Enable($doc);
	$self->{save_as}->Enable($doc);
	$self->{save_all}->Enable($doc);
	$self->{print}->Enable($doc);
	defined( $self->{open_session} ) and $self->{open_selection}->Enable($doc);
	defined( $self->{save_session} ) and $self->{save_session}->Enable($doc);
	$self->{docstat}->Enable($doc);

	return 1;
}

sub update_recentfiles {
	my $self = shift;

	# menu entry count starts at 0
	# first 3 entries are "open all", "clean list" and a separator
	foreach ( my $i = $self->{recentfiles}->GetMenuItemCount - 1; $i >= 3; $i-- ) {
		if ( my $item = $self->{recentfiles}->FindItemByPosition($i) ) {
			$self->{recentfiles}->Delete($item);
		}
	}

	my $idx = 0;
	foreach my $file ( grep { -f if $_ } Padre::DB::History->recent('files') ) {
		Wx::Event::EVT_MENU(
			$self->{main},
			$self->{recentfiles}->Append(
				-1,
				++$idx < 10 ? "&$idx. $file" : "$idx. $file"
			),
			sub {
				if ( -f $file ) {
					$_[0]->setup_editors($file);
				} else {

					# Handle "File not found" situation
					Padre::DB::History->delete( 'where name = ? and type = ?', $file, 'files' );
					$self->update_recentfiles;
					Wx::MessageBox(
						sprintf( Wx::gettext("File %s not found."), $file ),
						Wx::gettext("Open cancelled"),
						Wx::wxOK,
						$self->{main},
					);
				}
			},
		);
		Padre::Util::debug("Recent entry created for '$file'");
	}

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

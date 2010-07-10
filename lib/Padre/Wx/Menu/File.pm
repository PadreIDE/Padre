package Padre::Wx::Menu::File;

# Fully encapsulated File menu

use 5.008;
use strict;
use warnings;
use Fcntl           ();
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Constant ();
use Padre::Current  ();
use Padre::Logger;

our $VERSION = '0.66';
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

	# Create new things
	$self->{new} = $self->add_menu_action(
		$self,
		'file.new',
	);

	my $file_new = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('New'),
		$file_new,
	);
	$self->add_menu_action(
		$file_new,
		'file.new_p5_script',
	);
	$self->add_menu_action(
		$file_new,
		'file.new_p5_module',
	);
	$self->add_menu_action(
		$file_new,
		'file.new_p5_test',
	);

	# Split by language
	$file_new->AppendSeparator;

	$self->add_menu_action(
		$file_new,
		'file.new_p6_script',
	);

	# Split projects from files
	$file_new->AppendSeparator;

	$self->add_menu_action(
		$file_new,
		'file.new_p5_distro',
	);

	### NOTE: Add support for plugins here

	# Open things

	$self->add_menu_action(
		$self,
		'file.open',
	);

	my $file_open = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Open...'),
		$file_open,
	);

	$self->add_menu_action(
		$file_open,
		'file.openurl',
	);

	$self->{open_selection} = $self->add_menu_action(
		$file_open,
		'file.open_selection',
	);

	$self->{open_in_file_browser} = $self->add_menu_action(
		$file_open,
		'file.open_in_file_browser',
	);

	$self->{open_with_default_system_editor} = $self->add_menu_action(
		$file_open,
		'file.open_with_default_system_editor',
	);

	$self->{open_in_command_line} = $self->add_menu_action(
		$file_open,
		'file.open_in_command_line',
	);

	$self->{open_example} = $self->add_menu_action(
		$file_open,
		'file.open_example',
	);

	$self->{close} = $self->add_menu_action(
		$self,
		'file.close',
	);

	# Close things

	my $file_close = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Close'),
		$file_close,
	);

	$self->{close_current_project} = $self->add_menu_action(
		$file_close,
		'file.close_current_project',
	);

	$self->{close_other_projects} = $self->add_menu_action(
		$file_close,
		'file.close_other_projects',
	);

	$file_close->AppendSeparator;

	$self->{close_all} = $self->add_menu_action(
		$file_close,
		'file.close_all',
	);

	$self->{close_all_but_current} = $self->add_menu_action(
		$file_close,
		'file.close_all_but_current',
	);

	$file_close->AppendSeparator;

	$self->{close_some} = $self->add_menu_action(
		$file_close,
		'file.close_some',
	);

	### End of close submenu

	# Reload file(s)
	my $file_reload = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Reload'),
		$file_reload,
	);

	$self->{reload_file} = $self->add_menu_action(
		$file_reload,
		'file.reload_file',
	);

	$self->{reload_all} = $self->add_menu_action(
		$file_reload,
		'file.reload_all',
	);

	$self->{reload_all} = $self->add_menu_action(
		$file_reload,
		'file.reload_some',
	);

	### End of reload submenu

	$self->AppendSeparator;

	# Save files
	$self->{save} = $self->add_menu_action(
		$self,
		'file.save',
	);

	$self->{save_as} = $self->add_menu_action(
		$self,
		'file.save_as',
	);

	$self->{save_as} = $self->add_menu_action(
		$self,
		'file.save_intuition',
	);

	$self->{save_all} = $self->add_menu_action(
		$self,
		'file.save_all',
	);

	if ( $main->config->feature_session ) {

		$self->AppendSeparator;

		# Session operations
		$self->{open_session} = $self->add_menu_action(
			$self,
			'file.open_session',
		);

		$self->{save_session} = $self->add_menu_action(
			$self,
			'file.save_session',
		);

	}

	$self->AppendSeparator;

	# Print files
	$self->{print} = $self->add_menu_action(
		$self,
		'file.print',
	);

	$self->AppendSeparator;

	# Recent things
	$self->{recentfiles} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext("&Recent Files"),
		$self->{recentfiles}
	);
	$self->add_menu_action(
		$self->{recentfiles},
		'file.open_recent_files',
	);
	$self->add_menu_action(
		$self->{recentfiles},
		'file.clean_recent_files',
	);

	$self->{recentfiles}->AppendSeparator;

	# NOTE: Do NOT do an initial fill during the constructor
	# We'll do one later anyway, and the list is premature at this point.
	# NOTE: Do not ignore the above note. I mean it --ADAMK
	# $self->refresh_recent;

	$self->AppendSeparator;

	# Word Stats
	$self->{docstat} = $self->add_menu_action(
		$self,
		'file.doc_stat',
	);

	$self->AppendSeparator;

	# Exiting
	$self->add_menu_action(
		$self,
		'file.quit',
	);

	return $self;
}

sub title {
	Wx::gettext('&File');
}

sub refresh {
	my $self     = shift;
	my $document = Padre::Current->document ? 1 : 0;

	$self->{open_in_file_browser}->Enable($document);
	if (Padre::Constant::WIN32) {

		#Win32
		$self->{open_with_default_system_editor}->Enable($document);
		$self->{open_in_command_line}->Enable($document);
	} else {

		#Disabled until a unix implementation is actually working
		#TODO remove once the unix implementation is done (see Padre::Util::FileBrowser)
		$self->{open_with_default_system_editor}->Enable(0);
		$self->{open_in_command_line}->Enable(0);
	}
	$self->{close}->Enable($document);
	$self->{close_all}->Enable($document);
	$self->{close_all_but_current}->Enable($document);
	$self->{reload_file}->Enable($document);
	$self->{reload_all}->Enable($document);
	$self->{save}->Enable($document);
	$self->{save_as}->Enable($document);
	$self->{save_all}->Enable($document);
	$self->{print}->Enable($document);
	defined( $self->{open_session} ) and $self->{open_selection}->Enable($document);
	defined( $self->{save_session} ) and $self->{save_session}->Enable($document);
	$self->{docstat}->Enable($document);

	return 1;
}

sub refresh_recent {
	my $self = shift;

	# menu entry count starts at 0
	# first 3 entries are "open all", "clean list" and a separator
	foreach my $i ( reverse( 3 .. $self->{recentfiles}->GetMenuItemCount - 1 ) ) {
		if ( my $item = $self->{recentfiles}->FindItemByPosition($i) ) {
			$self->{recentfiles}->Delete($item);
		}
	}

	my $idx = 0;
	foreach my $file ( Padre::DB::History->recent('files') ) {
		if (Padre::Constant::WIN32) {
			next unless -f $file;
		} else {

			# Try a non-blocking "-f" (doesn't work in all cases)
			# File does not exist or is not accessable.
			# NOTE: O_NONBLOCK does not exist on Windows, kaboom
			sysopen(
				my $fh,
				$file,
				Fcntl::O_RDONLY | Fcntl::O_NONBLOCK
			) or next;
			close $fh;
		}

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
					Padre::Current->main->lock( 'UPDATE', 'DB', 'refresh_recent' );
					Padre::DB::History->delete(
						'where name = ? and type = ?',
						$file, 'files',
					);
					Wx::MessageBox(
						sprintf( Wx::gettext("File %s not found."), $file ),
						Wx::gettext("Open cancelled"),
						Wx::wxOK,
						$self->{main},
					);
				}
			},
		);
		TRACE("Recent entry created for '$file'") if DEBUG;
	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

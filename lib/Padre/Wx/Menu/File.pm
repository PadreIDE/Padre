package Padre::Wx::Menu::File;

# Fully encapsulated File menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Constant ();
use Padre::Current  ();
use Padre::Feature  ();
use Padre::Logger;

our $VERSION = '0.94';
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
		'file.new',
	);

	my $file_new = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Ne&w'),
		$file_new,
	);

	$self->{duplicate} = $self->add_menu_action(
		$file_new,
		'file.duplicate',
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

	### NOTE: Add support for plugins here

	# Open things

	$self->add_menu_action(
		'file.open',
	);

	my $file_open = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('O&pen'),
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

	if (Padre::Constant::WIN32) {
		$self->{open_with_default_system_editor} = $self->add_menu_action(
			$file_open,
			'file.open_with_default_system_editor',
		);

		$self->{open_in_command_line} = $self->add_menu_action(
			$file_open,
			'file.open_in_command_line',
		);
	}

	$self->{open_example} = $self->add_menu_action(
		$file_open,
		'file.open_example',
	);

	$self->{open_last_closed_file} = $self->add_menu_action(
		$file_open,
		'file.open_last_closed_file',
	);

	$self->{close} = $self->add_menu_action(
		'file.close',
	);

	# Close things

	my $file_close = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('&Close'),
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

	$file_close->AppendSeparator;

	$self->{delete} = $self->add_menu_action(
		$file_close,
		'file.delete',
	);

	### End of close submenu

	# Reload file(s)
	my $file_reload = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('Re&load'),
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

	$self->{reload_some} = $self->add_menu_action(
		$file_reload,
		'file.reload_some',
	);

	### End of reload submenu

	$self->AppendSeparator;

	# Save files
	$self->{save} = $self->add_menu_action(
		'file.save',
	);

	$self->{save_as} = $self->add_menu_action(
		'file.save_as',
	);

	$self->{save_intuition} = $self->add_menu_action(
		'file.save_intuition',
	);

	$self->{save_all} = $self->add_menu_action(
		'file.save_all',
	);

	if (Padre::Feature::SESSION) {

		$self->AppendSeparator;

		# Session operations
		$self->{open_session} = $self->add_menu_action(
			'file.open_session',
		);

		$self->{save_session} = $self->add_menu_action(
			'file.save_session',
		);

	}

	$self->AppendSeparator;

	# Print files
	# $self->{print} = $self->add_menu_action(
		# 'file.print',
	# );

	# $self->AppendSeparator;

	# Recent things
	$self->{recentfiles} = Wx::Menu->new;
	$self->Append(
		-1,
		Wx::gettext('&Recent Files'),
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
	# open_recent_files - the menu is populated in ->refill_recent

	$self->AppendSeparator;

	# Word Stats
	$self->{docstat} = $self->add_menu_action(
		'file.properties',
	);

	$self->AppendSeparator;

	# Exiting
	$self->add_menu_action(
		'file.quit',
	);

	return $self;
}

sub title {
	Wx::gettext('&File');
}

sub refresh {
	my $self = shift;
	my $document = Padre::Current->document ? 1 : 0;

	$self->{open_in_file_browser}->Enable($document);
	$self->{duplicate}->Enable($document);
	if (Padre::Constant::WIN32) {
		$self->{open_with_default_system_editor}->Enable($document);
		$self->{open_in_command_line}->Enable($document);
	}
	$self->{close}->Enable($document);
	$self->{delete}->Enable($document);
	$self->{close_all}->Enable($document);
	$self->{close_all_but_current}->Enable($document);
	$self->{reload_file}->Enable($document);
	$self->{reload_all}->Enable($document);
	$self->{reload_some}->Enable($document);
	$self->{save}->Enable($document);
	$self->{save_as}->Enable($document);
	$self->{save_intuition}->Enable($document);
	$self->{save_all}->Enable($document);
	#$self->{print}->Enable($document);
	defined( $self->{open_session} ) and $self->{open_selection}->Enable($document);
	defined( $self->{save_session} ) and $self->{save_session}->Enable($document);
	$self->{docstat}->Enable($document);

	return 1;
}

# Does not do the actual refresh, just kicks off the background job.
sub refresh_recent {
	my $self = shift;

	# Fire the recent files background task
	require Padre::Task::RecentFiles;
	Padre::Task::RecentFiles->new(
		want => 9,
	)->schedule;

	return;
}

sub refill_recent {
	my $self  = shift;
	my $files = shift;
	my $lock  = $self->{main}->lock('UPDATE');

	# Flush the old menu.
	# Menu entry count starts at 0
	# The first 3 entries are "open all", "clean list" and a separator
	my $recentfiles = $self->{recentfiles};
	foreach my $i ( reverse( 3 .. $recentfiles->GetMenuItemCount - 1 ) ) {
		my $item = $recentfiles->FindItemByPosition($i) or next;
		$recentfiles->Delete($item);
	}

	# Repopulate with the new files
	my $last_closed_file_found;
	foreach my $i ( 1 .. 9 ) {
		my $file = $files->[ $i - 1 ] or last;

		# Store last closed file for the 'Open Last Closed File' feature
		unless ($last_closed_file_found) {
			$self->{main}->{_last_closed_file} = $file;
			$last_closed_file_found = 1;
		}
		Wx::Event::EVT_MENU(
			$self->{main},
			$recentfiles->Append( -1, "&$i. $file" ),
			sub {
				$self->on_recent($file);
			},
		);
	}

	# Enable/disable 'Open Last Closed File' menu item
	$self->{open_last_closed_file}->Enable( $last_closed_file_found ? 1 : 0 );

	return;
}

sub on_recent {
	my $self = shift;
	my $file = shift;

	# The file will most likely exist
	if ( -f $file ) {
		$self->{main}->setup_editors($file);
		return;
	}

	# Because we filter for files that exist to generate the recent files
	# list, anything that doesn't exist must have been deleted a short
	# time ago. So we can remove it from history, it won't be coming back.
	Padre::DB::History->delete(
		'where name = ? and type = ?',
		$file, 'files',
	);
	Wx::MessageBox(
		sprintf( Wx::gettext('File %s not found.'), $file ),
		Wx::gettext('Open cancelled'),
		Wx::OK,
		$self->{main},
	);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

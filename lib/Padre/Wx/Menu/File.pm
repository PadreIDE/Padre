package Padre::Wx::Menu::File;

# Fully encapsulated File menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current  ('_CURRENT');
use Padre::Logger;

our $VERSION = '0.54';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {

	# TO DO: Convert this to Padre::Action::File

	my $class = shift;
	my $main  = shift;

	my $config = Padre->ide->config;

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
		Wx::gettext("New..."),
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

	$self->add_menu_action(
		$self,
		'file.openurl',
	);

	$self->{open_example} = $self->add_menu_action(
		$self,
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
		Wx::gettext("Close..."),
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

	$self->{reload_file} = $self->add_menu_action(
		$self,
		'file.reload_file',
	);

	$self->{reload_all} = $self->add_menu_action(
		$self,
		'file.reload_all',
	);

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

	if ( $config->func_session ) {

		$self->AppendSeparator;

		# Specialised open and close functions
		$self->{open_selection} = $self->add_menu_action(
			$self,
			'file.open_selection',
		);

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

	$self->update_recentfiles;

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
	my $self = shift;

	return Wx::gettext('&File');
}



sub refresh {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $doc     = $current->document ? 1 : 0;

	$self->{close}->Enable($doc);
	$self->{close_all}->Enable($doc);
	$self->{close_all_but_current}->Enable($doc);
	$self->{reload_file}->Enable($doc);
	$self->{reload_all}->Enable($doc);
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
		TRACE("Recent entry created for '$file'") if DEBUG;
	}

	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

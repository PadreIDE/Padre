package Padre::Wx::Directory::OpenInFileBrowserAction;

use 5.008;
use strict;
use warnings;

# package exports and version
our $VERSION = '0.56';

# module imports
use Padre::Wx ();

# -- constructor
sub new {
	my ($class) = @_;
	return bless {}, $class;
}

#
# private method for executing a process without waiting
#
sub _execute {
	my ( $self, $exe_name, @cmd_args ) = @_;
	my $result = undef;

	require File::Which;
	my $cmd = File::Which::which($exe_name);
	if ( -e $cmd ) {

		# On Windows, if we don't have STDIN/STDOUT, avoid IPC::Open3
		# because it crashes when launching a non-console app
		if (Padre::Constant::WIN32) {
			# Spawn process without waiting (only on win32, see perlport)
			system( 1, $cmd, @cmd_args );
		} else {
			require IPC::Open2;
			my $ok = eval {
				my $r   = '';
				my $w   = '';
				my $pid = IPC::Open2::open2( $r, $w, $cmd, @cmd_args );
				1;
			};
			if ( !$ok ) {
				$result = $@;
			}
		}
	} else {
		$result = Wx::gettext("Failed to execute process\n");
	}
	return $result;
}

#
# Opens the provided filename in the File browser:
# On win32, selects it in Windows Explorer
# On linux, opens the containing folder for it
#
sub open_in_file_browser {
	my ( $self, $filename ) = @_;
	my $main = Padre::Current->main;

	unless ($filename) {
		$main->error( Wx::gettext("No filename") );
		return;
	}

	my $error;
	if (Padre::Constant::WIN32) {

		# In windows, simply execute: explorer.exe /select,"$filename"
		$filename =~ s/\//\\/g;
		$error = $self->_execute( 'explorer.exe', "/select,\"$filename\"" );
	} elsif (Padre::Constant::UNIX) {
		my $parent_folder = File::Basename::dirname($filename);
		$error = $self->_execute_unix($parent_folder);
	} else {

		# Unsupported
		$error = sprintf( Wx::gettext("Unsupported OS: %s"), '$^O' );
	}

	if ($error) {
		$main->error($error);
	}

	return;
}

#
# Open with default system editor
#
sub open_with_default_system_editor {
	my ( $self, $filename ) = @_;

	my $main = Padre::Current->main;
	unless ($filename) {
		$main->error( Wx::gettext("No filename") );
		return;
	}

	my $error;
	if (Padre::Constant::WIN32) {

		# Win32
		require Padre::Util::Win32;
		Padre::Util::Win32::ExecuteProcessAndWait(
			directory  => $self->{cwd},
			file       => $filename,
			parameters => '',
			show       => 1
		);
	} elsif (Padre::Constant::UNIX) {

		# Unix
		$error = $self->_execute_in_file_mananger($filename);
	} else {

		# Unsupported
		$error = sprintf( Wx::gettext("Unsupported OS: %s"), '$^O' );
	}

	if ($error) {
		$main->error($error);
	}

	return;
}

#
# Try to execute a file in KDE or GNOME
#
sub _execute_unix {
	die "Only to be called in UNIX!" unless Padre::Constant::UNIX;

	my ( $self, $filename ) = @_;

	my $error;
	if ( defined $ENV{KDE_FULL_SESSION} ) {

		# In KDE, execute: kfmclient exec $filename
		$error = $self->_execute( 'kfmclient', "exec", $filename );
	} elsif ( defined $ENV{GNOME_DESKTOP_SESSION_ID} ) {

		# In Gnome, execute: nautilus --nodesktop --browser $filename
		$error = $self->_execute( 'nautilus', "--no-desktop", "--browser", $filename );
	} else {
		$error = Wx::gettext("Could not find KDE or GNOME");
	}

	return $error;
}

1;

__END__

=head1 NAME

Padre::Wx::Directory::OpenInFileBrowserAction - Open in file browser action

=head1 DESCRIPTION

=head2 Open in File Browser

For the current saved Padre document, open the platform's file manager/browser and
tries to select it if possible. On win32, opens the containing folder and
selects the file in its explorer. On Linux KDE/GNOME, opens the containing folder
for it.

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

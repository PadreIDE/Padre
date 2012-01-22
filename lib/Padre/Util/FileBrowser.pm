package Padre::Util::FileBrowser;

=head1 NAME

Padre::Util::FileBrowser - Open in file browser action

=head1 DESCRIPTION

A collection of single-shot methods to open a file in the platform's file
manager or browser while trying to select it if possible.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;

# package exports and version
our $VERSION = '0.94';

use Padre::Constant ();

# -- constructor
sub new {
	my ($class) = @_;
	return bless {}, $class;
}

=head2 C<open_in_file_browser>

  Padre::Util::FileBrowser->open_in_file_browser($filename);

Single shot method to open the provided C<$filename> in the file browser
On win32, selects it in Windows Explorer
On UNIX, opens the containing folder for it using either KDE or GNOME

=cut

sub open_in_file_browser {
	my ( $class, $filename ) = @_;
	my $self = $class->new(@_);
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
		my $parent_folder = -d $filename ? $filename : File::Basename::dirname($filename);
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

=head2 C<open_with_default_system_editor>

  Padre::Util::FileBrowser->open_in_file_browser($filename);

Single shot method to open the provided C<$filename> using the default system editor

=cut

sub open_with_default_system_editor {
	my ( $class, $filename ) = @_;
	my $self = $class->new(@_);
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
		#TODO implement for UNIX
		$error = $self->_execute_unix($filename);
	} else {

		# Unsupported
		$error = sprintf( Wx::gettext("Unsupported OS: %s"), '$^O' );
	}

	if ($error) {
		$main->error($error);
	}

	return;
}

=head2 C<open_in_command_line>

  Padre::Util::FileBrowser->open_in_command_line($filename);

Single shot method to open a command line/shell using the working
directory of C<$filename>

=cut

sub open_in_command_line {
	my ( $class, $filename ) = @_;
	my $self = $class->new(@_);
	my $main = Padre::Current->main;

	unless ($filename) {
		$main->error( Wx::gettext("No filename") );
		return;
	}

	my $error;
	if (Padre::Constant::WIN32) {

		# Win32
		my $parent_folder = File::Basename::dirname($filename);
		system( 1, 'cmd', '/C', 'start', '/D', qq{"$parent_folder"} );
	} elsif (Padre::Constant::UNIX) {

		# Unix

		#TODO implement for UNIX
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

			# There is no actual waiting since cmd.exe starts explorer.exe and quits
			require Padre::Util::Win32;
			Padre::Util::Win32::ExecuteProcessAndWait(
				directory  => $self->{project},
				file       => 'cmd.exe',
				parameters => "/C $cmd @cmd_args",
			);
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
# Private method to execute a file in KDE or GNOME
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

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

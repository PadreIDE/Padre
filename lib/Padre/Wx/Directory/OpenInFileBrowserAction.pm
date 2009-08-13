package Padre::Wx::Directory::OpenInFileBrowserAction;

use strict;
use warnings;

# package exports and version
our $VERSION   = '0.42';

# module imports
use Padre::Wx ();

# accessors
use Class::XSAccessor accessors => {
	_plugin => '_plugin', # Plugin object
};

# -- constructor
sub new {
	my ( $class, $plugin ) = @_;

	my $self = bless {}, $class;
	$self->_plugin($plugin);

	return $self;
}

#
# private method for executing a process without waiting
#
sub _execute {
	my ( $self, $exe_name, @cmd_args ) = @_;
	my $result = undef;
	my $cmd    = File::Which::which($exe_name);
	if ( -e $cmd ) {
		require IPC::Open2;
		my $pid = IPC::Open2::open2( \*R, \*W, $cmd, @cmd_args );
	} else {
		$result = Wx::gettext("Failed to execute process\n");
	}
	return $result;
}

#
# For the current "saved" Padre document,
# On win32, selects it in Windows Explorer
# On linux, opens the containing folder for it
#
sub open_in_file_browser {
	my $self = shift;

	my $main     = $self->_plugin->main;
	my $filename = $main->current->filename;
	if ( not defined $filename ) {
		Wx::MessageBox( Wx::gettext("No filename"), Wx::gettext('Error'), Wx::wxOK, $main, );
		return;
	}

	require File::Which;

	my $error = undef;
	if ( $^O =~ /win32/i ) {

		# In windows, simply execute: explorer.exe /select,"$filename"
		$filename =~ s/\//\\/g;
		$error = $self->_execute( 'explorer.exe', "/select,\"$filename\"" );
	} elsif ( $^O =~ /linux|bsd/i ) {
		my $parent_folder = File::Basename::dirname($filename);
		if ( defined $ENV{KDE_FULL_SESSION} ) {

			# In KDE, execute: kfmclient exec $filename
			$error = $self->_execute( 'kfmclient', "exec", $parent_folder );
		} elsif ( defined $ENV{GNOME_DESKTOP_SESSION_ID} ) {

			# In Gnome, execute: nautilus --nodesktop --browser $filename
			$error = $self->_execute( 'nautilus', "--no-desktop", "--browser", $parent_folder );
		} else {
			$error = "Could not find KDE or GNOME";
		}
	} else {

		#Unsupported Operating system.
		$error = "Unsupported operating system: '$^O'";
	}

	if ( defined $error ) {
		Wx::MessageBox( $error, Wx::gettext("Error"), Wx::wxOK, $main, );
	}

	return;
}

1;

__END__

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 C<< <ahmad.zawawi at gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

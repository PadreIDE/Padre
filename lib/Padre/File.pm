package Padre::File;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

# a list of registered protocol handlers. Structure:
# regexp => [handler1, handler2, ...]
# Note that ONLY THE FIRST handler is used! This is meant to allow
# for plugins to enable and disable handlers with falling back to
# the previously instantiated handlers.
our %RegisteredModules;

=encoding UTF-8

=head1 NAME

Padre::File - Common API for file functions

=head1 DESCRIPTION

C<Padre::File> provides a common API for file access within Padre.
It covers all the differences with non-local files by mapping every function
call to the currently used transport stream.

=head1 METHODS

=head2 C<RegisterProtocol>

  Padre::File->RegisterProtocol($RegExp, $Module);

Class method, may not be called on an object.

A plug-in could call C<< Padre::File->RegisterProtocol >> to register a new protocol to
C<Padre::File> and enable Padre to use URLs handled by this module.

Example:

  Padre::File->RegisterProtocol('^nfs\:\/\/','Padre::Plugin::NFS');

Every file/URL opened through C<Padre::File> which starts with C<nfs://> is now
handled through C<Padre::Plugin::NFS>.
C<< Padre::File->new >> will respect this and call C<< Padre::Plugin::NFS->new >> to
handle such URLs.

Returns true on success or false on error.

Registered protocols may override the internal protocols.

=cut

sub RegisterProtocol {
	shift if defined $_[0] and $_[0] eq __PACKAGE__;
	my $regexp = shift;
	my $module = shift;

	return () if not defined $regexp or $regexp eq '';
	return () if not defined $module or $module eq '';
	$regexp = "$regexp";

	# no double insertion
	return ()
		if exists $RegisteredModules{$regexp}
			and grep { $_ eq $module } @{ $RegisteredModules{$regexp} };

	unshift @{ $RegisteredModules{$regexp} }, $module;

	return 1;
}


=head2 C<DropProtocol>

Drops a previously registered protocol handler. First argument must
be the same regular expression (matching a protocol from an URI)
that was used to register the protocol handler in the first place using
C<RegisterProtocol>. Similarly, the second argument must be the name of
the class (module) that the handler was registered for. That means
if you registered your protocol with

  Padre::File->RegisterProtocol(qr/^sftp:\/\//, 'Padre::File::MySFTP');

then you need to drop it with

  Padre::File->DropProtocol(qr/^sftp:\/\//, 'Padre::File::MySFTP');

Returns true if a handler was removed and the empty list if no
handler was found for the given regular expression.

=cut

sub DropProtocol {
	shift if defined $_[0] and $_[0] eq __PACKAGE__;
	my $regexp = shift;
	my $module = shift;

	return () if not defined $regexp or $regexp eq '';
	return () if not defined $module or $module eq '';
	$regexp = "$regexp";

	return () if not exists $RegisteredModules{$regexp};

	my $modules  = $RegisteredModules{$regexp};
	my $n_before = @$modules;
	@$modules = grep { $_ ne $module } @$modules; # drop this module only

	delete $RegisteredModules{$regexp} if @$modules == 0;

	return $n_before != @$modules;
}


=pod

=head2 C<new>

  my $file = Padre::File->new($File_or_URL);

The C<new> constructor lets you create a new C<Padre::File> object.

Only one parameter is accepted at the moment: The name of the file which should
be used. As soon as there are HTTP, FTP, SSH and other modules, also URLs
should be accepted.

If you know the protocol (which should be true every time you build the URL
by source), it's better to call C<< Padre::File::Protocol->new($URL) >> directly
(replacing Protocol by the protocol which should be used, of course).

The module for the selected protocol should fill C<< ->{filename} >> property. This
should be used for all further references to the file as it will contain the
file name in universal correct format (for example correct the C<C:\ eq C:/> problem
on Windows).

Returns a new C<Padre::File> or dies on error.

=cut

sub new {
	my $class = shift;
	my $URL   = shift;
	my %args  = @_;

	return if not defined($URL) or $URL eq '';

	my $self;

	for ( keys(%RegisteredModules) ) {
		next if $URL !~ /$_/;
		my $module = $RegisteredModules{$_}->[0];
		if ( eval "require $module; 1;" ) {
			$self = $module->new($URL);
			return $self;
		}
	}

	if ( $URL =~ /^file\:(.+)$/i ) {
		require Padre::File::Local;
		$self = Padre::File::Local->new( $1, @_ );

	} elsif ( $URL =~ /^https?\:\/\//i ) {
		require Padre::File::HTTP;
		$self = Padre::File::HTTP->new( $URL, @_ );
	} elsif ( $URL =~ /^ftp?\:/i ) {
		require Padre::File::FTP;
		$self = Padre::File::FTP->new( $URL, @_ );
	} else {
		require Padre::File::Local;
		$self = Padre::File::Local->new( $URL, @_ );
	}

	$self->{Filename} = $self->{filename}; # Temporary hack

	# Copy the info message handler to self
	$self->{info_handler} = $args{info_handler} if defined( $args{info_handler} );

	return $self;

}

=head2 C<atime>

  $file->atime;

Returns the last-access time of the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub atime { }

=head2 C<basename>

  $file->basename;

Returns the plain file name without path if a path/file name structure
exists for this module.

=cut

# Fallback if the module has no such function:
# It turned out that returning everything is much better
# than returning undef for this function:
sub basename {
	my $self = shift;
	return $self->{filename};
}

=head2 C<blksize>

  $file->blksize;

Returns the block size of the file system where the file resides.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub blksize { }

=head2 C<blocks>

  $file->blocks;

Returns the number of blocks used by the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub blocks { }

=head2 C<browse_mtime>

  $file->browse_mtime($path_and_filename);

Returns the modification time of the given file on the remote server.

Leave out the protocol and server name for remote protocols, for example

  my $file = Padre::File->new('http://perlide.org/current/foo.html');
  $file->browse_mtime('/archive/bar.html');

This returns the modification time of C<http://perlide.org/archive/bar.html>

The default uses one C<Padre::File> clone per request which is a reasonable
fallback but very inefficient! Please add C<browse_…> methods to the
subclass module whenever possible.

=cut

sub browse_mtime {
	my $self     = shift;
	my $filename = shift;

	my $file = $self->clone_file($filename);
	return $file->mtime;
}

=pod

=head2 C<browse_url_join>

  $file->browse_url_join($server, $path, $basename);

Merges a server name, path name and a file name to a complete URL.

A C<path> in this function is meant to be the local path on the server,
not the Padre path (which includes the server name).

You may think of

  /tmp + padre.$$                       => /tmp/padre.$$
  C:\\temp + padre.$$                   => C:\\temp\\padre.$$

...but also remember

  http://perlide.org + about.html       => http://perlide.org/about.html

Datapoint created a file syntax...

  common + program/text                 => program/text:common

This could happen once someone adds a C<Padre::File::DBCFS> for using
a C<DB/C FS> file server. C<program> is the file name, C<text> the extension
and "common" is what we call a directory.

The most common seems to be a C</> as the directory separator character, so
we'll use this as the default.

This method should care about merging double C</> to one if this should
be done on this file system (even if the default doesn't care).

=cut

# Note: Don't use File::Spec->catfile here as it may mix up http or
#       other pathnames. This is a default and should be overriden
#       by each Padre::File::* - module!
sub browse_url_join {
	my $self     = shift;
	my $server   = shift;
	my $path     = shift;
	my $basename = shift;

	return $self->{protocol} . '://' . $server . '/' . $path . '/' . $basename if defined($basename);
	return $self->{protocol} . '://' . $server . '/' . $path;
}

=pod

=head2 C<can_clone>

  $file->can_clone;

Returns true if the protocol allows re-using of connections for new
files (usually from the same project).

Local files don't use connections at all, HTTP uses one-request-
connections, cloning has no benefit for them. FTP and SSH use
connections to a remote server and we should work to get no more
than one connection per server.

=cut

sub can_clone {

	# Cloning needs to be supported by the protocol, the safer
	# option is false here.
	return 0;
}

=pod

=head2 C<can_delete>

  $file->can_delete;

Returns true if the protocol allows deletion of files or false if it
doesn't.

=cut

sub can_delete {

	# If the module does not state that it could remove files,
	# we return a safe default of false.
	return 0;
}

=pod

=head2 C<can_run>

  $file->can_run;

Returns true if the protocol allows execution of files or the empty
list if it doesn't.

This is usually not possible for non-local files (which return true),
because there is no way to reproduce a save environment for running
a HTTP or FTP based file (they return false).

=cut

sub can_run {

	# If the module does not state that it could do "run",
	# we return a safe default of false.
	return 0;
}

=pod

=head2 C<clone>

  my $clone = $file->clone($File_or_URL);

The C<clone> constructor lets you create a new C<Padre::File> object reusing
an existing connection.

Takes the same arguments as the C<new> method.

If the protocol doesn't know about (server) connections/sessions, returns a
brand new Padre::File object.

NOTICE: If you request a clone which is located on another server, you'll
        get a Padre::File object using the original connection to the
        original server and the original authentication data but the new
        path and file name!

Returns a new C<Padre::File> or dies on error.

=cut

sub clone {
	my $self = shift;

	my $class = ref($self);

	return $class->new(@_);
}

=pod

=head2 C<clone_file>

  my $clone = $file->clone_file($filename_with_path);
  my $clone = $file->clone_file($path,$filename);

The C<clone> constructor lets you create a new C<Padre::File> object reusing
an existing connection.

Takes one or two arguments:

=over

=item either the complete path + file name of an URL

=item or the path and file name as separate arguments

=back

If the protocol doesn't know about (server) connections/sessions, returns a
brand new C<Padre::File> object.

Returns a new C<Padre::File> or dies on error.

=cut

sub clone_file {
	my $self     = shift;
	my $path     = shift;
	my $filename = shift;

	return $self->clone( $self->browse_url_join( $self->servername, $path, $filename ) );
}

=head2 C<ctime>

  $file->ctime;

Returns the last-change time of the inode (not the file!).

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub ctime { }

=head2 C<delete>

  $file->delete;

Removes the current object's file from disk (or whereever it's stored).

Should clear any caches.

=cut

sub delete { }

=head2 C<dev>

  $file->dev;

Returns the device number of the file system where the file resides.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub dev { }

=head2 C<dirname>

  $file->dirname;

Returns the plain path without file name if a path/file name structure
exists for this module.

Returns the empty list on failure or undefined behaviour for the
given protocol.

=cut

sub dirname { }

=head2 C<error>

  $file->error;

Returns the last error message (like $! for system calls).

=cut

sub error {
	my $self = shift;
	return $self->{error};
}

=head2 C<exists>

  $file->exists;

Returns true if the file exists.
Returns false if the file doesn't exist.
Returns the empty list if unsure (network problem, not implemented).

=cut

# Fallback if the module has no such function:
sub exists {

	my $self = shift;

	# A size indicates that the file exists:
	return 1 if $self->size;

	return;
}

=head2 C<filename>

  $file->filename;

Returns the the file name including path handled by this object.

Please remember that C<Padre::File> is able to open many URL types. This
file name may also be a URL. Please use the C<basename> and C<dirname>
methods to split it (assuming that a path exists in the current
protocol).

=cut

# Fallback if the module has no such function:
sub filename {
	my $self = shift;
	return $self->{filename};
}

=head2 C<gid>

  $file->gid;

Returns the real group ID of the file group.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub gid { }

=head2 C<inode>

  $file->inode;

Returns the inode number of the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub inode { }

=head2 C<mime>

  $file->mime;
  $file->mime('text/plain');

Returns or sets the MIME type of the file.

=cut

sub mime {
	my $self     = shift;
	my $new_mime = shift;
	defined($new_mime) and $self->{MIME} = $new_mime;
	return $self->{MIME};
}

=head2 C<mode>

  $file->mode;

Returns the file mode (type and rights). See also: L<perlfunc/stat>.
To get the POSIX file I<permissions> as the usual octal I<number>
(as opposed to a I<string>) use:

  use Fcntl ':mode';
  my $perms_octal = S_IMODE($file->mode);

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub mode { }

=head2 C<mtime>

  $file->mtime;

Returns the last-modification (change) time of the file.

=cut

sub mtime { }

=head2 C<nlink>

  $file->nlink;

Returns the number of hard links to the file.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub nlink { }

=head2 C<rdev>

  $file->rdev;

Returns the device identifier.

This is usually not possible for non-local files, in these cases,
the empty list is returned.

=cut

sub rdev { }

=head2 C<read>

  $file->read;

Reads the file contents and returns them.

Returns the empty list on error. The error message can be retrieved using the
C<error> method.

=cut

=head2 C<servername>

  $file->servername;

Returns the server name for this module - if the protocol knows about a
server, local files don't.

WARNING: The Padre C<path> includes the server name in a protocol dependent
         syntax!

=cut

sub servername {
	my $self = shift;
	return '';
}


=head2 C<size>

  $file->size;

Returns the file size in bytes or the empty list if the
method was not implemented by the C<Padre::File> subclass.

=cut

sub size { }

=head2 C<stat>

  $file->stat;

This emulates a stat call and returns the same values:


  0 dev      device number of file system
  1 ino      inode number
  2 mode     file mode  (type and permissions)
  3 nlink    number of (hard) links to the file
  4 uid      numeric user ID of file's owner
  5 gid      numeric group ID of file's owner
  6 rdev     the device identifier (special files only)
  7 size     total size of file, in bytes
  8 atime    last access time in seconds since the epoch
  9 mtime    last modify time in seconds since the epoch
 10 ctime    inode change time in seconds since the epoch (*)
 11 blksize  preferred block size for file system I/O
 12 blocks   actual number of blocks allocated

A module should fill as many items as possible, but if you're thinking
about using this method, always remember

=over

=item 1.

Usually, you need only one or two of the items, request them directly.

=item 2.

Besides from local files, most of the values will not be accessible (resulting
in empty lists/false returned).

=item 3.

On most protocols these values must be requested one-by-one, which is very
expensive.

=back

Please always consider using the function for the value you really need
instead of using C<stat>!

=cut

sub stat {
	my $self = shift;

	# If the module has a own stat function, we won't ever reach this point!

	return (
		$self->dev,
		$self->inode,
		$self->nlink,
		$self->uid,
		$self->gid,
		$self->rdev,
		$self->size,
		$self->atime,
		$self->mtime,
		$self->ctime,
		$self->blksize,
		$self->blocks
	);

}

=head2 C<uid>

  $file->uid;

Returns the real user ID of the file owner.

This is usually not possible for non-local files, in these cases, the empty list
is returned.

=cut

sub uid { }

=head2 C<write>

  $file->write($Content);
  $file->write($Content,$Coding);

Writes the given C<$Content> to the file, if a encoding is given and the
protocol allows encoding, it is respected.

Returns 1 on success.
Returns 0 on failure.
Returns the empty list if the function is not available on the protocol.

=cut

sub write { }

=head1 INTERNAL METHODS

=head2 C<_info>

  $file->_info($message);

Shows $message to the user as an information. The output is guaranteed to
be non-blocking and messages shown this way must be safe to be ignored by
the user.

Doesn't return anything.

=cut

sub _info {
	my $self    = shift;
	my $message = shift;

	# Return silently if no handler for info message is defined
	return unless defined( $self->{info_handler} ) and ( ref( $self->{info_handler} ) eq 'CODE' );

	# Handle the info message but don't fail on DIEs:
	eval { &{ $self->{info_handler} }( $self, $message ); };
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

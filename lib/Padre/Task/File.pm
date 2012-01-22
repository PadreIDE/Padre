package Padre::Task::File;

=pod

=head1 NAME

Padre::Task::File - File operations in the background

=head1 SYNOPSIS

  # Recursively delete
  Padre::Task::File->new(
    remove => 'C:\foo\bar\baz',
  )->schedule;

=head1 DESCRIPTION

The L<File::Remove> CPAN module is a specialised package for deleting files
or recursively deleting directories.

As well as providing the basic support for recursive deletion, it adds
several other important features such as removing readonly limits on the fly,
taking ownership of files if permitted, and moving the current working
directory out of the deletion path so that directory cursors won't block the
deletion (a particular problem on Windows).

The task takes the name of a single file or directory to delete (for now), and
proceeds to attempt a recursive deletion of the file or directory via the
L<File::Remove> C<remove> method.

In the future, this module will also support more types of file operations
and support the execution of a list of operations.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use File::Spec  ();
use Padre::Task ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

=pod

=head2 new

  my $task = Padre::Task::File->new(
      remove => '/foo/bar/baz',
  );

Creates a new deletion task.

Takes a single parameter C<remove> which B<must> be an absolute path to the
file to delete (as the "current directory" may change between the time the
removal task is created and when it is executed).

=cut

sub new {
	my $self = shift->SUPER::new(@_);

	# Check the path to remove
	unless ( defined $self->remove ) {
		die "Missing or invalid path";
	}
	unless ( File::Spec->file_name_is_absolute( $self->remove ) ) {
		die "File path is not absolute";
	}

	return $self;
}

=pod

=head2 remove

The C<remove> accessor returns the absolute path of the file or directory the
task will try to delete (or tried to delete in the case of completed tasks).

=cut

sub remove {
	$_[0]->{remove};
}





######################################################################
# Padre::Task Methods

sub run {
	my $self = shift;

	# Do not check for the path existing at prepare time as this involves
	# a blocking stat call. Better to just pass it through and do the file
	# existance check and any resulting shortcuts in the background.
	my $path = $self->remove;
	unless ( -e $path ) {
		return 1;
	}

	# Hand off to the specialist module
	require File::Remove;
	$self->{removed} = [ File::Remove::remove( \1, $path ) ];

	return 1;
}

1;

=pod

=head1 SEE ALSO

L<Padre>, L<Padre::Task>, L<File::Remove>

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

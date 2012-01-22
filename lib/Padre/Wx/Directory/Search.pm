package Padre::Wx::Directory::Search;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;
use Scalar::Util               ();
use Padre::Task                ();
use Padre::Wx::Directory::Path ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';

use constant NO_WARN => 1;





######################################################################
# Constructor

sub new {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift->SUPER::new(@_);

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
		$self->{skip} = $self->{project}->ignore_skip;
		delete $self->{project};
	}

	# Check params
	unless ( defined $self->{skip} ) {
		$self->{skip} = [];
	}
	unless ( defined $self->{order} ) {
		$self->{order} = 'first';
	}
	unless ( defined $self->{filter} and length $self->{filter} ) {
		die "Missing or invalid 'filter' parameter";
	}

	return $self;
}





######################################################################
# Padre::Task Methods

# If somehow we tried to run with a non-existint root, skip
sub prepare {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	return 0 unless defined $self->{root};
	return 0 unless length $self->{root};
	return 0 unless -d $self->{root};
	return 1;
}

sub run {
	TRACE( $_[0] ) if DEBUG;
	require Module::Manifest;
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;
	my @files = ();

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

	# Prepare the file name filter.
	# Doing this case insensitive probably makes more sense.
	my $filter = quotemeta $self->{filter};
	$filter = qr/$filter/i;

	# WARNING!!!
	# what should really happen here?
	# I'm only initialising the values here as
	# t/62-directory-task.t and t/63-directory-project.t
	# fails the no warnings test
	# but I'm quite sure you don't want an empty string
	# should it test and return maybe?
	my $path = defined( $queue[0]->path ) ? $queue[0]->path : "";
	my $name = defined( $queue[0]->name ) ? $queue[0]->name : "";
	my %seen = ( File::Spec->catdir( $path, $name ) => $queue[0] );

	# Get the device of the root path
	my $dev = ( stat($root) )[0];

	# Recursively scan for files
	while (@queue) {

		# Abort the task if we've been cancelled
		if ( $self->cancelled ) {
			TRACE('Padre::Wx::Directory::Search task has been cancelled') if DEBUG;
			$self->tell_status;
			return 1;
		}

		# Is this a file?
		my $object = shift @queue;
		if ( $object->is_file ) {

			# Does the file name match the filter?
			if ( $object->name =~ $filter ) {

				# Send the matching file to the parent thread
				$self->tell_owner($object);
			}
			next;
		}

		# Read the file list for the directory
		# NOTE: Silently ignore any that fail. Anything we don't have
		# permission to see inside of them will just be invisible.
		my @path = $object->path;
		my $dir = File::Spec->catdir( $root, @path );
		opendir DIRECTORY, $dir or next;
		my @list = readdir DIRECTORY;
		closedir DIRECTORY;

		# Notify our parent we are working on this directory
		$self->tell_status( "Searching... " . $object->unix );

		# Step 1 - Map the files into path objects
		my @objects = ();
		foreach my $file (@list) {
			next if $file =~ /^\.+\z/;

			# Abort the task if we've been cancelled
			if ( $self->cancelled ) {
				TRACE('Padre::Wx::Directory::Search task has been cancelled') if DEBUG;
				$self->tell_status;
				return 1;
			}

			# Traverse symlinks
			my $skip = 0;
			my $fullname = File::Spec->catdir( $dir, $file );
			while (1) {
				my $target;

				# readlink may die if symlinks are not implemented
				local $@;
				eval { $target = readlink($fullname); };
				last if $@; # readlink failed
				last unless defined $target; # not a link

				# Target may be "/home/user/foo" or "../foo" or "bin/foo"
				$fullname =
					File::Spec->file_name_is_absolute($target)
					? $target
					: File::Spec->canonpath( File::Spec->catdir( $dir, $target ) );

				# Get it from the cache in case of loops:
				if ( exists $seen{$fullname} ) {
					if ( defined $seen{$fullname} ) {
						push @files, $seen{$fullname};
					}
					$skip = 1;
					last;
				}

				# Prepare a cache object to step out of symlink loops
				$seen{$fullname} = undef;
			}
			next if $skip;

			# File doesn't exist, either a directory error, symlink to nowhere or something unexpected.
			# Don't worry, just skip, because we can't show it in the dir browser anyway
			my @fstat = stat($fullname);
			next if $#fstat == -1;

			if ( $dev != $fstat[0] ) {
				warn "DirectoryBrowser root-dir $root is on a different device than $fullname, skipping (FIX REQUIRED!)"
					unless NO_WARN;
				next;
			}

			# Convert to the path object and apply ignorance
			# The four element list we add is the mapping phase
			# of a Schwartzian transform.
			if ( -f _ ) {
				my $child = Padre::Wx::Directory::Path->file( @path, $file );
				next if $rule->skipped( $child->unix );
				push @objects,
					[
					$child,
					$fullname,
					$child->is_directory,
					lc( $child->name ),
					];

			} elsif ( -d _ ) {
				my $child = Padre::Wx::Directory::Path->directory( @path, $file );
				next if $rule->skipped( $child->unix );
				push @objects,
					[
					$child,
					$fullname,
					$child->is_directory,
					lc( $child->name ),
					];
			} else {
				warn "Unknown or unsupported file type for $fullname" unless NO_WARN;
			}
		}

		# Step 2 - Apply the desired sort order
		if ( $self->{order} eq 'first' ) {
			@objects =
				sort { $b->[2] <=> $a->[2] or $a->[3] cmp $b->[3] } @objects;
		} else {
			@objects = sort { $a->[3] cmp $b->[3] } @objects;
		}

		# Step 3 - Prepend to the queue so we will process depth-first
		unshift @queue, map { $_->[0] } @objects;
	}

	# Notify our parent we are finished searching
	$self->tell_status;

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

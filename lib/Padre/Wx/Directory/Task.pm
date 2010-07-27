package Padre::Wx::Directory::Task;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;
use Scalar::Util               ();
use Padre::Task                ();
use Padre::Wx::Directory::Path ();

our $VERSION = '0.67';
our @ISA     = 'Padre::Task';

use constant NO_WARN => 1;





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
		$self->{skip} = $self->{project}->ignore_skip;
		delete $self->{project};
	}

	# Property defaults
	unless ( defined $self->{skip} ) {
		$self->{skip} = [];
	}
	unless ( defined $self->{recursive} ) {
		$self->{recursive} = 1;
	}
	unless ( defined $self->{order} ) {
		$self->{order} = 'first';
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	require Module::Manifest;
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;
	my @files = ();

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

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
		my $parent = shift @queue;
		my @path   = $parent->path;
		my $dir    = File::Spec->catdir( $root, @path );

		# Read the file list for the directory
		# NOTE: Silently ignore any that fail. Anything we don't have
		# permission to see inside of them will just be invisible.
		opendir DIRECTORY, $dir or next;
		my @list = readdir DIRECTORY;
		closedir DIRECTORY;

		# Step 1 - Map the files into path objects
		my @objects = ();
		foreach my $file (@list) {
			next if $file =~ /^\.+\z/;

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
				my $object = Padre::Wx::Directory::Path->file( @path, $file );
				next if $rule->skipped( $object->unix );
				push @objects,
					[
					$object,
					$fullname,
					$object->is_directory,
					lc( $object->name ),
					];

			} elsif ( -d _ ) {
				my $object = Padre::Wx::Directory::Path->directory( @path, $file );
				next if $rule->skipped( $object->unix );
				push @objects,
					[
					$object,
					$fullname,
					$object->is_directory,
					lc( $object->name ),
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

		# Step 3 - Inject into the output list below our parent so
		# that the directory tree will generate properly.
		my $i = 0;
		my $p = Scalar::Util::refaddr($parent);
		foreach ( 0 .. $#files ) {
			next unless Scalar::Util::refaddr( $files[$_] ) == $p;
			$i = $_ + 1;
			last;
		}
		splice @files, $i, 0, map { $_->[0] } @objects;

		# Step 4 - Queue the directories to recurse into
		foreach my $object (@objects) {
			next unless $object->[2];

			# NOTE: Selective expansion should be done here
			next unless $self->{recursive};

			# Because we now sort a directory at a time, we'll need to do it
			# depth-first. So add the directories to the front of the queue.
			push @queue, $object->[0];
			$seen{ $object->[1] } = $object->[0];
		}
	}

	# Save and return
	$self->{model} = [@files];

	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

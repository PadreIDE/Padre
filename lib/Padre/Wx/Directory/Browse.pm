package Padre::Wx::Directory::Browse;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;
use Scalar::Util               ();
use Padre::Task                ();
use Padre::Constant            ();
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
	unless ( defined $self->{order} ) {
		$self->{order} = 'first';
	}
	unless ( defined $self->{skip} ) {
		$self->{skip} = [];
	}
	unless ( defined $self->{list} ) {
		die "Did not provide a directory list to refresh";
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub prepare {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;
	return 0 unless defined $self->{root};
	return 0 unless length $self->{root};

	# You can't opendir a UNC path on Windows,
	# so any attempt to run this task is pointless.
	if (Padre::Constant::WIN32) {
		return 0 if $self->{root} =~ /\\\\/;
	}

	# Don't run if our root path does not exist any more
	return 0 unless -d $self->{root};

	return 1;
}

sub run {
	TRACE( $_[0] ) if DEBUG;
	require Module::Manifest;
	my $self  = shift;
	my $root  = $self->{root};
	my $list  = $self->{list};
	my @queue = @$list;

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

	# Get the device of the root path
	my $dev = ( stat($root) )[0];

	# Recursively scan directories for their content
	my $descend = scalar @$list;
	while (@queue) {

		# Abort the task if we've been cancelled
		if ( $self->cancelled ) {
			TRACE('Padre::Wx::Directory::Search task has been cancelled') if DEBUG;
			return 1;
		}

		# Read the file list for the directory
		# NOTE: Silently ignore any that fail. Anything we don't have
		# permission to see inside of them will just be invisible.
		$descend--;
		my $request = shift @queue;
		my @path    = $request->path;
		my $dir     = File::Spec->catdir( $root, @path );
		next unless -d $dir;
		opendir DIRECTORY, $dir or next;
		my @list = readdir DIRECTORY;
		closedir DIRECTORY;

		# Step 1 - Map the files into path objects
		my @objects = ();
		foreach my $file (@list) {
			next if $file =~ /^\.+\z/;

			# Traverse symlinks
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
			}

			# File doesn't exist, either a directory error, symlink to nowhere or something unexpected.
			# Don't worry, just skip, because we can't show it in the dir browser anyway
			my @fstat = stat($fullname);
			next if $#fstat == -1;

			unless ( $dev == $fstat[0] ) {
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
				if ( $descend >= 0 ) {
					push @queue, $child;
				}
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

		# Step 3 - Send the completed directory back to the parent process
		#          Don't send a response if the directory is empty.
		#          Also skip if we are running in the parent and have no handle.
		if ( $self->is_child and @objects ) {
			$self->tell_owner( $request, map { $_->[0] } @objects );
		}
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

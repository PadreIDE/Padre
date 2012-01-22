package Padre::Task::ReplaceInFiles;

use 5.008;
use strict;
use warnings;
use File::Spec    ();
use Time::HiRes   ();
use Padre::Search ();
use Padre::Task   ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} ||= $self->{project}->root;
		$self->{skip} = $self->{project}->ignore_skip;
		delete $self->{project};
	}

	# Property defaults
	unless ( defined $self->{dryrun} ) {
		$self->{dryrun} = 0;
	}
	unless ( defined $self->{binary} ) {
		$self->{binary} = 0;
	}
	unless ( defined $self->{skip} ) {
		$self->{skip} = [];
	}
	unless ( defined $self->{maxsize} ) {
		require Padre::Current;
		$self->{maxsize} = Padre::Current->config->editor_file_size_limit;
	}

	# Create the embedded search object
	unless ( $self->{search} ) {
		$self->{search} = Padre::Search->new(
			find_term    => $self->{find_term},
			find_case    => $self->{find_case},
			find_regex   => $self->{find_regex},
			replace_term => $self->{replace_term},
		) or return;
	}

	return $self;
}

sub root {
	$_[0]->{root};
}





######################################################################
# Padre::Task Methods

sub run {
	require Module::Manifest;
	require Padre::Wx::Directory::Path;
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

	# Recursively scan for files
	while (@queue) {

		# Abort the task if we've been cancelled
		if ( $self->cancelled ) {
			TRACE('Padre::Wx::Directory::Search task has been cancelled') if DEBUG;
			$self->tell_status;
			return 1;

		}

		my $parent = shift @queue;
		my @path   = $parent->path;
		my $dir    = File::Spec->catdir( $root, @path );

		# Read the file list for the directory
		# NOTE: Silently ignore any that fail. Anything we don't have
		# permission to see inside of them will just be invisible.
		opendir DIRECTORY, $dir or next;
		my @list = sort readdir DIRECTORY;
		closedir DIRECTORY;

		# Notify our parent we are working on this directory
		$self->tell_status( "Searching... " . $parent->unix );

		my @children = ();
		foreach my $file (@list) {
			my $skip = 0;
			next if $file =~ /^\.+\z/;
			next if $file =~ /^\.svn$/;
			next if $file =~ /^\.git$/;

			# Abort the task if we've been cancelled
			if ( $self->cancelled ) {
				TRACE('Padre::Wx::Directory::Search task has been cancelled') if DEBUG;
				$self->tell_status;
				return 1;
			}

			# Confirm the file still exists and get stat details
			my $fullname = File::Spec->catdir( $dir, $file );
			my @fstat = stat($fullname);
			unless ( -e _ ) {

				# The file dissapeared mid-search?
				next;
			}

			# Handle non-files
			if ( -d _ ) {
				my $object = Padre::Wx::Directory::Path->directory( @path, $file );
				next if $rule->skipped( $object->unix );
				push @children, $object;
				next;
			}
			unless ( -f _ ) {
				warn "Unknown or unsupported file type for $fullname";
				next;
			}
			unless ( -w _ ) {
				warn "No write permissions for $fullname";
				next;
			}

			# This is a file
			my $object = Padre::Wx::Directory::Path->file( @path, $file );
			next if $rule->skipped( $object->unix );

			# Skip if the file is too big
			if ( $fstat[7] > $self->{maxsize} ) {
				TRACE("Skipped $fullname: File size $fstat[7] exceeds maximum of $self->{maxsize}") if DEBUG;
				next;
			}

			# Unless specifically told otherwise, only read text files
			unless ( $self->{binary} or -T _ ) {
				next;
			}

			# Read the entire file
			open( my $fh, '<', $fullname ) or next;
			binmode($fh);
			my $buffer = do { local $/; <$fh> };
			close $fh;

			# Is this the correct MIME type
			if ( $self->{mime} ) {
				require Padre::MIME;
				my $type = Padre::MIME->detect(
					file => $fullname,
					text => $buffer,
				);
				unless ( defined $type and $type eq $self->{mime} ) {
					TRACE("Skipped $fullname: Not a $self->{mime} (got " . ($type || 'undef') . ")") if DEBUG;
					next;
				}
			}

			# Allow the search object to do the main work
			local $@;
			my $count = eval { $self->{search}->replace_all( \$buffer ) };
			if ($@) {
				TRACE("Replace crashed in $fullname") if DEBUG;
				$self->tell_owner( $object, -1 );
				next;
			}
			next unless $count;

			# Save the changed file
			TRACE("Replaced $count matches in $fullname") if DEBUG;
			unless ( $self->{dryrun} ) {
				open( my $fh, '>', $fullname ) or next;
				binmode($fh);
				local $/;
				$fh->print($buffer);
				close $fh;
			}

			# Made changes, inform out owner
			$self->tell_owner( $object, $count );
		}
		unshift @queue, @children;
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

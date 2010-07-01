package Padre::Task::FindInFiles;

use 5.008;
use strict;
use warnings;
use File::Spec ();

our $VERSION = '0.66';





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

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	require Module::Manifest;
	require Padre::Wx::Directory::Path;
	my $self  = shift;
	my $root  = $self->{root};
	my @queue = Padre::Wx::Directory::Path->directory;
	my @files = ();

	# Prepare the search regex
	my $term = $self->{find_term};
	if ( $self->{find_regex} ) {

		# Escape non-trailing $ so they won't interpolate
		$term =~ s/\$(?!\z)/\\\$/g;
	} else {

		# Escape everything
		$term = quotemeta $term;
	}

	# Compile the search regexp
	my $regexp = eval {
		$self->{find_case} ? qr/$term/m : qr/$term/mi
	};
	return 1 if $@;

	# Prepare the skip rules
	my $rule = Module::Manifest->new;
	$rule->parse( skip => $self->{skip} );

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

		foreach my $file (@list) {
			my $skip = 0;
			next if $file =~ /^\.+\z/;
			my $fullname = File::Spec->catdir( $dir, $file );
			my @fstat    = stat($fullname);

			if ( -f _ ) {
				my $object = Padre::Wx::Directory::Path->file( @path, $file );
				next if $rule->skipped( $object->unix );
				$self->file( $regexp => $object );

			} elsif ( -d _ ) {
				my $object = Padre::Wx::Directory::Path->directory( @path, $file );
				next if $rule->skipped( $object->unix );
				unshift @queue, $object;

			} else {
				warn "Unknown or unsupported file type for $fullname" unless NO_WARN;
			}

		}
	}

	return 1;
}

sub file {
	my $self = shift;
	my $rule = shift;
	my $file = shift;

	# Load the file
	die "CODE INCOMPLETE";
}

1;

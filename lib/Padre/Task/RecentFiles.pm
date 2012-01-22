package Padre::Task::RecentFiles;

use 5.008;
use strict;
use warnings;
use Padre::Task     ();
use Padre::Constant ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Check params
	unless ( $self->{want} ) {
		die "Missing or invalid want param";
	}

	return $self;
}





######################################################################
# Padre::Task Methods

# Fetch the state data at the last moment, to maximise accuracy.
sub prepare {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Save the list of open files
	require Padre::Current;
	$self->{open} = [
		grep { defined $_ }
		map  { $_->filename } Padre::Current->main->documents
	];

	# Load the last 100 recent files
	require Padre::DB;
	$self->{history} = Padre::DB::History->recent( 'files', 100 );

	return 1;
}

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Index the open files
	my %skip = map { $_ => 1 } @{ $self->{open} };

	# Iterate through our candidates
	my @recent = ();
	foreach my $file ( @{ $self->{history} } ) {
		next if $skip{$file};
		TRACE("Checking $file\n") if DEBUG;

		# Abort the task if we've been cancelled
		if ( $self->cancelled ) {
			TRACE( __PACKAGE__ . ' task cancelled' ) if DEBUG;
			return 1;
		}

		if (Padre::Constant::WIN32) {

			# NOTE: Does anyone know a smarter way to do this?
			next unless -f $file;
		} else {

			# Try a non-blocking "-f" (doesn't work in all cases)
			# File does not exist or is not accessable.
			# NOTE: O_NONBLOCK does not exist on Windows, kaboom
			require Fcntl;
			sysopen(
				my $fh,
				$file,
				Fcntl::O_RDONLY | Fcntl::O_NONBLOCK
			) or next;
			close $fh;
		}

		# This file looks good, do we have enough?
		push @recent, $file;
		if ( @recent >= $self->{want} ) {
			last;
		}
	}

	# Completed without crashing or failure, return the list
	$self->{recent} = \@recent;

	return 1;
}

sub finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# If we ran successfully, hand off the list of known-good files
	# to the menu to populate it.
	if ( $self->{recent} ) {
		require Padre::Current;
		Padre::Current->main->menu->file->refill_recent( $self->{recent} );
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

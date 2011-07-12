package Padre::Lock;

use 5.008;
use strict;
use warnings;
use Carp ();

our $VERSION = '0.87';

sub new {
	my $class  = shift;
	my $locker = shift;
	my $self   = bless [ $locker ], $class;

	# Enable the locks
	my $db      = 0;
	my $config  = 0;
	my $busy    = 0;
	my $update  = 0;
	my $refresh = 0;
	foreach (@_) {
		if ( $_ ne uc $_ ) {
			$locker->method_increment($_);
			push @$self, $_;

		} elsif ( $_ eq 'BUSY' ) {
			$locker->busy_increment;
			$busy = 1;

		} elsif ( $_ eq 'CONFIG' ) {
			# Have CONFIG take an implicit DB lock as well so
			# that any writes for DB locks opened while the CONFIG
			# lock is open are aggregated into a single commit with
			# DB writes from a config unlock.
			$locker->config_increment;
			$locker->db_increment;
			$config = 1;
			$db     = 1;

		} elsif ( $_ eq 'DB' ) {
			$locker->db_increment;
			$db = 1;

		} elsif ( $_ eq 'REFRESH' ) {
			$locker->method_increment;
			$refresh = 1;

		} elsif ( $_ eq 'UPDATE' ) {
			$locker->update_increment;
			$update = 1;

		} else {
			Carp::croak("Unknown or unsupported special lock '$_'");
		}
	}

	# We always want to unlock commit/busy/update last.
	# NOTE: Putting DB last means that actions involving a database commit
	#       will APPEAR to happen faster. However, this could be somewhat
	#       disconcerting for long commits, because there will be user input
	#       lag immediately after it appears to be "complete". If this
	#       becomes a problem, move the DB to first so actions appear to be
	#       slower, but the UI is immediately available once updated.
	# NOTE: Because configuration involves a database write, we always do it
	#       before we release the database lock.
	push @$self, 'REFRESH' if $refresh;
	push @$self, 'BUSY'    if $busy;
	push @$self, 'UPDATE'  if $update;
	push @$self, 'CONFIG'  if $config;
	push @$self, 'DB'      if $db;

	return $self;
}

# Disable locking on destruction
sub DESTROY {
	my $locker = shift @{ $_[0] } or return;
	foreach ( @{ $_[0] } ) {
		if ( $_ ne uc $_ ) {
			$locker->method_decrement($_) if $locker->can('method_decrement');

		} elsif ( $_ eq 'REFRESH' ) {
			$locker->method_decrement;

		} elsif ( $_ eq 'BUSY' ) {
			$locker->busy_decrement if $locker->can('busy_decrement');

		} elsif ( $_ eq 'UPDATE' ) {
			$locker->update_decrement if $locker->can('update_decrement');

		} elsif ( $_ eq 'DB' ) {
			$locker->db_decrement if $locker->can('db_decrement');

		} elsif ( $_ eq 'CONFIG' ) {
			$locker->config_decrement;
		}
	}
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

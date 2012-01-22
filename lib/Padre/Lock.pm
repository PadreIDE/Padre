package Padre::Lock;

use 5.008;
use strict;
use warnings;
use Carp ();

our $VERSION = '0.94';

sub new {
	my $class  = shift;
	my $locker = shift;
	my $self   = bless [$locker], $class;

	# Enable the locks
	my $db     = 0;
	my $aui    = 0;
	my $config = 0;
	my $busy   = 0;
	my $update = 0;
	foreach (@_) {
		if ( $_ ne uc $_ ) {
			$locker->method_increment($_);
			push @$self, 'method_decrement';

		} elsif ( $_ eq 'CONFIG' ) {

			# Have CONFIG take an implicit DB lock as well so
			# that any writes for DB locks opened while the CONFIG
			# lock is open are aggregated into a single commit with
			# DB writes from a config unlock.
			$locker->config_increment unless $config;
			$locker->db_increment     unless $db;
			$config = 1;
			$db     = 1;

		} elsif ( $_ eq 'UPDATE' ) {
			$locker->update_increment unless $update;
			$update = 1;

		} elsif ( $_ eq 'REFRESH' ) {
			$locker->method_increment;
			push @$self, 'method_decrement';

		} elsif ( $_ eq 'DB' ) {
			$locker->db_increment unless $db;
			$db = 1;

		} elsif ( $_ eq 'AUI' ) {
			$locker->aui_increment unless $aui;
			$aui = 1;

		} elsif ( $_ eq 'BUSY' ) {
			$locker->busy_increment unless $busy;
			$busy = 1;

		} else {
			Carp::croak("Unknown or unsupported special lock '$_'");
		}
	}

	# Regardless of which order we were given the locks, the unlocking
	# definitely has to be done in a specific order.
	#
	# Putting DB last means that actions involving a database commit
	# will APPEAR to happen faster. However, this could be somewhat
	# disconcerting for long commits, because there will be user input
	# lag immediately after it appears to be "complete". If this
	# becomes a problem, move the DB to first so actions appear to be
	# slower, but the UI is immediately available once updated.
	#
	# Because configuration involves a database write, we always do it
	# before we release the database lock.
	push @$self, 'busy_decrement'   if $busy;
	push @$self, 'aui_decrement'    if $aui;
	push @$self, 'update_decrement' if $update;
	push @$self, 'db_decrement'     if $db;
	push @$self, 'config_decrement' if $config;

	return $self;
}

# Disable locking on destruction
sub DESTROY {
	my $locker = shift @{ $_[0] } or return;
	foreach ( @{ $_[0] } ) {

		# NOTE: DO NOT CONVERT TO A GREP.
		#       Depending on what happens in the method call, this
		#       destroy handler may need to behave reentrantly.
		$locker->$_() if $locker->can($_);
	}
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

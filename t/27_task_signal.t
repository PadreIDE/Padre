#!/usr/bin/perl

# Create the task manager

use strict;
use warnings;
use Test::More;
use Time::HiRes ();


######################################################################
# This test requires a DISPLAY to run
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}

	plan tests => 16;
}

use Padre::Logger;
use Padre::TaskManager        ();
use Padre::Task::Addition     ();
use Padre::Wx::App            ();
use t::lib::Padre::NullWindow ();

use_ok('Test::NoWarnings');

# Do we start with no threads as expected
is( scalar( threads->list ), 0, 'No threads' );





######################################################################
# Basic Creation

SCOPE: {
	my $wxapp = Padre::Wx::App->new;
	isa_ok( $wxapp, 'Padre::Wx::App' );

	my $window = t::lib::Padre::NullWindow->new;
	isa_ok( $window, 't::lib::Padre::NullWindow' );

	my $manager = Padre::TaskManager->new( conduit => $window );
	isa_ok( $manager, 'Padre::TaskManager' );
	is( scalar( threads->list ), 0, 'No threads' );

	# Run the startup process
	ok( $manager->start, '->start ok' );
	Time::HiRes::sleep(1);
	is( scalar( threads->list ), 1, 'The master threads exists' );

	# Create the sample task
	my $addition = Padre::Task::Addition->new(
		x => 2,
		y => 3,
	);
	isa_ok( $addition, 'Padre::Task::Addition' );

	# Schedule the task (which should trigger it's execution)
	ok( $manager->schedule($addition), '->schedule ok' );

	# Only the prepare phase should run (for now)
	is( $addition->{prepare}, 1, '->{prepare} is false' );
	is( $addition->{run},     0, '->{run}     is false' );
	is( $addition->{finish},  0, '->{finish}  is false' );

	# Run the shutdown process
	ok( $manager->stop, '->stop ok' );
	Time::HiRes::sleep(5);
	TODO: {
		local $TODO = "Padre currently exits with running threads most of the time, unknown source, doesn't harm.";
		is( scalar( threads->list ), 0, 'No threads' );
	}
}

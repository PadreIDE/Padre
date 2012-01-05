#!/usr/bin/perl

# Tests for Padre::Task::FindInFiles

use strict;
use warnings;
use Test::More tests => 7;
use Test::NoWarnings;
use File::Spec ();
use t::lib::Padre;
use Padre::MIME ();
use Padre::Project::Perl ();
use Padre::Search ();
use Padre::Task::FindInFiles ();





######################################################################
# Mainly check support for MIME filtering in Padre::Task::FindInFiles

SCOPE: {
	my $output = [ ];
	my $task   = Padre::Task::FindInFiles->new(
		project => Padre::Project::Perl->new(
			root     => File::Spec->curdir,
			explicit => 1,
		),
		mime    => 'application/x-perl',
		maxsize => 1000000,
		search  => Padre::Search->new(
			find_term => 'Foo',
			find_case => 1,
		),
		output  => $output,
	);
	isa_ok( $task, 'Padre::Task::FindInFiles' );

	# Execute the task in the foreground
	ok( scalar( $task->prepare ), '->prepare ok' );
	ok( scalar( $task->run     ), '->run ok'     );
	ok( scalar( $task->finish  ), '->finish ok'  );

	# Between 10 and 30 Perl files (20 at time of writing) contain
	# the term Foo. You may need to adjust these numbers later.
	my $results = scalar @$output;
	ok( $results > 10, 'Found more than 10 files with Foo in it' );
	ok( $results < 30, 'Found less than 30 files with Foo in it' );
}

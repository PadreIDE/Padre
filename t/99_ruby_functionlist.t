#!/usr/bin/perl

# Tests the logic for extracting the list of functions in a Ruby program

use strict;
use warnings;
use Test::More;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 9 );
}

use t::lib::Padre;
use Padre::Document::Ruby::FunctionList ();

# Sample code we will be parsing
my $code = <<'END_RUBY';
=begin
def bogus(a, b):
=end
def initialize:
     return

def subtract(a, b):
     return a - b

def add(a, b):
     return a + b

def _private:
     return
END_RUBY

######################################################################
# Basic Parsing

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::Ruby::FunctionList',
		[ text => $code ]
	);

	# Executing the parsing job
	ok( $task->run, '->run ok' );

	# Check the result of the parsing
	is_deeply(
		$task->{list},
		[   qw{
				initialize
				subtract
				add
				_private
				}
		],
		'Found expected functions',
	);
}





######################################################################
# Alphabetical Ordering

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::Ruby::FunctionList',
		[   text  => $code,
			order => 'alphabetical',
		]
	);

	# Executing the parsing job
	ok( $task->run, '->run ok' );

	# Check the result of the parsing
	is_deeply(
		$task->{list},
		[   qw{
				add
				initialize
				_private
				subtract
				}
		],
		'Found expected functions (alphabetical)',
	);
}





######################################################################
# Alphabetical Ordering (Private Last)

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::Ruby::FunctionList',
		[   text  => $code,
			order => 'alphabetical_private_last',
		]
	);

	# Executing the parsing job
	ok( $task->run, '->run ok' );

	# Check the result of the parsing
	is_deeply(
		$task->{list},
		[   qw{
				add
				initialize
				subtract
				_private
				}
		],
		'Found expected functions (alphabetical_private_last)',
	);
}

#!/usr/bin/perl

# Tests the logic for extracting the list of functions in a Python program

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
use Padre::Document::Python::FunctionList ();

# Sample code we will be parsing
my $code = <<'END_PYTHON';
"""
def bogus(a, b):
"""
def __init__:
     return

def subtract(a, b):
     return a - b

def add(a, b):
     return a + b

g = lambda x: x**2
END_PYTHON

######################################################################
# Basic Parsing

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::Python::FunctionList',
		[ text => $code ]
	);

	# Executing the parsing job
	ok( $task->run, '->run ok' );

	# Check the result of the parsing
	is_deeply(
		$task->{list},
		[   qw{
				__init__
				subtract
				add
				g
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
		'Padre::Document::Python::FunctionList',
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
				g
				__init__
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
		'Padre::Document::Python::FunctionList',
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
				g
				subtract
				__init__
				}
		],
		'Found expected functions (alphabetical_private_last)',
	);
}

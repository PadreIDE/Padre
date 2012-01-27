#!/usr/bin/perl

# Tests the logic for extracting the list of functions in a program

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
use Padre::Document::Perl::FunctionList ();

# Sample code we will be parsing
my $code = <<'END_PERL';
package Foo;
sub _bar { }
sub foo1 {}
sub foo3 { }
sub foo2{}
sub  foo4 {
}
sub foo5 :tag {
}
*backwards = sub { };
*_backwards = \&backwards;
END_PERL





######################################################################
# Basic Parsing

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::Perl::FunctionList',
		[   text => $code,
		]
	);

	# Executing the parsing job
	ok( $task->run, '->run ok' );

	# Check the result of the parsing
	is_deeply(
		$task->{list},
		[   qw{
				_bar
				foo1
				foo3
				foo2
				foo4
				foo5
				backwards
				_backwards
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
		'Padre::Document::Perl::FunctionList',
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
				backwards
				_backwards
				_bar
				foo1
				foo2
				foo3
				foo4
				foo5
				}
		],
		'Found expected functions',
	);
}





######################################################################
# Alphabetical Ordering (Private Last)

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::Perl::FunctionList',
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
				backwards
				foo1
				foo2
				foo3
				foo4
				foo5
				_backwards
				_bar
				}
		],
		'Found expected functions',
	);
}

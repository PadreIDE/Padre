#!/usr/bin/perl

# Tests the logic for extracting the list of functions in a C# program

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
use Padre::Document::CSharp::FunctionList ();

# Sample code we will be parsing
my $code = <<'END_CS';
/**
public static void Bogus(a, b)
{
}
*/
//public static void Bogus(a, b) { }

public static void Main(string[] args)
{
}

///
protected override void Init()
// ticket #1351

public abstract void MyAbstractMethod();

public byte[] ToByteArray();

public static T StaticGenericMethod<T>(arguments);

public sealed List<int>[] GenericArrayReturnType();

public virtual string[,] TwoDimArrayReturnType();

public abstract List<int> GetList();

private int Subtract(int a, int b)
{
	return a - b;
}

private int Add(int a, int b)
{
	return a + b;
}

[Test()] public void TestMethod() { }
END_CS

######################################################################
# Basic Parsing

SCOPE: {

	# Create the function list parser
	my $task = new_ok(
		'Padre::Document::CSharp::FunctionList',
		[ text => $code ]
	);

	# Executing the parsing job
	ok( $task->run, '->run ok' );

	# Check the result of the parsing
	is_deeply(
		$task->{list},
		[   qw{
				Main
				MyAbstractMethod
				ToByteArray
				StaticGenericMethod
				GenericArrayReturnType
				TwoDimArrayReturnType
				GetList
				Subtract
				Add
				TestMethod
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
		'Padre::Document::CSharp::FunctionList',
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
				Add
				GenericArrayReturnType
				GetList
				Main
				MyAbstractMethod
				StaticGenericMethod
				Subtract
				TestMethod
				ToByteArray
				TwoDimArrayReturnType
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
		'Padre::Document::CSharp::FunctionList',
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
				Add
				GenericArrayReturnType
				GetList
				Main
				MyAbstractMethod
				StaticGenericMethod
				Subtract
				TestMethod
				ToByteArray
				TwoDimArrayReturnType
				}
		],
		'Found expected functions (alphabetical_private_last)',
	);
}

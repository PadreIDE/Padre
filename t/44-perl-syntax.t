#!/usr/bin/perl

# Checks that errors and warnings emitted by the Perl syntax highlighting
# task have the correct line numbers.

use strict;
use warnings;
use Test::More; # tests => 55;

BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
	plan( tests => 55 );
}

use t::lib::Padre;
use Storable                      ();
use File::HomeDir                 ();
use Padre::Document::Perl::Syntax ();





######################################################################
# Trivial Tests

# Check the null case
my $null = execute('');
isa_ok( $null, 'Padre::Task::Syntax' );
is_deeply( $null->{model}, [], 'Null syntax returns null model' );

# A simple, correct, one line script
my $hello = execute( <<'END_PERL' );
#!/usr/bin/perl

print "Hello World!\n";
END_PERL
is_deeply( $null->{model}, [], 'Trivial script returns null model' );

# A simple, correct, one line package
my $package = execute( <<'END_PERL' );
package Foo;
END_PERL
is_deeply( $null->{model}, [], 'Trivial module returns null model' );





######################################################################
# Trivially broken three line script

SCOPE: {
	my $script = execute( <<'END_PERL' );
#!/usr/bin/perl

print(
END_PERL
	is_deeply(
		$script->{model},
		[   {   line     => 3,
				msg      => 'syntax error, at EOF',
				severity => 0,
			},
		],
		'Trivially broken three line script',
	);
}





######################################################################
# Trivially broken package statement, and variants

SCOPE: {
	my $module = execute('package');
	is_deeply(
		$module->{model},
		[   {   line     => 1,
				msg      => 'syntax error, at EOF',
				severity => 0,
			},
		],
		'Trivially broken package statement',
	);
}

SCOPE: {
	my $module = execute("package;\n");
	is_deeply(
		$module->{model},
		[   {   line     => 1,
				msg      => 'syntax error, near "package;"',
				severity => 0,
			},
		],
		'Trivially broken package statement',
	);
}





######################################################################
# Nth line error in package, and variants

SCOPE: {
	my $module = execute( <<'END_PERL' );
package Foo;

print(

END_PERL
	is_deeply(
		$module->{model},
		[   {   line     => 3,
				msg      => 'syntax error, at EOF',
				severity => 0,
			},
		],
		'Error at the nth line of a module',
	);
}

# With explicit windows newlines
my $win32 = "package Foo;\cM\cJ\cM\cJprint(\cM\cJ\cM\cJ";
SCOPE: {
	my $module = execute($win32);
	is_deeply(
		$module->{model},
		[   {   line     => 3,
				msg      => 'syntax error, at EOF',
				severity => 0,
			},
		],
		'Error at the nth line of a module',
	);
}

# UTF8 upgraded with windows newlines
SCOPE: {
	use utf8;
	utf8::upgrade($win32);
	my $module = execute($win32);
	is_deeply(
		$module->{model},
		[   {   line     => 3,
				msg      => 'syntax error, at EOF',
				severity => 0,
			},
		],
		'Error at the nth line of a module',
	);
	no utf8;
}





######################################################################
# Support Functions

sub execute {

	# Create a Padre document for the code
	my $document = Padre::Document::Perl::Fake->new(
		text => $_[0],
	);
	isa_ok( $document, 'Padre::Document::Perl' );

	# Create the task
	my $task = Padre::Document::Perl::Syntax->new(
		document => $document,
	);
	isa_ok( $task, 'Padre::Document::Perl::Syntax' );
	ok( $task->prepare, '->prepare ok' );

	# Push through storable to emulate being sent to a worker thread
	$task = Storable::dclone($task);

	ok( $task->run, '->run ok' );

	# Clone again to emulate going back
	$task = Storable::dclone($task);

	ok( $task->finish, '->finish ok' );

	return $task;
}

CLASS: {

	package Padre::Document::Perl::Fake;

	use strict;
	use base 'Padre::Document::Perl';

	sub new {
		my $class = shift;
		my $self = bless {@_}, $class;
		return $self;
	}

	sub text_get {
		$_[0]->{text};
	}

	sub project_dir {
		File::HomeDir->my_documents;
	}

	sub filename {
		return undef;
	}

	1;
}

#!/usr/bin/perl

use strict;
use warnings;

# Create test environment...
package local::t75;

sub LineFromPosition {
	return 0;
}

package Wx;

sub gettext {
	return $_[0];
}

package Padre;

sub ide {
	return bless {}, __PACKAGE__;
}

sub config {
	return $_[0];
}

sub lang_perl5_beginner_chomp { 1; }

sub lang_perl5_beginner_close { 1; }

sub lang_perl5_beginner_debugger { 1; }

sub lang_perl5_beginner_elseif { 1; }

sub lang_perl5_beginner_ifsetvar { 1; }

sub lang_perl5_beginner_map { 1; }

sub lang_perl5_beginner_map2 { 1; }

sub lang_perl5_beginner_perl6 { 1; }

sub lang_perl5_beginner_pipe2open { 1; }

sub lang_perl5_beginner_pipeopen { 1; }

sub lang_perl5_beginner_regexq { 1; }

sub lang_perl5_beginner_split { 1; }

sub lang_perl5_beginner_warning { 1; }

# The real test...
package main;

use Test::More;

#use Test::NoWarnings;
use File::Spec ();

# Don't run tests for installs
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
}

# enable NoWarning if this is fixed

my %TEST = (
	'split1.pl'                 => "Line 6: The second parameter of split is a string, not an array",
	'split2.pl'                 => "Line 6: The second parameter of split is a string, not an array",
	'warning.pl'                => "Line 3: You need to write use warnings (with an s at the end) and not use warning.",
	'boolean_expressions_or.pl' => 'TODO',
	'boolean_expressions_pipes.pl' => 'TODO',
	'match_default_scalar.pl'      => 'TODO',
	'chomp.pl'                     => 'TODO',
	'substitute_in_map.pl'         => 'TODO',
	'unintented_glob.pl'           => 'TODO',
	'return_stronger_than_or.pl'   => 'TODO',
	'grep_always_true.pl'          => 'TODO',
	'my_argv.pl'                   => 'TODO', # "my" variable @ARGV masks global variable at ...
	'else_if.pl'    => "Line 9: 'else if' is wrong syntax, correct if 'elsif'.",
	'elseif.pl'     => "Line 9: 'elseif' is wrong syntax, correct if 'elsif'.",
	'SearchTask.pm' => undef,

	# @ARGV, $ARGV, @INC, %INC, %ENV, %SIG, @ISA,
	# other special variables ? $a, $b, $ARGV, $AUTOLOAD, etc ? $_ in perls older than 5.10?
	# @_ ?
);

plan( tests => scalar( keys %TEST ) * 2 + 20 );

use Padre::Document::Perl::Beginner;
my $b = Padre::Document::Perl::Beginner->new( document => { editor => bless {}, 'local::t75' } );

isa_ok $b, 'Padre::Document::Perl::Beginner';


# probably already in some Perl Critic rules
# lack of use strict; and lack of use warnings; should be also reported.

# this might be also in some Perl Critic rules
#my $filename = 'input.txt';
#open my $fh, '<', $filename || die $!;
# problem: precedence of || is higher than that of , so the above code is actually
# the same as:
# open my $fh, '<', ($filename || die $!);
# which will only die if the $filename is false, nothing to do with
# success of failure of open()


# without "use warning" this 'works' noiselessly
# I am not sure we need to look for such as we should always
# tell users to 'use warnings'
#my $x = 23;
#my $z = 3;
#if ($x = 7) {
#	print "xx\n";
#}
#

foreach my $file ( keys %TEST ) {
	if ( defined $TEST{$file} and $TEST{$file} eq 'TODO' ) {
		TODO: {
			local $TODO = "$file not yet implemented";
			ok(0);
			ok(0);
		}
		next;
	}

	my $data = slurp( File::Spec->catfile( 't', 'files', 'beginner', $file ) );
	my $result = $b->check($data);
	if ( defined $TEST{$file} ) {
		is( $result, undef, $file ) or diag "Result: '$result'";
	} else {
		is( $result, 1, $file );
	}
	is( $b->error, $TEST{$file}, "$file error" );
}

# No need to create files for all of these:
# Notice: Text matches are critical as texts may change without notice!
$b->check("=pod\n\nThis is a typical POD test with bad stuff.\npackage DB; if (\$x=1) {}\n\n\=cut\n");
ok( !defined( $b->error ), 'No check of POD stuff' );

$b->check('join(",",map { 1; } (@INC),"a");');
is( $b->error, q(Line 1: map (),x uses x also as list value for map.), 'map arguments' );

$b->check('package DB;');
is( $b->error, q(Line 1: This file uses the DB-namespace which is used by the Perl Debugger.),
	'kill Perl debugger (1)'
);

$b->check('package DB::Connect;');
is( $b->error, q(Line 1: This file uses the DB-namespace which is used by the Perl Debugger.),
	'kill Perl debugger (2)'
);

$b->check('$X = chomp($ARGV[0]);');
is( $b->error, q(Line 1: chomp doesn't return the chomped value, it modifies the variable given as argument.),
	'chomp return value'
);

$b->check('join(",",map { s/\//\,/g; } (@INC),"a");');
is( $b->error, q(Line 1: map (),x uses x also as list value for map.), 'substitution in map (1)' );

$b->check('join(",",map { $_ =~ s/\//\,/g; } (@INC),"a");');
is( $b->error, q(Line 1: map (),x uses x also as list value for map.), 'substitution in map (2)' );

$b->check('for (<@INC>) { 1; }');
is( $b->error, q(Line 1: (<@Foo>) is Perl6 syntax and usually not valid in Perl5.), 'Perl6 loop syntax in Perl5' );

$b->check('if ($_ = 1) { 1; }');
is( $b->error, q(Line 1: A single = in a if-condition is usually a typo, use == or eq to compare.),
	'assign instead of compare'
);

$b->check('open file,"free|tail"');
is( $b->error, q(Line 1: Using a | char in open without a | at the beginning or end is usually a typo.),
	'pipe-open without in or out redirection (2 args)'
);

$b->check('open file,">","free|tail"');
is( $b->error, q(Line 1: Using a | char in open without a | at the beginning or end is usually a typo.),
	'pipe-open3 without in or out redirection (3 args)'
);

$b->check('open file,"|cat|"');
is( $b->error, q(Line 1: You can't use open to pipe to and from a command at the same time.),
	'pipe-open with in and out redirection (2 args)'
);

$b->check('open file,"|cat|"');
is( $b->error, q(Line 1: You can't use open to pipe to and from a command at the same time.),
	'pipe-open with in and out redirection (3 args)'
);

# Thanks to meironC for this sample:
$b->check('open LYNX, "lynx -source http://www.perl.com |" or die " Cant open lynx: $!";');
ok( !$b->error, 'Open with pipe and result check' );

$b->check('elseif');
is( $b->error, q(Line 1: 'elseif' is wrong syntax, correct if 'elsif'.), 'elseif - typo' );

$b->check('$x=~/+/');
is( $b->error,
	q(Line 1: A regular expression starting with a quantifier ( + * ? { ) doesn't make sense, you may want to escape it with a \.),
	'RegExp with quantifier (1)'
);

$b->check('$x =~ /*/');
is( $b->error,
	q(Line 1: A regular expression starting with a quantifier ( + * ? { ) doesn't make sense, you may want to escape it with a \.),
	'RegExp with quantifier (2)'
);

$b->check('close; ');
is( $b->error, q(Line 1: close; usually closes STDIN, STDOUT or something else you don't want.), 'close;' );

$b->check("\nclose; ");
is( $b->error, q(Line 2: close; usually closes STDIN, STDOUT or something else you don't want.), 'close;' );

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

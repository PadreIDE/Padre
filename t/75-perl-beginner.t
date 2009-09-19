#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::NoWarnings;
use Data::Dumper qw(Dumper);
use File::Spec ();

my %TEST = (
	'split1.pl'                    => "The second parameter of split is a string, not an array",
	'split2.pl'                    => "The second parameter of split is a string, not an array",
	'warning.pl'                   => "You need to write use warnings (with an s at the end) and not use warning.",
	'boolean_expressions_or.pl'    => 'TODO',
	'boolean_expressions_pipes.pl' => 'TODO',
	'match_default_scalar.pl'      => 'TODO',
	'chomp.pl'                     => 'TODO',
	'substitute_in_map.pl'         => 'TODO',
	'unintented_glob.pl'           => 'TODO',
	'return_stronger_than_or.pl'   => 'TODO',
	'grep_always_true.pl'          => 'TODO',
	'my_argv.pl' => 'TODO',                                          # "my" variable @ARGV masks global variable at ...
	'else_if.pl' => "'else if' is wrong syntax, correct if 'elsif'.",

	# @ARGV, $ARGV, @INC, %INC, %ENV, %SIG, @ISA,
	# other special variables ? $a, $b, $ARGV, $AUTOLOAD, etc ? $_ in perls older than 5.10?
	# @_ ?
);

plan( tests => scalar( keys %TEST ) * 2 + 15 );

use Padre::Document::Perl::Beginner;
my $b = Padre::Document::Perl::Beginner->new;

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
	if ( $TEST{$file} eq 'TODO' ) {
		TODO: {
			local $TODO = "$file not yet implemented";
			ok(0);
			ok(0);
		}
		next;
	}

	my $data = slurp( File::Spec->catfile( 't', 'files', 'beginner', $file ) );
	ok( !defined( $b->check($data) ), $file );
	is( $b->error, $TEST{$file}, "$file error" );
}

# No need to create files for all of these:
# Notice: Text matches are critical as texts may change without notice!
$b->check('join(",",map { 1; } (@INC),"a");');
ok( $b->error =~ /map/, 'map arguments' );

$b->check('package DB;');
ok( $b->error =~ /DB/, 'kill Perl debugger (1)' );

$b->check('package DB::Connect;');
ok( $b->error =~ /DB/, 'kill Perl debugger (2)' );

$b->check('$X = chomp($ARGV[0]);');
ok( $b->error =~ /chomp/, 'chomp return value' );

$b->check('join(",",map { s/\//\,/g; } (@INC),"a");');
ok( $b->error =~ /map/, 'substitution in map (1)' );

$b->check('join(",",map { $_ =~ s/\//\,/g; } (@INC),"a");');
ok( $b->error =~ /map/, 'substitution in map (2)' );

$b->check('for (<@INC>) { 1; }');
ok( $b->error =~ /Perl6/, 'Perl6 loop syntax in Perl5' );

$b->check('if ($_ = 1) { 1; }');
ok( $b->error =~ /\=/, 'assign instead of compare' );

$b->check('open file,"free|tail"');
ok( $b->error =~ /open/, 'pipe-open without in or out redirection (2 args)' );

$b->check('open file,">","free|tail"');
ok( $b->error =~ /open/, 'pipe-open3 without in or out redirection (3 args)' );

$b->check('open file,"|cat|"');
ok( $b->error =~ /open/, 'pipe-open with in and out redirection (2 args)' );

$b->check('open file,"|cat|"');
ok( $b->error =~ /open/, 'pipe-open with in and out redirection (3 args)' );

$b->check('elseif');
ok( $b->error =~ /elseif.*elsif/, 'elseif - typo' );

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

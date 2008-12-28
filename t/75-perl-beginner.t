#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::NoWarnings;
use Data::Dumper qw(Dumper);
use File::Spec   ();

my $tests;
plan tests => $tests+1;

use Padre::Document::Perl::Beginner;
my $b = Padre::Document::Perl::Beginner->new;

isa_ok $b, 'Padre::Document::Perl::Beginner';
BEGIN { $tests += 1; }

SCOPE: {
	my $data = slurp (File::Spec->catfile('t', 'files', 'beginner', 'split1.pl'));
	ok(! defined($b->check($data)), 'split1.pl');
	is($b->error, "The second parameter of split is a string, not an array", "split1.pl error");
	BEGIN { $tests += 2; }
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}
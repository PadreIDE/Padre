#!/usr/bin/perl

use strict;
use warnings;
use File::Find::Rule;

# Create test environment...
package local::t14;

sub LineFromPosition {
	return 0;
}

package Wx;

sub gettext {
	return $_[0];
}

# The real test...
package main;

use Test::More;
use Test::NoWarnings;

use Padre::Document::Perl::Beginner;
my $b = Padre::Document::Perl::Beginner->new( document => { editor => bless {}, 'local::t14' } );

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');

plan( tests => @files + 2 );

isa_ok $b, 'Padre::Document::Perl::Beginner';

foreach my $file (@files) {
 $b->check(slurp('lib/'.$file));
 my $result = $b->error || '';
 ok(($result eq ''),'Check '.$file.': '.$result);
}

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

#!/usr/bin/perl

use strict;
use warnings;
use File::Find::Rule;
use Test::More;
use Test::NoWarnings;
use Padre::Document::Perl::Beginner;

package Padre;

# Fake the Padre instance, P::D::P::Beginner only needs Padre->ide->config
use Padre::Config();
my $SINGLETON = undef;

sub ide {
	my $class = shift;
	return $SINGLETON if $SINGLETON;
	$SINGLETON = bless {}, $class;
	$SINGLETON->{config} = Padre::Config->read;
	return $SINGLETON;
}

sub config {
	my $self = shift;
	return $self->{config};
}

package main;

our $SKIP;

unless ( $ENV{AUTOMATED_TESTING} ) {
	$SKIP = "Only test this on developer versions.";
	plan( tests => 2 );
	ok( 1, 'Skip nice-syntax tests on released versions' );
	exit;
}

# Create to beginner error check object
my $b = Padre::Document::Perl::Beginner->new( document => { editor => bless {}, 'local::t14' } );

my %skip_files = (
	'Padre/Document/Perl/Beginner.pm' => 'Beginner error checks contain bad samples',

	#TODO cpanm sets AUTOMATED_TESTING and these files are bad :)
	'Padre/Document.pm'                 => 'PHP language keywords',
	'Padre/Wx/Constant.pm'              => 'Bad substitution',
	'Padre/Wx/Theme.pm'                 => 'Bad substitution',
	'Padre/Wx/Dialog/Patch.pm'          => 'equals in an if',
);

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');

plan( tests => @files + 2 );

isa_ok $b, 'Padre::Document::Perl::Beginner';

foreach my $file (@files) {
	if ( defined( $skip_files{$file} ) ) {
		local $SKIP = $skip_files{$file};
		ok( 1, 'Check ' . $file );
		next;
	}

	$b->check( slurp( 'lib/' . $file ) );
	my $result = $b->error || '';
	is( $result, '', "Check $file" );
}





######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die "Couldn't open $file: $!";
	local $/ = undef;
	my $buffer = <$fh>;
	close $fh;
	return $buffer;
}





######################################################################
# Support Classes

# Create test environment...
# Test replacement for document object
SCOPE: {

	package local::t14;

	sub LineFromPosition {
		return 0;
	}
}

# Test replacement for Wx
SCOPE: {

	package Wx;

	sub gettext {
		return $_[0];
	}
}

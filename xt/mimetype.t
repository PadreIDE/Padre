#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN {

	# Don't run tests for installs
	unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
		plan( skip_all => "Author tests not required for installation" );
	}

	# check if we has a DISPLAY set
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}


}

use File::Find::Rule;

my %test_texts = (
	".class { border: 1px solid; } a { text-decoration: none; }"              => 'text/css',
	'[% PROCESS Padre %]'                                                     => 'text/x-perltt',
	'#!/bin/bash'                                                             => 'application/x-shellscript',
	'<html><head><title>Padre</title></head></html>'                          => 'text/html',
	'use strict; sub foo { 1; } my $self = split(/y/,$ENV{foo}));'            => 'application/x-perl',
	"function lua_fct()\n\t--[[This\n\tis\n\ta\ncomment\n\t]]--repeat\nend\n" => 'text/x-lua',
);

my %test_files = (
	'foo.pl'     => 'application/x-perl',
	'bar.p6'     => 'application/x-perl6',
	'style.css'  => 'text/css',
	'index.tt'   => 'text/x-perltt',
	'main.c'     => 'text/x-csrc',
	'oop.cpp'    => 'text/x-c++src',
	'patch.diff' => 'text/x-patch',
	'index.html' => 'text/html',
	'index.htm'  => 'text/html',
	'script.js'  => 'application/javascript',
	'config.php' => 'application/x-php',
	'form.rb'    => 'application/x-ruby',
	'foo.bar'    => 'text/plain',
);

my %existing_test_files = (
	'broken.bin'                     => undef,               # regression test for ticket #900
	'rename_variable_stress_test.pl' => 'application/x-perl',
);

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');
my $tests = 2 * @files
	+ scalar( keys %test_texts ) 
	+ scalar( keys %test_files )
	+ scalar( keys %existing_test_files )
	+ 1;

plan( tests => $tests );

use_ok('Padre::MIME');

# Fake installed Perl6 plugin
Padre::MIME->find('application/x-perl6')->plugin(__PACKAGE__);

# All Padre modules should be Perl files and Padre should be able to detect his own files
foreach my $file (@files) {
	$file = "lib/$file";
	my $text = slurp($file);
	is(
		Padre::MIME->detect(
			text => $text,
			file => $file,
		),
		'application/x-perl',
		"$file with filename",
	);
	is(
		Padre::MIME->detect(
			text => $text,
		),
		'application/x-perl',
		"$file without filename",
	);
}

# Some fixed test texts
foreach my $text ( sort( keys(%test_texts) ) ) {
	is(
		Padre::MIME->detect(
			text => $text,
		),
		$test_texts{$text},
		$test_texts{$text},
	);
}

# Some fixed test filenames
foreach my $file ( sort keys %test_files ) {
	is(
		Padre::MIME->detect(
			file => $file,
		),
		$test_files{$file},
		$file,
	);
}

# Some files that actually exist on-disk
foreach my $file ( sort keys %existing_test_files ) {
	my $text = slurp("xt/files/$file");
	require Padre::Locale;
	my $encoding = Padre::Locale::encoding_from_string($text);

	SCOPE: {
		local $SIG{__WARN__} = sub { };
		$text = Encode::decode( $encoding, $text );
	}

	is(
		Padre::MIME->detect(
			text => $text,
		),
		$existing_test_files{$file},
		"$file without filename",
	);
}





######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $! . ' for ' . $file;
	local $/ = undef;
	my $buffer = <$fh>;
	close $fh;
	return $buffer;
}

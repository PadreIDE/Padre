#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Find::Rule;

my %test_texts = (
	".class { border: 1px solid; } a { text-decoration: none; }"	=> 'text/css',
	'[% PROCESS Padre %]' => 'text/x-perltt',
	'#!/bin/bash' => 'application/x-shellscript',
	'<html><head><title>Padre</title></head></html>' => 'text/html',
	'=begin pod' => 'application/x-perl6',
	'use v6;' => 'application/x-perl6',
	'use strict; sub foo { 1; } my $self = split(/y/,$ENV{foo}));' => 'application/x-perl',
	"function lua_fct()\n\t--[[This\n\tis\n\ta\ncomment\n\t]]--repeat\nend\n" => 'text/x-lua',
		);

my %test_files = (
	'foo.pl' => 'application/x-perl',
	'bar.p6' => 'application/x-perl6',
	'style.css' => 'text/css',
	'index.tt' => 'text/x-perltt',
	'main.c' => 'text/x-c',
	'oop.cpp' => 'text/x-c++src',
	'patch.diff' => 'text/x-patch',
	'index.html' => 'text/html',
	'index.htm' => 'text/html',
	'script.js' => 'application/javascript',
	'config.php' => 'application/x-php',
	'form.rb' => 'application/x-ruby',
	'foo.bar' => 'text/plain',
);

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');

plan( tests =>  (2 * @files) + 1 + scalar(keys(%test_texts))+ scalar(keys(%test_files)) );

use_ok('Padre::MimeTypes');

# Fake installed Perl6 plugin
Padre::MimeTypes->add_mime_class('application/x-perl6',__PACKAGE__);

# All Padre modules should be Perl files and Padre should be able to detect his own files
foreach my $file (@files) {

	$file = "lib/$file";

	my $text = slurp($file);

	is(Padre::MimeTypes->guess_mimetype($text,$file),'application/x-perl',$file.' with filename');
	is(Padre::MimeTypes->guess_mimetype($text,''),'application/x-perl',$file.' without filename');
}

# Some fixed test texts
foreach my $text (sort(keys(%test_texts))) {
	is(Padre::MimeTypes->guess_mimetype($text,''),$test_texts{$text},$test_texts{$text});
}

# Some fixed test filenames
foreach my $file (sort(keys(%test_files))) {
	is(Padre::MimeTypes->guess_mimetype('',$file),$test_files{$file},$file);
}

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!.' for '.$file;
	local $/ = undef;
	my $buffer = <$fh>;
	close $fh;
	return $buffer;
}

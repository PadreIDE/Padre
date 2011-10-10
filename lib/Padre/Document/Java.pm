package Padre::Document::Java;

use 5.008;
use strict;
use warnings;
use Padre::Constant   ();
use Padre::Role::Task ();
use Padre::Document   ();

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Document
};


#####################################################################
# Padre::Document Task Integration

sub task_functions {
	return 'Padre::Document::Java::FunctionList';
}

sub task_outline {
	return undef;
}

sub task_syntax {
	return undef;
}

sub get_function_regex {
	my $name = quotemeta $_[1];

	#TODO fix Java function regex
	return qr/(?:^|[^# \t-])[ \t]*((?:def)\s+$name\b|\*$name\s*=\s*)/;
}

sub get_command {
	my $self    = shift;
	my $arg_ref = shift || {};
	my $config  = $self->current->config;

	# Use a temporary file if run_save is set to 'unsaved'
	my $filename =
		  $config->run_save eq 'unsaved' && !$self->is_saved
		? $self->store_in_tempfile
		: $self->filename;

	# Use console java
	require File::Which;
	my $java = File::Which::which('java')
		or die Wx::gettext("Cannot find ruby executable in your PATH");
	$java = qq{"$java"} if Padre::Constant::WIN32;

	my $dir = File::Basename::dirname($filename);
	chdir $dir;
	my $shortname = File::Basename::basename($filename);

	my @commands = (qq{$java});
	$shortname = qq{"$shortname"} if (Padre::Constant::WIN32);
	push @commands, qq{"$shortname"};

	return join ' ', @commands;
}

# Java keyword list is obtained from src/scite/src/cpp.properties
sub scintilla_key_words {
	return [
		[   qw{
				abstract assert boolean break byte case catch char class
				const continue default do double else enum extends final
				finally float for goto if implements import instanceof int
				interface long native new package private protected public
				return short static strictfp super switch synchronized this
				throw throws transient try var void volatile while
				}
		]
	];
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

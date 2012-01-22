package Padre::Document::Ruby;

use 5.008;
use strict;
use warnings;
use Padre::Constant   ();
use Padre::Role::Task ();
use Padre::Document   ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Document
};





#####################################################################
# Padre::Document Task Integration

sub task_functions {
	return 'Padre::Document::Ruby::FunctionList';
}

sub task_outline {
	return undef;
}

sub task_syntax {
	return undef;
}

sub get_function_regex {
	my $name = quotemeta $_[1];
	return qr/(?:^|[^# \t-])[ \t]*((?:def)\s+$name\b|\*$name\s*=\s*)/;
}

sub get_command {
	my $self    = shift;
	my $arg_ref = shift || {};
	my $config  = $self->config;

	# Use a temporary file if run_save is set to 'unsaved'
	my $filename =
		  $config->run_save eq 'unsaved' && !$self->is_saved
		? $self->store_in_tempfile
		: $self->filename;

	# Use console ruby
	require File::Which;
	my $ruby = File::Which::which('ruby') or 
		die Wx::gettext("Cannot find ruby executable in your PATH");
	$ruby = qq{"$ruby"} if Padre::Constant::WIN32;

	my $dir = File::Basename::dirname($filename);
	chdir $dir;
	my $shortname = File::Basename::basename($filename);

	my @commands = (qq{$ruby});
	$shortname = qq{"$shortname"} if (Padre::Constant::WIN32);
	push @commands, qq{"$shortname"};

	return join ' ', @commands;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

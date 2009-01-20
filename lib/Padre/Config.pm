package Padre::Config;

use 5.008;
use strict;
use warnings;
use Storable      ();
use File::Path    ();
use File::Spec    ();
use File::Copy    ();
use File::HomeDir ();
use Params::Util  qw{ _STRING _ARRAY };
use YAML::Tiny    ();

use Padre::Config::Clear ();

our $VERSION = '0.25';

my %defaults = (
	# Look and feel preferences
	main_lockinterface       => 1,
	main_functions           => 0,
	main_functions_order     => 'alphabetical',
	main_outline             => 0,
	main_output              => 0,
	main_output_ansi         => 1,
	main_syntaxcheck         => 0,
	main_errorlist           => 0,
	main_statusbar           => 1,

	# Editor features and indent settings
	editor_font              => undef,
	editor_linenumbers       => 1,
	editor_eol               => 0,
	editor_whitespace        => 0,
	editor_indentationguides => 0,
	editor_calltips          => 0,
	editor_autoindent        => 'deep',
	editor_folding           => 0,
	editor_wordwrap          => 0,
	editor_currentline       => 0,
	editor_currentline_color => 'FFFF04',
	editor_beginner          => 1,
	editor_indent_auto       => 1,
	editor_indent_tab        => 1,
	editor_indent_tab_width  => 8,
	editor_indent_width      => 8,
	ppi_highlight            => 0,
	ppi_highlight_limit      => 10_000,

	# Search settings
	find_case                => 1,
	find_regex               => 0,
	find_reverse             => 0,
	find_first               => 0,
	find_nohidden            => 1,
	find_quick               => 0,

	# startup mode, if no files given on the command line this can be
	#   new        - a new empty buffer
	#   nothing    - nothing to open
	#   last       - the files that were open last time
	main_startup             => 'new',

	# When running a script from the application some of the files might have not been saved yet.
	# There are several option what to do before running the script
	# none - don's save anything
	# same - save the file in the current buffer
	# all_files - all the files (but not buffers that have no filenames)
	# all_buffers - all the buffers even if they don't have a name yet
	run_save                 => 'same',
	run_stacktrace           => 0,

	# By default, use background threads unless profiling
	threads                  => 1,

	# What language should we work in
	locale                   => '',       
	locale_perldiag          => '',

	# By default, don't enable experimental features
	experimental             => 0,
);





#####################################################################
# Class-Level Functionality

my $DEFAULT_DIR = File::Spec->catfile( (
	$ENV{PADRE_HOME}
		? $ENV{PADRE_HOME}
		: File::HomeDir->my_data
	), '.padre',
);

sub default_dir {
	my $dir = $DEFAULT_DIR;
	unless ( -e $dir ) {
		mkdir $dir or
		die "Cannot create config dir '$dir' $!";
	}
	return $dir;
}

sub default_yaml {
	File::Spec->catfile(
		$_[0]->default_dir,
		'config.yml',
	);
}

sub default_db {
	File::Spec->catfile(
		$_[0]->default_dir,
		'config.db',
	);
}

sub default_plugin_dir {
	my $pluginsdir = File::Spec->catdir(
		$_[0]->default_dir,
		'plugins',
	);
	my $plugins_full_path = File::Spec->catdir(
		$pluginsdir, 'Padre', 'Plugin'
	);
	unless ( -e $plugins_full_path) {
		File::Path::mkpath($plugins_full_path) or
		die "Cannot create plugins dir '$plugins_full_path' $!";
	}

	# Copy the My Plugin if necessary
	my $file = File::Spec->catfile( $plugins_full_path, 'My.pm' );
	unless ( -e $file ) {
		Padre::Config->copy_original_My_plugin( $file );
	}
	return $pluginsdir;
}

sub copy_original_My_plugin {
	my $class  = shift;
	my $target = shift;
	my $src = File::Spec->catfile( File::Basename::dirname($INC{'Padre/Config.pm'}), 'Plugin', 'My.pm' );
	unless ( $src ) {
		die "Could not find the original My plugin";
	}
	unless ( File::Copy::copy($src, $target) ) {
		return die "Could not copy the My plugin ($src) to $target: $!";
	}
	chmod 0644, $target;

	return 1;
}





#####################################################################
# Constructor and Serialization

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Main window geometry
	$self->{host}->{main_height}    ||= 400;
	$self->{host}->{main_width}     ||= 600;
	$self->{host}->{main_left}      ||= 40;
	$self->{host}->{main_top}       ||= 20;
	$self->{host}->{main_maximized} ||= 0;

	# Files that were previously open (and can be still)
	unless ( exists $self->{host}->{main_file} ) {
		$self->{host}->{main_file} = undef;
	}
	unless ( _ARRAY($self->{host}->{main_files}) ) {
		$self->{host}->{main_files} = [];
	}
	unless ( _ARRAY($self->{host}->{main_files_pos}) ) {
		$self->{host}->{main_files_pos} = [];
	}
	$self->{host}->{main_files} = [
		grep { -f $_ and -r _ }
		@{ $self->{host}->{main_files} }
	];

	# Default the locale to the system locale
	$self->{host}->{editor_style} ||= 'default';

	%$self = (%defaults, %$self);

	# Forcefully disable syntax checking at startup.
	# Automatically compiling files provided on the command
	# line at start means executing arbitrary code, which is
	# a massive security violation.
	$self->{main_syntaxcheck} = 0;

	# Return a clear wrapper
	return Padre::Config::Clear->new( $self );
}

# Write a null config, then read it back in
sub create {
	my $class = shift;
	my $file  = shift;

	# Save a null configuration
	YAML::Tiny::DumpFile( $file, {} );

	# Now read it (and the host config) back in
	return $class->read( $file );
}

sub read {
	my $class = shift;

	# Check the file
	my $file = shift;
	unless ( defined $file and -f $file and -r $file ) {
		return;
	}

	# Load the user configuration
	my $hash = YAML::Tiny::LoadFile($file);
	return unless ref($hash) eq 'HASH';

	# Load the host configuration
	my $host = Padre::DB::Hostconf->read;
	return unless ref($hash) eq 'HASH';

	# Expand a few things
	if ( defined _STRING($host->{main_files}) ) {
		$host->{main_files} = [
			 split /\n/, $host->{main_files}
		];
	}
	if ( defined _STRING($host->{main_files_pos}) ) {
		$host->{main_files_pos} = [
			 split /\n/, $host->{main_files_pos}
		];
	}

	# Merge and create the configuration
	return $class->new( %$hash, host => $host );
}

sub write {
	my $self = shift;

	# Clone and remove the bless
	my $copy = Storable::dclone( +{ %$self } );

	# Serialize some values
	$copy->{host}->{main_files} = join( "\n", grep { defined } @{$copy->{host}->{main_files}} );
	$copy->{host}->{main_files_pos} = join( "\n", grep { defined } @{$copy->{host}->{main_files_pos}} );

	# Save the host configuration
	Padre::DB::Hostconf->write( delete $copy->{host} );

	# Save the user configuration
	YAML::Tiny::DumpFile( $_[0], $copy );

	return 1;
}





#####################################################################
# Human-Layer Settings

use Class::XSAccessor
	getters => {
		main_startup             => 'main_startup',
		main_lockinterface       => 'main_lockinterface',
		main_functions           => 'main_functions',
		main_functions_order     => 'main_functions_order',
		main_outline             => 'main_outline',
		main_output              => 'main_output',
		main_output_ansi         => 'main_output_ansi',
		main_syntaxcheck         => 'main_syntaxcheck',
		main_errorlist           => 'main_errorlist',
		main_statusbar           => 'main_statusbar',
		editor_font              => 'editor_font',
		editor_linenumbers       => 'editor_linenumbers',
		editor_eol               => 'editor_eol',
		editor_whitespace        => 'editor_whitespace',
		editor_indentationguides => 'editor_indentationguides',
		editor_calltips          => 'editor_calltips',
		editor_autoindent        => 'editor_autoindent',
		editor_folding           => 'editor_folding',
		editor_wordwrap          => 'editor_wordwrap',
		editor_currentline       => 'editor_currentline',
		editor_currentline_color => 'editor_currentline_color',
		editor_beginner          => 'editor_beginner',
		editor_indent_auto       => 'editor_indent_auto',
		editor_indent_tab        => 'editor_indent_tab',
		editor_indent_tab_width  => 'editor_indent_tab_width',
		editor_indent_width      => 'editor_indent_width',
		find_case                => 'find_case',
		find_regex               => 'find_regex',
		find_reverse             => 'find_reverse',
		find_first               => 'find_first',
		find_nohidden            => 'find_nohidden',
		find_quick               => 'find_quick',
		ppi_highlight            => 'ppi_highlight',
		ppi_highlight_limit      => 'ppi_highlight_limit',
		run_save                 => 'run_save',
		run_stacktrace           => 'run_stacktrace',
		locale                   => 'locale',
		locale_perldiag          => 'locale_perldiag',
		threads                  => 'threads',
		experimental             => 'experimental',
	};





#####################################################################
# Host-Layer Settings

sub main_maximized {
	$_[0]->{host}->{main_maximized};
}

sub main_top {
	$_[0]->{host}->{main_top};
}

sub main_left {
	$_[0]->{host}->{main_left};
}

sub main_width {
	$_[0]->{host}->{main_width};
}

sub main_height {
	$_[0]->{host}->{main_height};
}

sub main_auilayout {
	$_[0]->{host}->{main_auilayout};
}

sub main_file {
	$_[0]->{host}->{main_file};
}

sub main_files {
	$_[0]->{host}->{main_files};
}

sub main_files_pos {
	$_[0]->{host}->{main_files_pos};
}

sub editor_style {
	$_[0]->{host}->{editor_style};
}





#####################################################################
# Setting a Setting

sub set {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	# Check the human layer
	if ( exists $self->{$name} ) {
		$self->{$name} = $value;
		return 1;
	}

	# Check the host layer
	if ( exists $self->{host}->{$name} ) {
		$self->{host}->{$name} = $value;
		return 1;
	}

	# FAIL
	die("Unknown or unsupported configuration setting '$name'");
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Config2;

# To help force the break from the first-generate HASH based configuration
# over to the second-generation method based configuration, initially we
# will use an ARRAY-based object, so that all existing code is forcefully
# broken.

use 5.008;
use strict;
use warnings;
use Carp                   ();
use File::Spec             ();
use File::HomeDir          ();
use Params::Util           qw{_INSTANCE};
use Padre::Config::Setting ();
use Padre::Config::Human   ();
use Padre::Config::Project ();
use Padre::Config::Host    ();

our $VERSION = '0.25';

# Settings Types (based on Firefox)
use constant BOOLEAN => 0;
use constant INTEGER => 1;
use constant STRING  => 2;
use constant PATH    => 3;

# Setting Stores
use constant HOST    => 0;
use constant HUMAN   => 1;
use constant PROJECT => 2;

use Class::XSAccessor::Array
	getters => {
		host    => HOST,
		human   => HUMAN,
		project => PROJECT,
	};

# Establish Padre's home directory
my $DEFAULT_DIR = undef;
if ( defined $ENV{PADRE_HOME} ) {
	# When explicitly set, always use the Unix style
	$DEFAULT_DIR = File::Spec->catdir(
		$ENV{PADRE_HOME},
		'.padre',
	);
} elsif ( File::Spec->isa('File::Spec::Win32') ) {
	# On Windows use the traditional Vendor/Product format
	$DEFAULT_DIR = File::Spec->catdir(
		File::HomeDir->my_data,
		'Perl',
		'Padre',
	);
} else {
	# Use the the Unix style elsewhere
	# TODO - We may want to do something special on Mac
	$DEFAULT_DIR = File::Spec->catdir(
		File::HomeDir->my_data,
		'.padre',
	);
}
unless ( File::Spec->file_name_is_absolute($DEFAULT_DIR) ) {
	$DEFAULT_DIR = File::Spec->rel2abs($DEFAULT_DIR);
}





#####################################################################
# Settings Specification

# This section identifies the set of all named configuration entries,
# and where the configuration system should resolve them to.

# Setting Storage
our %SETTING = ();

# Indent Settings
# Allow projects to forcefully override personal settings
setting(
	name    => 'editor_indent_auto',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'editor_indent_tab',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'editor_indent_tab_width',
	type    => INTEGER,
	store   => HUMAN,
	default => 8,
);
setting(
	name    => 'editor_indent_width',
	type    => INTEGER,
	store   => HUMAN,
	default => 8,
);

# Pages and Panels
setting(
	# startup mode, if no files given on the command line this can be
	#   new        - a new empty buffer
	#   nothing    - nothing to open
	#   last       - the files that were open last time
	name    => 'main_startup',
	type    => STRING,
	store   => HUMAN,
	default => 'new',
);
setting(
	name    => 'main_lockinterface',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'main_functions',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'main_functions_order',
	type    => STRING,
	store   => HUMAN,
	default => 'alphabetical',
);
setting(
	name    => 'main_outline',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'main_output',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'main_output_ansi',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'main_syntaxcheck',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'main_errorlist',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'main_statusbar',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);

# Editor settings
setting(
	name    => 'editor_font',
	type    => STRING,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'editor_linenumbers',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'editor_eol',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'editor_whitespace',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'editor_indentationguides',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'editor_calltips',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'editor_autoindent',
	type    => STRING,
	store   => HUMAN,
	default => 'deep',
);
setting(
	name    => 'editor_folding',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'editor_currentline',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'editor_currentline_color',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 'FFFF04',
);
setting(
	name    => 'editor_beginner',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'find_case',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'find_regex',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'find_reverse',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'find_first',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'find_nohidden',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'find_quick',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'ppi_highlight',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'ppi_highlight_limit',
	type    => INTEGER,
	store   => HUMAN,
	default => 2000,
);

# Behaviour Tuning
setting(
	# When running a script from the application some of the files might have not been saved yet.
	# There are several option what to do before running the script
	# none - don's save anything
	# same - save the file in the current buffer
	# all_files - all the files (but not buffers that have no filenames)
	# all_buffers - all the buffers even if they don't have a name yet
	name    => 'run_save',
	type    => STRING,
	store   => HUMAN,
	default => 'same',
);
setting(
	name    => 'run_stacktrace',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	# By default use background threads unless profiling
	# TODO - Make the default actually change
	name    => 'threads',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 1,
);
setting(
	name    => 'locale',
	type    => STRING,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'locale_perldiag',
	type    => STRING,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'experimental',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);

# Because the colour data is in local files,
# it has to be a host-specific setting.
setting(
	name    => 'editor_style',
	type    => STRING,
	store   => HOST,
	default => 'default',
);

# Window geometry
setting(
	name    => 'main_maximized',
	type    => BOOLEAN,
	store   => HOST,
	default => 0,
);
setting(
	name    => 'main_top',
	type    => INTEGER,
	store   => HOST,
	default => 40,
);
setting(
	name    => 'main_left',
	type    => INTEGER,
	store   => HOST,
	default => 20,
);
setting(
	name    => 'main_width',
	type    => INTEGER,
	store   => HOST,
	default => 600,
);
setting(
	name    => 'main_height',
	type    => INTEGER,
	store   => HOST,
	default => 400,
);

# Editor Session State
setting(
	name    => 'main_file',
	type    => STRING,
	store   => HOST,
	default => undef,
);
setting(
	name    => 'main_files',
	type    => STRING,
	store   => HOST,
	default => [],
);
setting(
	name    => 'main_files_pos',
	type    => STRING,
	store   => HOST,
	default => [],
);





#####################################################################
# Class-Level Functionality

sub default_dir {
	unless ( -e $DEFAULT_DIR ) {
		mkdir($DEFAULT_DIR) or
		die "Cannot create config dir '$DEFAULT_DIR' $!";
	}
	return $DEFAULT_DIR;
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

# TODO - This should probably live in Padre::PluginManager somewhere
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
	chmod( 0644, $target );

	return 1;
}










#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $host  = shift;
	my $human = shift;
	unless ( _INSTANCE($host, 'Padre::Config::Host') ) {
		Carp::croak("Did not provide a host config to Padre::Config2->new");
	}
	unless ( _INSTANCE($human, 'Padre::Config::Human') ) {
		Carp::croak("Did not provide a user config to Padre::Config2->new");
	}

	# Create the basic object with the two required elements
	my $self = bless [ $host, $human ], $class;

	# Add the optional third element
	if ( @_ ) {
		my $project = shift;
		unless ( _INSTANCE($project, 'Padre::Config::Project') ) {
			Carp::croak("Did not provide a project config to Padre::Config2->new");
		}
		$self->[PROJECT] = $project;
	}

	return $self;
}

sub read {
	my $class = shift;

	# Load the host configuration
	my $host = Padre::Config::Host->read;

	# Load the user configuration
	die "TO BE COMPLETED";
}





#####################################################################
# Code Generation

# Cache the defaults
our %DEFAULT = ();

sub setting {
	# Validate the setting
	my $object = Padre::Config::Setting->new(@_);
	if ( $SETTING{$object->{name}} ) {
		Carp::croak("The $object->{name} setting is already defined");
	}

	# Generate the accessor
	my $code = <<"END_PERL";
sub $object->{name} {
	my \$self = shift;
	if ( exists \$self->[$object->{store}]->{'$object->{name}'} ) {
		return \$self->[$object->{store}]->{'$object->{name}'};
	}
	return \$DEFAULT{'$object->{name}'};
}
END_PERL

	# Compile the accessor
	eval $code; ## no critic
	if ( $@ ) {
		Carp::croak("Failed to compile setting $object->{name}");
	}

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Config;

# To help force the break from the first-generate HASH based configuration
# over to the second-generation method based configuration, initially we
# will use an ARRAY-based object, so that all existing code is forcefully
# broken.

use 5.008;
use strict;
use warnings;
use Carp                   ();
use File::Spec             ();
use File::Copy             ();
use File::HomeDir          ();
use File::Path             ();
use Params::Util           qw{ _POSINT _INSTANCE };
use Padre::Config::Setting ();
use Padre::Config::Human   ();
use Padre::Config::Project ();
use Padre::Config::Host    ();

use Padre::Config::Constants qw{ $PADRE_CONFIG_DIR };

our $VERSION   = '0.28';

# Master storage of the settings
our %SETTING   = ();

# A cache for the defaults
our %DEFAULT   = ();

# The configuration revision.
# (Functionally similar to the database revision)
our $REVISION  = 1;

# Storage for the default config object
our $SINGLETON = undef;

# Settings Types (based on Firefox)
use constant BOOLEAN => 0;
use constant POSINT  => 1;
use constant INTEGER => 2;
use constant ASCII  => 3;
use constant PATH    => 4;

# Setting Stores
use constant HOST    => 0;
use constant HUMAN   => 1;
use constant PROJECT => 2;

# Accessor generation
use Class::XSAccessor::Array
	getters => {
		host    => HOST,
		human   => HUMAN,
		project => PROJECT,
	};

sub product_path {
	if ( defined $ENV{PADRE_HOME} ) {
		# When explicitly set, always use the Unix style
		return qw{ .padre };
	} elsif ( File::Spec->isa('File::Spec::Win32') ) {
		# On Windows use the traditional Vendor/Product format
		return qw{ Perl Padre };
	} else {
		# Use the the Unix style elsewhere.
		# TODO - We may want to do something special on Mac
		return qw{ .padre };
	}
}

# Establish Padre's home directory
my $DEFAULT_DIR = $PADRE_CONFIG_DIR;





#####################################################################
# Settings Specification

# This section identifies the set of all named configuration entries,
# and where the configuration system should resolve them to.

# The identity of the user (simplistic initial version)
setting(
	# Initially, this must be ascii only
	name    => 'identity_name',
	type    => ASCII,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'identity_email',
	type    => ASCII,
	store   => HUMAN,
	default => '',
);


# for Module::Starter
setting(
	name    => 'license',
	type    => ASCII,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'builder',
	type    => ASCII,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'module_start_directory',
	type    => ASCII,
	store   => HUMAN,
	default => '',
);


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
	type    => POSINT,
	store   => HUMAN,
	default => 8,
);
setting(
	name    => 'editor_indent_width',
	type    => POSINT,
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
	type    => ASCII,
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
	type    => ASCII,
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
	name    => 'main_directory',
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
	type    => ASCII,
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
	type    => ASCII,
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
	type    => ASCII,
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
	name    => 'editor_wordwrap',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
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
	type    => POSINT,
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
	type    => ASCII,
	store   => HUMAN,
	default => 'same',
);
# Move of stacktrace to run menu: will be removed (run_stacktrace)
setting(
	name    => 'run_stacktrace',
	type    => BOOLEAN,
	store   => HUMAN,
	default => 0,
);
setting(
	name    => 'autocomplete_brackets',
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
	type    => ASCII,
	store   => HUMAN,
	default => '',
);
setting(
	name    => 'locale_perldiag',
	type    => ASCII,
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
	type    => ASCII,
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
	type    => POSINT,
	store   => HOST,
	default => 600,
);
setting(
	name    => 'main_height',
	type    => POSINT,
	store   => HOST,
	default => 400,
);





#####################################################################
# Class-Level Functionality

sub default_dir {
	unless ( -e $DEFAULT_DIR ) {
		File::Path::mkpath($DEFAULT_DIR) or
		die "Cannot create config dir '$DEFAULT_DIR' $!";
	}
	return $DEFAULT_DIR;
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
	my $src = File::Spec->catfile(
		File::Basename::dirname($INC{'Padre/Config.pm'}),
		'Plugin', 'My.pm'
	);
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
		Carp::croak("Did not provide a host config to Padre::Config->new");
	}
	unless ( _INSTANCE($human, 'Padre::Config::Human') ) {
		Carp::croak("Did not provide a user config to Padre::Config->new");
	}

	# Create the basic object with the two required elements
	my $self = bless [ $host, $human, undef ], $class;

	# Add the optional third element
	if ( @_ ) {
		my $project = shift;
		unless ( _INSTANCE($project, 'Padre::Config::Project') ) {
			Carp::croak("Did not provide a project config to Padre::Config->new");
		}
		$self->[PROJECT] = $project;
	}

	return $self;
}

sub set {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	# Does the setting exist?
	my $setting = $SETTING{$name} or
	Carp::croak("The configuration setting '$name' does not exist");

	# All types are ASCII-like
	unless ( defined $value and not ref $value ) {
		Carp::croak("Missing or non-scalar value for setting '$name'");
	}

	# We don't need to do additional checks on ASCII types at this point
	my $type = $setting->type;
	if ( $type == BOOLEAN and $value ne '1' and $value ne '0' ) {
		Carp::croak("Tried to change setting '$name' to non-boolean '$value'");
	}
	if ( $type == POSINT and not _POSINT($value) ) {
		Carp::croak("Tried to change setting '$name' to non-posint '$value'");
	}
	if ( $type == INTEGER and not _INTEGER($value) ) {
		Carp::croak("Tried to change setting '$name' to non-integer '$value'");
	}
	if ( $type == PATH and not -e $value ) {
		Carp::croak("Tried to change setting '$name' to non-existant path '$value'");
	}

	# Set the value into the appropriate backend
	my $store = $SETTING{$name}->store;
	$self->[$store]->{$name} = $value;

	return 1;
}

# Fetches an explicitly named default
sub default {
	my $self  = shift;
	my $name  = shift;

	# Does the setting exist?
	my $setting = $SETTING{$name} or
	Carp::croak("The configuration setting '$name' does not exist");

	return $DEFAULT{$name};
}

sub read {
	my $class = shift;

	unless ( $SINGLETON ) {
		# Load the host configuration
		my $host = Padre::Config::Host->read;

		# Load the user configuration
		my $human = Padre::Config::Human->read
			|| Padre::Config::Human->create;

		# Hand off to the constructor
		$SINGLETON = $class->new( $host, $human );

		# TODO - Check the version
	}

	return $SINGLETON;
}

sub write {
	my $self = shift;

	# Save the user configuration
	$self->[HUMAN]->{version} = $REVISION;
	$self->[HUMAN]->write();

	# Save the host configuration
	$self->[HOST]->{version} = $REVISION;
	$self->[HOST]->write;

	return 1;
}





#####################################################################
# Support Functions

sub setting {
	# Validate the setting
	my $object = Padre::Config::Setting->new(@_);
	if ( $SETTING{$object->{name}} ) {
		Carp::croak("The $object->{name} setting is already defined");
	}

	# Generate the accessor
	my $code = <<"END_PERL";
package Padre::Config;

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

	# Save the setting
	$SETTING{$object->{name}} = $object;
	$DEFAULT{$object->{name}} = $object->{default};

	return 1;
}

sub _INTEGER ($) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^(?:0|-?[1-9]\d*)$/) ? 1 : undef;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

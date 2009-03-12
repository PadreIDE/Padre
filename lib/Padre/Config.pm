#
# Configuration subsystem for Padre
#

package Padre::Config;

# To help force the break from the first-generate HASH based configuration
# over to the second-generation method based configuration, initially we
# will use an ARRAY-based object, so that all existing code is forcefully
# broken.

use 5.008;
use strict;
use warnings;

use Carp                     qw{ croak };
use Params::Util             qw{ _POSINT _INSTANCE };
use Padre::Config::Constants qw{ :stores :types $PADRE_CONFIG_DIR };
use Padre::Config::Setting   ();
use Padre::Config::Human     ();
use Padre::Config::Project   ();
use Padre::Config::Host      ();


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


# Accessor generation
use Class::XSAccessor::Array
	getters => {
		host    => $HOST,
		human   => $HUMAN,
		project => $PROJECT,
	};

#####################################################################
# Settings Specification

# This section identifies the set of all named configuration entries,
# and where the configuration system should resolve them to.

my %settings = (
human => [
	# for each setting, add an array ref:
	# [ $setting_name, $setting_type, $setting_default ]

	# -- user identity (simplistic initial version)
	[ 'identity_name',  $ASCII, '' ],  # Initially, this must be ascii only
	[ 'identity_email', $ASCII, '' ],
	
	# -- for module::starter
	[ 'license',                $ASCII, '' ],
	[ 'builder',                $ASCII, '' ],
	[ 'module_start_directory', $ASCII, '' ],
	
	# -- indent settings
	# allow projects to forcefully override personal settings
	[ 'editor_indent_auto',      $BOOLEAN, 1 ],
	[ 'editor_indent_tab',       $BOOLEAN, 1 ],
	[ 'editor_indent_tab_width', $POSINT,  8 ],
	[ 'editor_indent_width',     $POSINT,  8 ],
	
	# -- pages and panels
	# startup mode, if no files given on the command line this can be
	#   new        - a new empty buffer
	#   nothing    - nothing to open
	#   last       - the files that were open last time
	[ 'main_startup',         $ASCII,   'new'          ],
	[ 'main_lockinterface',   $BOOLEAN, 1              ],
	[ 'main_functions',       $BOOLEAN, 0              ],
	[ 'main_functions_order', $ASCII,   'alphabetical' ],
	[ 'main_outline',         $BOOLEAN, 0              ],
	[ 'main_directory',       $BOOLEAN, 0              ],
	[ 'main_output',          $BOOLEAN, 0              ],
	[ 'main_output_ansi',     $BOOLEAN, 1              ],
	[ 'main_syntaxcheck',     $BOOLEAN, 0              ],
	[ 'main_errorlist',       $BOOLEAN, 0              ],
	[ 'main_statusbar',       $BOOLEAN, 1              ],
	
	# -- editor settings
	[ 'editor_font',              $ASCII,   ''       ],
	[ 'editor_linenumbers',       $BOOLEAN, 1        ],
	[ 'editor_eol',               $BOOLEAN, 0        ],
	[ 'editor_whitespace',        $BOOLEAN, 0        ],
	[ 'editor_indentationguides', $BOOLEAN, 0        ],
	[ 'editor_calltips',          $BOOLEAN, 0        ],
	[ 'editor_autoindent',        $ASCII,   'deep'   ],
	[ 'editor_folding',           $BOOLEAN, 0        ],
	[ 'editor_currentline',       $BOOLEAN, 1        ],
	[ 'editor_currentline_color', $ASCII,   'FFFF04' ],
	[ 'editor_beginner',          $BOOLEAN, 1        ],
	[ 'editor_wordwrap',          $BOOLEAN, 0        ],
	[ 'find_case',                $BOOLEAN, 1        ],
	[ 'find_regex',               $BOOLEAN, 0        ],
	[ 'find_reverse',             $BOOLEAN, 0        ],
	[ 'find_first',               $BOOLEAN, 0        ],
	[ 'find_nohidden',            $BOOLEAN, 1        ],
	[ 'find_quick',               $BOOLEAN, 0        ],
	[ 'ppi_highlight',            $BOOLEAN, 0        ],
	[ 'ppi_highlight_limit',      $POSINT,  2000     ],
	
	# -- behaviour tuning
	# When running a script from the application some of the files might have
	# not been saved yet. There are several option what to do before running the
	# script:
	# none - don't save anything
	# same - save the file in the current buffer
	# all_files - all the files (but not buffers that have no filenames)
	# all_buffers - all the buffers even if they don't have a name yet
	[ 'run_save',              $ASCII,   'same' ],
	# move of stacktrace to run menu: will be removed (run_stacktrace)
	[ 'run_stacktrace',        $BOOLEAN, 0      ],
	[ 'autocomplete_brackets', $BOOLEAN, 0      ],
	# by default use background threads unless profiling
	# TODO - Make the default actually change
	[ 'threads',               $BOOLEAN, 1      ],
	[ 'locale',                $ASCII,   ''     ],
	[ 'locale_perldiag',       $ASCII,   ''     ],
	[ 'experimental',          $BOOLEAN, 0      ],
],
host => [
	# for each setting, add an array ref:
	# [ $setting_name, $setting_type, $setting_default ]

	# -- color data
	# since it's in local files, it has to be a host-specific setting
	[ 'editor_style', $ASCII, 'default' ],
	
	# -- window geometry
	[ 'main_maximized', $BOOLEAN, 0   ],
	[ 'main_top',       $INTEGER, 40  ],
	[ 'main_left',      $INTEGER, 20  ],
	[ 'main_width',     $POSINT,  600 ],
	[ 'main_height',    $POSINT,  400 ],
],
);
my %store = (
	human => $HUMAN,
	host  => $HOST,
);
foreach my $type ( keys %settings ) {
	my $settings = $settings{$type};
	my $store    = $store{$type};
	foreach my $setting ( @$settings ) {
		my ($name, $type, $default) = @$setting;
		_setting(
			name    => $name,
			type    => $type,
			store   => $store,
			default => $default,
		);
	}
}



#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $host  = shift;
	my $human = shift;
	unless ( _INSTANCE($host, 'Padre::Config::Host') ) {
		croak("Did not provide a host config to Padre::Config->new");
	}
	unless ( _INSTANCE($human, 'Padre::Config::Human') ) {
		croak("Did not provide a user config to Padre::Config->new");
	}

	# Create the basic object with the two required elements
	my $self = bless [ $host, $human, undef ], $class;

	# Add the optional third element
	if ( @_ ) {
		my $project = shift;
		unless ( _INSTANCE($project, 'Padre::Config::Project') ) {
			croak("Did not provide a project config to Padre::Config->new");
		}
		$self->[$PROJECT] = $project;
	}

	return $self;
}

sub set {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	# Does the setting exist?
	my $setting = $SETTING{$name} or
	croak("The configuration setting '$name' does not exist");

	# All types are $ASCII-like
	unless ( defined $value and not ref $value ) {
		croak("Missing or non-scalar value for setting '$name'");
	}

	# We don't need to do additional checks on $ASCII types at this point
	my $type = $setting->type;
	if ( $type == $BOOLEAN and $value ne '1' and $value ne '0' ) {
		croak("Tried to change setting '$name' to non-boolean '$value'");
	}
	if ( $type == $POSINT and not _POSINT($value) ) {
		croak("Tried to change setting '$name' to non-posint '$value'");
	}
	if ( $type == $INTEGER and not _INTEGER($value) ) {
		croak("Tried to change setting '$name' to non-integer '$value'");
	}
	if ( $type == $PATH and not -e $value ) {
		croak("Tried to change setting '$name' to non-existant path '$value'");
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
	croak("The configuration setting '$name' does not exist");

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
	$self->[$HUMAN]->{version} = $REVISION;
	$self->[$HUMAN]->write();

	# Save the host configuration
	$self->[$HOST]->{version} = $REVISION;
	$self->[$HOST]->write;

	return 1;
}


# -- private subs

#
# _setting( %params );
#
# create a new setting, with %params used to feed the new object.
#
sub _setting {
	# Validate the setting
	my $object = Padre::Config::Setting->new(@_);
	if ( $SETTING{$object->{name}} ) {
		croak("The $object->{name} setting is already defined");
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
		croak("Failed to compile setting $object->{name}");
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

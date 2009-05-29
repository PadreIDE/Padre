package Padre::Config;

#
# Configuration subsystem for Padre
#

# To help force the break from the first-generate HASH based configuration
# over to the second-generation method based configuration, initially we
# will use an ARRAY-based object, so that all existing code is forcefully
# broken.

use 5.008;
use strict;
use warnings;
use Carp                   ();
use Params::Util           ();
use Padre::Constant        ();
use Padre::Config::Setting ();
use Padre::Config::Human   ();
use Padre::Config::Project ();
use Padre::Config::Host    ();

our $VERSION = '0.36';

# Master storage of the settings
our %SETTING = ();

# A cache for the defaults
our %DEFAULT = ();

# The configuration revision.
# (Functionally similar to the database revision)
our $REVISION = 1;

# Storage for the default config object
our $SINGLETON = undef;

# Accessor generation
use Class::XSAccessor::Array getters => {
	host    => Padre::Constant::HOST,
	human   => Padre::Constant::HUMAN,
	project => Padre::Constant::PROJECT,
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
		[ 'identity_name',  Padre::Constant::ASCII, '' ],    # Initially, this must be ascii only
		[ 'identity_email', Padre::Constant::ASCII, '' ],

		# -- for module::starter
		[ 'license',                Padre::Constant::ASCII, '' ],
		[ 'builder',                Padre::Constant::ASCII, '' ],
		[ 'module_start_directory', Padre::Constant::ASCII, '' ],

		# -- indent settings
		# allow projects to forcefully override personal settings
		[ 'editor_indent_auto',      Padre::Constant::BOOLEAN, 1 ],
		[ 'editor_indent_tab',       Padre::Constant::BOOLEAN, 1 ],
		[ 'editor_indent_tab_width', Padre::Constant::POSINT,  8 ],
		[ 'editor_indent_width',     Padre::Constant::POSINT,  8 ],

		# -- pages and panels
		# startup mode, if no files given on the command line this can be
		#   new        - a new empty buffer
		#   nothing    - nothing to open
		#   last       - the files that were open last time
		[ 'main_startup',         Padre::Constant::ASCII,   'new' ],
		[ 'main_singleinstance',  Padre::Constant::BOOLEAN, 0 ],
		[ 'main_lockinterface',   Padre::Constant::BOOLEAN, 1 ],
		[ 'main_functions',       Padre::Constant::BOOLEAN, 0 ],
		[ 'main_functions_order', Padre::Constant::ASCII,   'alphabetical' ],
		[ 'main_outline',         Padre::Constant::BOOLEAN, 0 ],
		[ 'main_directory',       Padre::Constant::BOOLEAN, 0 ],
		[ 'main_output',          Padre::Constant::BOOLEAN, 0 ],
		[ 'main_output_ansi',     Padre::Constant::BOOLEAN, 1 ],
		[ 'main_syntaxcheck',     Padre::Constant::BOOLEAN, 0 ],
		[ 'main_errorlist',       Padre::Constant::BOOLEAN, 0 ],
		[ 'main_statusbar',       Padre::Constant::BOOLEAN, 1 ],

		# -- editor settings
		[ 'editor_font',              Padre::Constant::ASCII,   '' ],
		[ 'editor_linenumbers',       Padre::Constant::BOOLEAN, 1 ],
		[ 'editor_eol',               Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_whitespace',        Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_indentationguides', Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_calltips',          Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_autoindent',        Padre::Constant::ASCII,   'deep' ],
		[ 'editor_folding',           Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_fold_pod',          Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_currentline',       Padre::Constant::BOOLEAN, 1 ],
		[ 'editor_currentline_color', Padre::Constant::ASCII,   'FFFF04' ],
		[ 'editor_beginner',          Padre::Constant::BOOLEAN, 1 ],
		[ 'editor_wordwrap',          Padre::Constant::BOOLEAN, 0 ],
		[ 'editor_file_size_limit',   Padre::Constant::POSINT,  500_000 ],
		[ 'find_case',                Padre::Constant::BOOLEAN, 1 ],
		[ 'find_regex',               Padre::Constant::BOOLEAN, 0 ],
		[ 'find_reverse',             Padre::Constant::BOOLEAN, 0 ],
		[ 'find_first',               Padre::Constant::BOOLEAN, 0 ],
		[ 'find_nohidden',            Padre::Constant::BOOLEAN, 1 ],
		[ 'find_quick',               Padre::Constant::BOOLEAN, 0 ],
		[ 'ppi_highlight',            Padre::Constant::BOOLEAN, 0 ],
		[ 'ppi_highlight_limit',      Padre::Constant::POSINT,  2000 ],

		# -- behaviour tuning
		# When running a script from the application some of the files might have
		# not been saved yet. There are several option what to do before running the
		# script:
		# none - don't save anything (the script will be run without current modifications)
		# unsaved - as above but including modifications present in the buffer
		# same - save the file in the current buffer
		# all_files - all the files (but not buffers that have no filenames)
		# all_buffers - all the buffers even if they don't have a name yet
		[ 'run_save', Padre::Constant::ASCII, 'same' ],

		# move of stacktrace to run menu: will be removed (run_stacktrace)
		[ 'run_stacktrace',        Padre::Constant::BOOLEAN, 0 ],
		[ 'autocomplete_brackets', Padre::Constant::BOOLEAN, 0 ],

		# by default use background threads unless profiling
		# TODO - Make the default actually change
		[ 'threads',         Padre::Constant::BOOLEAN, 1 ],
		[ 'locale',          Padre::Constant::ASCII,   '' ],
		[ 'locale_perldiag', Padre::Constant::ASCII,   '' ],
		[ 'experimental',    Padre::Constant::BOOLEAN, 0 ],
	],
	host => [

		# for each setting, add an array ref:
		# [ $setting_name, $setting_type, $setting_default ]

		# -- color data
		# since it's in local files, it has to be a host-specific setting
		[ 'editor_style', Padre::Constant::ASCII, 'default' ],

		# -- window geometry
		[ 'main_maximized', Padre::Constant::BOOLEAN, 0 ],
		[ 'main_top',       Padre::Constant::INTEGER, 40 ],
		[ 'main_left',      Padre::Constant::INTEGER, 20 ],
		[ 'main_width',     Padre::Constant::POSINT,  600 ],
		[ 'main_height',    Padre::Constant::POSINT,  400 ],

		[ 'logging',       Padre::Constant::BOOLEAN, 0 ],
		[ 'logging_trace', Padre::Constant::BOOLEAN, 0 ],

		# -- default run parameters
		[ 'run_interpreter_args_default', Padre::Constant::ASCII, '' ],
		[ 'run_script_args_default',      Padre::Constant::ASCII, '' ],
		[ 'external_diff_tool',           Padre::Constant::ASCII, '' ],
	],
);

my %store = (
	human => Padre::Constant::HUMAN,
	host  => Padre::Constant::HOST,
);
foreach my $type ( keys %settings ) {
	my $settings = $settings{$type};
	my $store    = $store{$type};
	foreach my $setting (@$settings) {
		my ( $name, $type, $default ) = @$setting;
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
	unless ( Params::Util::_INSTANCE( $host, 'Padre::Config::Host' ) ) {
		Carp::croak("Did not provide a host config to Padre::Config->new");
	}
	unless ( Params::Util::_INSTANCE( $human, 'Padre::Config::Human' ) ) {
		Carp::croak("Did not provide a user config to Padre::Config->new");
	}

	# Create the basic object with the two required elements
	my $self = bless [ $host, $human, undef ], $class;

	# Add the optional third element
	if (@_) {
		my $project = shift;
		unless ( Params::Util::_INSTANCE( $project, 'Padre::Config::Project' ) ) {
			Carp::croak("Did not provide a project config to Padre::Config->new");
		}
		$self->[Padre::Constant::PROJECT] = $project;
	}

	return $self;
}

sub set {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	# Does the setting exist?
	my $setting = $SETTING{$name}
		or Carp::croak("The configuration setting '$name' does not exist");

	# All types are Padre::Constant::ASCII-like
	unless ( defined $value and not ref $value ) {
		Carp::croak("Missing or non-scalar value for setting '$name'");
	}

	# We don't need to do additional checks on Padre::Constant::ASCII
	# types at this point.
	my $type = $setting->type;
	if ( $type == Padre::Constant::BOOLEAN and $value ne '1' and $value ne '0' ) {
		Carp::croak("Tried to change setting '$name' to non-boolean '$value'");
	}
	if ( $type == Padre::Constant::POSINT and not Params::Util::_POSINT($value) ) {
		Carp::croak("Tried to change setting '$name' to non-posint '$value'");
	}
	if ( $type == Padre::Constant::INTEGER and not _INTEGER($value) ) {
		Carp::croak("Tried to change setting '$name' to non-integer '$value'");
	}
	if ( $type == Padre::Constant::PATH and not -e $value ) {
		Carp::croak("Tried to change setting '$name' to non-existant path '$value'");
	}

	# Set the value into the appropriate backend
	my $store = $SETTING{$name}->store;
	$self->[$store]->{$name} = $value;

	return 1;
}

# Fetches an explicitly named default
sub default {
	my $self = shift;
	my $name = shift;

	# Does the setting exist?
	unless ( $SETTING{$name} ) {
		Carp::croak("The configuration setting '$name' does not exist");
	}

	return $DEFAULT{$name};
}

sub read {
	my $class = shift;

	unless ($SINGLETON) {

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
	$self->[Padre::Constant::HUMAN]->{version} = $REVISION;
	$self->[Padre::Constant::HUMAN]->write;

	# Save the host configuration
	$self->[Padre::Constant::HOST]->{version} = $REVISION;
	$self->[Padre::Constant::HOST]->write;

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
	if ( $SETTING{ $object->{name} } ) {
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
	eval $code;    ## no critic
	if ($@) {
		Carp::croak("Failed to compile setting $object->{name}");
	}

	# Save the setting
	$SETTING{ $object->{name} } = $object;
	$DEFAULT{ $object->{name} } = $object->{default};

	return 1;
}

#
# my $is_integer = _INTEGER( $scalar );
#
# return true if $scalar is an integer.
#
sub _INTEGER ($) {
	return defined $_[0] && !ref $_[0] && $_[0] =~ m/^(?:0|-?[1-9]\d*)$/;
}

1;

__END__

=pod

=head1 NAME

Padre::Config - Configuration subsystem for Padre

=head1 SYNOPSIS

	use Padre::Config;
	[...]
	if ( Padre::Config->main_statusbar ) { [...] }

=head1 DESCRIPTION

=head2 Generic usage

Every setting is accessed by a method named after it, which is a mutator.
ie, it can be used both as a getter and a setter, depending on the number
of arguments passed to it.

=head2 Different types of settings

Padre needs to store different settings. Those preferences are stored in
different places depending on their impact. But C<Padre::Config> allows to
access them with a unified api (a mutator). Only their declaration differ
in the module.

Here are the various types of settings that C<Padre::Config> can manage:

=over 4

=item * User settings

Those settings are general settings that relates to user preferences. They range
from general user interface look&feel (whether to show the line numbers, etc.)
to editor preferences (tab width, etc.) and other personal settings.

Those settings are stored in a YAML file, and accessed with C<Padre::Config::Human>.

=item * Host settings

Those preferences are related to the host on which Padre is run. The principal
example of those settings are window appearance.

Those settings are stored in a DB file, and accessed with C<Padre::Config::Host>.

=item * Project settings

Those preferences are related to the project of the file you are currently
editing. Examples of those settings are whether to use tabs or spaces, etc.

Those settings are accessed with C<Padre::Config::Project>.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

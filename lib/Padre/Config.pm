package Padre::Config;

# Configuration subsystem for Padre

# To help force the break from the first-generate HASH based configuration
# over to thdee second-generation method based configuration, initially we
# will use an ARRAY-based object, so that all existing code is forcefully
# broken.

use 5.008;
use strict;
use warnings;
use Carp                   ();
use YAML::Tiny             ();
use Params::Util           ();
use Padre::Constant        ();
use Padre::Util            ('_T');
use Padre::Current         ();
use Padre::Config::Setting ();
use Padre::Config::Human   ();
use Padre::Config::Project ();
use Padre::Config::Host    ();
use Padre::Config::Upgrade ();
use Padre::Logger;

our $VERSION = '0.66';

our ( %SETTING, %DEFAULT, %STARTUP, $REVISION, $SINGLETON );

BEGIN {

	# Master storage of the settings
	%SETTING = ();

	# A cache for the defaults
	%DEFAULT = ();

	# A cache for startup.yml settings
	%STARTUP = ();

	# The configuration revision.
	# (Functionally similar to the database revision)
	$REVISION = 1;

	# Storage for the default config object
	$SINGLETON = undef;
}

# Accessor generation
use Class::XSAccessor::Array {
	getters => {
		host    => Padre::Constant::HOST,
		human   => Padre::Constant::HUMAN,
		project => Padre::Constant::PROJECT,
	}
};





#####################################################################
# Settings Specification

# This section identifies the set of all named configuration entries,
# and where the configuration system should resolve them to.

sub settings {
	sort keys %SETTING;
}

#
# setting( %params );
#
# create a new setting, with %params used to feed the new object.
#
sub setting {

	# Allow this sub to be called as a method or function
	shift if ref( $_[0] ) eq __PACKAGE__;

	# Validate the setting
	my $object = Padre::Config::Setting->new(@_);
	my $name   = $object->{name};
	if ( $SETTING{$name} ) {
		Carp::croak("The $name setting is already defined");
	}

	# Generate the accessor
	eval $object->code;
	Carp::croak("Failed to compile setting $object->{name}: $@") if $@;

	# Save the setting
	$SETTING{$name} = $object;
	$DEFAULT{$name} = $object->{default};
	$STARTUP{$name} = 1 if $object->{startup};

	return 1;
}





#####################################################################
# Constructor and Input/Output

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

sub read {
	my $class = shift;

	unless ($SINGLETON) {
		TRACE("Loading configuration for $class") if DEBUG;

		# Load the host configuration
		my $host = Padre::Config::Host->read;

		# Load the user configuration
		my $human = Padre::Config::Human->read
			|| Padre::Config::Human->create;

		# Hand off to the constructor
		$SINGLETON = $class->new( $host, $human );

		Padre::Config::Upgrade::check($SINGLETON);
	}

	return $SINGLETON;
}

sub write {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Save the user configuration
	$self->[Padre::Constant::HUMAN]->{version} = $REVISION;
	$self->[Padre::Constant::HUMAN]->write;

	# Save the host configuration
	$self->[Padre::Constant::HOST]->{version} = $REVISION;
	$self->[Padre::Constant::HOST]->write;

	# Write the startup subset of the configuration.
	# NOTE: Use a hyper-minimalist listified key/value file format
	# so that we don't need to load YAML::Tiny before the thread fork.
	# This should save around 400k of memory per background thread.
	my %startup = map { $_ => $self->$_() } sort keys %STARTUP;
	open( my $FILE, '>', Padre::Constant::CONFIG_STARTUP ) or return 1;
	print $FILE map {"$_\n$startup{$_}\n"} sort keys %startup or return 1;
	close $FILE or return 1;

	return 1;
}





######################################################################
# Main Methods

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

sub set {
	TRACE( $_[1] ) if DEBUG;
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	# Does the setting exist?
	my $setting = $SETTING{$name};
	unless ($setting) {
		Carp::croak("The configuration setting '$name' does not exist");
	}

	# All types are Padre::Constant::ASCII-like
	unless ( defined $value and not ref $value ) {
		Carp::croak("Missing or non-scalar value for setting '$name'");
	}

	# We don't need to do additional checks on Padre::Constant::ASCII
	my $type = $setting->type;
	if ( $type == Padre::Constant::BOOLEAN ) {
		$value = 0 if $value eq '';
		if ( $value ne '1' and $value ne '0' ) {
			Carp::croak("Tried to change setting '$name' to non-boolean '$value'");
		}
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

# Set a value in the configuration and apply the preference change
# to the application.
sub apply {
	TRACE( $_[0] ) if DEBUG;
	my $self    = shift;
	my $name    = shift;
	my $value   = shift;
	my $current = Padre::Current::_CURRENT(@_);

	# Set the config value
	$self->set( $name => $value );

	# Does this setting have an apply hook
	my $code = $SETTING{$name}->apply;
	if ($code) {
		$code->( $current->main, $value );
	}

	return 1;
}

sub meta {
	$SETTING{ $_[1] } or die("Missing or invalid setting name '$_[1]'");
}





######################################################################
# Support Functions

#
# my $is_integer = _INTEGER( $scalar );
#
# return true if $scalar is an integer.
#
sub _INTEGER {
	return defined $_[0] && !ref $_[0] && $_[0] =~ m/^(?:0|-?[1-9]\d*)$/;
}





######################################################################
# Basic Settings

# User identity (simplistic initial version)
# Initially, this must be ascii only
setting(
	name    => 'identity_name',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);
setting(
	name    => 'identity_email',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);
setting(
	name    => 'identity_nickname',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);

# Support for Module::Starter
setting(
	name    => 'license',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);
setting(
	name    => 'builder',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);
setting(
	name    => 'module_start_directory',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);

# Indent settings
# Allow projects to forcefully override personal settings
setting(
	name    => 'editor_indent_auto',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
	project => 1,
);
setting(
	name    => 'editor_indent_tab',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
	project => 1,
);
setting(
	name    => 'editor_indent_tab_width',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HUMAN,
	default => 8,
	project => 1,
);
setting(
	name    => 'editor_indent_width',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HUMAN,
	default => 8,
	project => 1,
);





#####################################################################
# Startup Behaviour Rules

setting(
	name    => 'startup_splash',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
	startup => 1,
);

# Startup mode, if no files given on the command line this can be
#   new        - a new empty buffer
#   nothing    - nothing to open
#   last       - the files that were open last time
setting(
	name    => 'startup_files',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'new',
	options => {
		'last'    => _T('Previous open files'),
		'new'     => _T('A new empty file'),
		'nothing' => _T('No open files'),
		'session' => _T('Open session'),
	},
);





######################################################################
# Main Window Tools and Layout

# Window
setting(
	name    => 'main_title',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'Padre [%p]',
);

setting(
	name    => 'main_singleinstance',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => Padre::Constant::DEFAULT_SINGLEINSTANCE,
	startup => 1,
	apply   => sub {
		my $main  = shift;
		my $value = shift;
		if ($value) {
			$main->single_instance_start;
		} else {
			$main->single_instance_stop;
		}
		return 1;
	},
);

setting(
	name    => 'main_singleinstance_port',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HOST,
	default => Padre::Constant::DEFAULT_SINGLEINSTANCE_PORT,
	startup => 1,
);

setting(
	name    => 'main_lockinterface',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
	apply   => sub {
		my $main  = shift;
		my $value = shift;

		# Update the lock status
		$main->aui->lock_panels($value);

		# The toolbar can't dynamically switch between
		# tearable and non-tearable so rebuild it.
		# TO DO: Review this assumption

		# (Ticket #668)

		if ($Padre::Wx::Toolbar::DOCKABLE) {
			$main->rebuild_toolbar;
		}

		return 1;
	}
);
setting(
	name    => 'main_functions',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_functions_order',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'alphabetical',
	options => {
		'original'                  => _T('Code Order'),
		'alphabetical'              => _T('Alphabetical Order'),
		'alphabetical_private_last' => _T('Alphabetical Order (Private Last)'),
	},
);
setting(
	name    => 'main_outline',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_todo',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_directory',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_directory_order',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'first',
	options => {
		first => _T('Directories First'),
		mixed => _T('Directories Mixed'),
	},
);
setting(
	name    => 'main_directory_panel',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'left',
	options => {
		'left'  => _T('Project Tools (Left)'),
		'right' => _T('Document Tools (Right)'),
	},
	apply => sub {
		my $main  = shift;
		my $value = shift;

		# Is it visible and on the wrong side?
		return 1 unless $main->has_directory;
		my $directory = $main->directory;
		return 1 unless $directory->IsShown;
		return 1 unless $directory->side ne $value;

		# Hide and reshow the tool with the new setting
		$directory->panel->hide($directory);
		$main->directory_panel->show($directory);
		$main->Layout;
		$main->Update;

		return 1;
	}
);
setting(
	name    => 'main_directory_root',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HOST,
	default => File::HomeDir->my_documents || '',
);
setting(
	name    => 'main_output',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_output_ansi',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'main_syntaxcheck',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_errorlist',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'main_statusbar',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name  => 'main_toolbar',
	type  => Padre::Constant::BOOLEAN,
	store => Padre::Constant::HUMAN,

	# Toolbars are not typically used for Mac apps.
	# Hide it by default so Padre looks "more Mac'ish"
	# NOTE: Or at least, so we were told. Opinions apparently vary.
	default => Padre::Constant::MAC ? 0 : 1,
);
setting(
	name  => 'main_toolbar_items',
	type  => Padre::Constant::ASCII,
	store => Padre::Constant::HUMAN,

	# This lives here until a better place is found:
	# This is a list of toolbar items, seperated by ;
	# The following items are supported:
	#   action
	#     Insert the action
	#   action(argument,argument)
	#     Insert an action which requires one or more arguments
	#   |
	#     Insert a seperator
	default => 'file.new;'
		. 'file.open;'
		. 'file.save;'
		. 'file.save_as;'
		. 'file.save_all;'
		. 'file.close;' . '|;'
		. 'file.open_example;' . '|;'
		. 'edit.undo;'
		. 'edit.redo;' . '|;'
		. 'edit.cut;'
		. 'edit.copy;'
		. 'edit.paste;'
		. 'edit.select_all;' . '|;'
		. 'search.find;'
		. 'search.replace;' . '|;'
		. 'edit.comment_toggle;' . '|;'
		. 'file.doc_stat;' . '|;'
		. 'search.open_resource;'
		. 'search.quick_menu_access;' . '|;'
		. 'run.run_document;'
		. 'run.stop;' . '|;'
		. 'debug.step_in;'
		. 'debug.step_over;'
		. 'debug.step_out;'
		. 'debug.run;'
		. 'debug.set_breakpoint;'
		. 'debug.display_value;'
		. 'debug.quit;'
);

setting(
	name    => 'swap_ctrl_tab_alt_right',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

# Directory Tree Settings
setting(
	name    => 'default_projects_directory',
	type    => Padre::Constant::PATH,
	store   => Padre::Constant::HOST,
	default => File::HomeDir->my_documents || '',
);

# Editor Settings
setting(
	name    => 'editor_font',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);
setting(
	name    => 'editor_linenumbers',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'editor_eol',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_whitespace',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_indentationguides',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_calltips',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_autoindent',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'deep',
	options => {
		'no'   => _T('No Autoindent'),
		'same' => _T('Indent to Same Depth'),
		'deep' => _T('Indent Deeply'),
	},
);
setting(
	name    => 'editor_folding',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_fold_pod',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

setting(
	name    => 'editor_brace_expression_highlighting',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

setting(
	name    => 'save_autoclean',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_currentline',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'editor_currentline_color',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'FFFF04',
);
setting(
	name    => 'editor_beginner',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'editor_wordwrap',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_file_size_limit',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HUMAN,
	default => 500_000,
);
setting(
	name    => 'editor_right_margin_enable',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'editor_right_margin_column',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HUMAN,
	default => 80,
);
setting(
	name    => 'editor_smart_highlight_enable',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'find_case',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'find_regex',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'find_reverse',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'find_first',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'find_nohidden',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'find_nomatch',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'find_quick',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'default_line_ending',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => Padre::Constant::NEWLINE
);
setting(
	name    => 'update_file_from_disk_interval',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 2,
);

# Autocomplete settings (global and Perl-specific)
setting(
	name    => 'autocomplete_multiclosebracket',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'autocomplete_always',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'autocomplete_method',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'autocomplete_subroutine',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'perl_autocomplete_max_suggestions',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 20,
);
setting(
	name    => 'perl_autocomplete_min_chars',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'perl_autocomplete_min_suggestion_len',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 3,
);
setting(
	name    => 'perl_ppi_lexer_limit',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HUMAN,
	default => 4000,
);

# Behaviour Tuning
# When running a script from the application some of the files might have
# not been saved yet. There are several option what to do before running the
# script:
# none - don't save anything (the script will be run without current modifications)
# unsaved - as above but including modifications present in the buffer
# same - save the file in the current buffer
# all_files - all the files (but not buffers that have no filenames)
# all_buffers - all the buffers even if they don't have a name yet
setting(
	name    => 'run_save',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 'same',
);
setting(
	name  => 'run_perl_cmd',
	type  => Padre::Constant::ASCII,
	store => Padre::Constant::HOST,

	# We don't get a default from Padre::Perl, because the saved value
	# may be outdated sometimes in the future, reading it fresh on
	# every run makes us more future-compatible
	default => '',
);

setting(
	name  => 'perl_tags_file',
	type  => Padre::Constant::ASCII,
	store => Padre::Constant::HOST,

	# Don't save a default to allow future updates
	default => '',
);

setting(
	name    => 'xs_calltips_perlapi_version',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::PROJECT,
	default => 'newest',
	project => 1,
);

setting(
	name    => 'info_on_statusbar',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

# Move of stacktrace to run menu: will be removed (run_stacktrace)
setting(
	name    => 'run_stacktrace',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'autocomplete_brackets',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

setting(
	name    => 'mid_button_paste',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'todo_regexp',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => "#\\s*(?:TO[- ]?DO|XXX|FIX[- ]?ME)(?:[ \\t]*[:-]?)(?:[ \\t]*)(.*?)\\s*\$",
);


# By default use background threads unless profiling
# TO DO - Make the default actually change

# (Ticket # 669)
setting(
	name    => 'threads',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
	startup => 1,
);
setting(
	name    => 'locale',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);
setting(
	name    => 'locale_perldiag',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => '',
);

# Colour Data
# Since it's in local files, it has to be a host-specific setting.
setting(
	name    => 'editor_style',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HOST,
	default => 'default',
);

# Window Geometry
setting(
	name    => 'main_maximized',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 0,
);
setting(
	name    => 'main_top',
	type    => Padre::Constant::INTEGER,
	store   => Padre::Constant::HOST,
	default => -1,
);
setting(
	name    => 'main_left',
	type    => Padre::Constant::INTEGER,
	store   => Padre::Constant::HOST,
	default => -1,
);
setting(
	name    => 'main_width',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HOST,
	default => -1,
);
setting(
	name    => 'main_height',
	type    => Padre::Constant::POSINT,
	store   => Padre::Constant::HOST,
	default => -1,
);

# Run Parameters
setting(
	name    => 'run_interpreter_args_default',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HOST,
	default => '',
);
setting(
	name    => 'run_script_args_default',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HOST,
	default => '',
);
setting(
	name    => 'run_use_external_window',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 0,
);
setting(
	name    => 'external_diff_tool',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HOST,
	default => '',
);

# Enable/Disable entire functions that some people dislike.
# Normally these should be enabled by default (or should be
# planned to eventually be enabled by default).
setting(
	name    => 'feature_config',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);
setting(
	name    => 'feature_bookmark',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'feature_fontsize',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'feature_session',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);
setting(
	name    => 'feature_cursormemory',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);

# Window menu list shorten common path
setting(
	name    => 'window_list_shorten_path',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 1,
);

# Beginner error checks configuration
setting(
	name    => 'begerror_split',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_warning',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_map',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_DB',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_chomp',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_map2',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_perl6',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_ifsetvar',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_pipeopen',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_pipe2open',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_regexq',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_elseif',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

setting(
	name    => 'begerror_close',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HOST,
	default => 1,
);

# Padre::File options

#   ::HTTP
setting(
	name    => 'file_http_timeout',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 30,
);

#   ::FTP
setting(
	name    => 'file_ftp_timeout',
	type    => Padre::Constant::ASCII,
	store   => Padre::Constant::HUMAN,
	default => 30,
);

setting(
	name    => 'file_ftp_passive',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 1,
);

# Non-preference settings
setting(
	name    => 'session_autosave',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

# The "config_" namespace is for the paths of other non-Padre config files
# for various external tools (usually so that projects can define the
# the location of their project-specific policies).

# Location of the Perl::Tidy RC file, if a project wants to set a custom one.
# When set to false, allow Perl::Tidy to use its own default config location.
# Load this from the project backend in preference to the host one, so that
# projects can set their own project-specific config file.
setting(
	name    => 'config_perltidy',
	type    => Padre::Constant::PATH,
	store   => Padre::Constant::PROJECT,
	default => '',
);

# Location of the Perl::Critic RC file, if a project wants to set a custom
# one. When set to false, allow Perl::Critic to use its own default config
# location. Load this from the project backend in preference to the host one,
# so that projects can set their own project-specific config file.
setting(
	name    => 'config_perlcritic',
	type    => Padre::Constant::PATH,
	store   => Padre::Constant::PROJECT,
	default => '',
);

# Save if feedback has been send or not
setting(
	name    => 'feedback_done',
	type    => Padre::Constant::BOOLEAN,
	store   => Padre::Constant::HUMAN,
	default => 0,
);

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

This module not only stores the complete Padre configuration, it also holds
the functions for loading and saving the configuration.

The Padre configuration lives in two places:

=over

=item a user-editable text file usually called F<config.yml>

=item an SQLite database which shouldn't be edited by the user

=back

=head2 Generic usage

Every setting is accessed by a mutator named after it,
i.e. it can be used both as a getter and a setter depending on the number
of arguments passed to it.

=head2 Different types of settings

Padre needs to store different settings. Those preferences are stored in
different places depending on their impact. But C<Padre::Config> allows to
access them with a unified API (a mutator). Only their declaration differs
in the module.

Here are the various types of settings that C<Padre::Config> can manage:

=over 4

=item * User settings

Those settings are general settings that relates to user preferences. They range
from general user interface I<look & feel> (whether to show the line numbers, etc.)
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

=head1 ADDING CONFIGURATION OPTIONS

Add a "setting()" - call to the correct section of this file.

The setting() call initially creates the option and defines some
metadata like the type of the option, it's living place and the
default value which should be used until the user configures
a own value.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

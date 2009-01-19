package Padre::Config2;

# To help force the break from the first-generate HASH based configuration
# over to the second-generation method based configuration, initially we
# will use an ARRAY-based object, so that all existing code is forcefully
# broken.

use 5.008;
use strict;
use warnings;
use Carp                   ();
use Params::Util           qw{_INSTANCE};
use Padre::Config::Host    ();
use Padre::Config::Human   ();
use Padre::Config::Project ();

our $VERSION = '0.25';

use constant HOST    => 0;
use constant HUMAN   => 1;
use constant PROJECT => 2;





#####################################################################
# Configuration Design

# This section identifies the set of all named configuration entries,
# and where the configuration system should resolve them to.

# Indent Settings
# Allow projects to forcefully override personal settings
config( editor_indent_auto       => PROJECT, HUMAN );
config( editor_indent_tab        => PROJECT, HUMAN );
config( editor_indent_tab_width  => PROJECT, HUMAN );
config( editor_indent_width      => PROJECT, HUMAN );

# Pages and Panels
config( main_lockinterface       => HUMAN );
config( main_functions           => HUMAN );
config( main_functions_order     => HUMAN );
config( main_outline             => HUMAN );
config( main_output              => HUMAN );
config( main_syntaxcheck         => HUMAN );
config( main_errorlist           => HUMAN );
config( main_statusbar           => HUMAN );

# Editor settings
config( editor_font              => HUMAN );
config( editor_linenumbers       => HUMAN );
config( editor_eol               => HUMAN );
config( editor_whitespace        => HUMAN );
config( editor_indentationguides => HUMAN );
config( editor_calltips          => HUMAN );
config( editor_autoindent        => HUMAN );
config( editor_folding           => HUMAN );
config( editor_currentline       => HUMAN );
config( editor_currentline_color => HUMAN );
config( editor_beginner          => HUMAN );
config( find_case                => HUMAN );
config( find_regex               => HUMAN );
config( find_reverse             => HUMAN );
config( find_first               => HUMAN );
config( find_nohuman             => HUMAN );
config( ppi_highlight            => HUMAN );
config( ppi_highlight_limit      => HUMAN );

# Behaviour Tuning
config( main_startup             => HUMAN );
config( run_save                 => HUMAN );
config( run_stacktrace           => HUMAN );
config( threads                  => HUMAN );
config( main_output_ansi         => HUMAN );
config( diagnostic_lang          => HUMAN );
config( experimental             => HUMAN );

# Because the colour data is in local files,
# it has to be a host-specific setting.
config( editor_style             => HOST  );

# Window geometry
config( main_maximized           => HOST  );
config( main_top                 => HOST  );
config( main_left                => HOST  );
config( main_width               => HOST  );
config( main_height              => HOST  );

# Editor Session State
config( main_file                => HOST  );
config( main_files               => HOST  );
config( main_files_pos           => HOST  );





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

sub host {
	$_[0]->[HOST];
}

sub human {
	$_[0]->[HUMAN];
}

sub project {
	$_[0]->[PROJECT];
}





#####################################################################
# Code Generation

sub config {
	my $name = shift;

	# Generate the accessor
	my @lines = (
		"\tmy \$self = shift;\n",
	);
	while ( @_ ) {
		my $part = [qw{HOST USER PROJECT}]->[shift] or next;
		push @lines, (
			"\tif ( exists \$self->[$part]->{$name} ) {\n",
			"\t\treturn \$self->[$part]->{$name};\n",
			"\t}\n",
		);
	}
	push @lines, "\treturn undef;\n";

	# Compile the accessor
	my $code = join( '', @lines );
	eval $code; ## no critic
	die("Failed to build config accessor for '$name'") if $@;

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Config::Setting;

# Simple data class for a configuration setting

use 5.008;
use strict;
use warnings;
use Carp            ();
use File::Spec      ();
use Params::Util    ();
use Padre::Constant ();

our $VERSION = '0.94';

use Class::XSAccessor {
	getters => [
		qw{
			name
			type
			store
			startup
			default
			project
			options
			help
			}
	],
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Param checking
	unless ( $self->name ) {
		Carp::croak("Missing or invalid name");
	}
	unless ( _TYPE( $self->type ) ) {
		Carp::croak("Missing or invalid type for config '$self->{name}'");
	}
	unless ( _STORE( $self->store ) ) {
		Carp::croak("Missing or invalid store for config '$self->{name}'");
	}
	unless ( exists $self->{default} ) {
		Carp::croak("Missing or invalid default for config '$self->{name}'");
	}

	if ( defined $self->{options} ) {
		unless ( Params::Util::_HASH( $self->{options} ) ) {
			Carp::croak("Invalid or empty options for config '$self->{name}'");
		}
	}

	# Path settings are subject to some special constraints
	if ( $self->type == Padre::Constant::PATH ) {

		# It is illegal to store paths in the human config
		if ( $self->store == Padre::Constant::HUMAN ) {
			Carp::croak("PATH value not in HOST store for config '$self->{name}'");
		}

		# You cannot (yet) define option lists for paths
		if ( defined $self->{options} ) {
			Carp::croak("PATH values cannot define options for config '$self->{name}'");
		}
	}

	# Normalise
	$self->{project} = !!$self->project;

	return $self;
}

# Generate the code to implement the setting
sub code {
	my $self  = shift;
	my $name  = $self->name;
	my $store = $self->store;

	# Don't return loaded values not in the valid option list
	# "$self" in this code refs to the Padre::Config parent object
	return <<"END_PERL" if defined $self->{options};
sub $name {
	my \$self   = shift;
	my \$config = \$self->[$store];
	if ( exists \$config->{$name} ) {
		my \$options = \$self->meta('$name')->options;
		my \$value   = \$config->{$name};
		if ( defined \$value and exists \$options->{\$value} ) {
			return \$value;
		}
	}
	return \$DEFAULT{$name};
}
END_PERL

	# Vanilla code for everything other than PATH entries
	return <<"END_PERL" unless $self->type == Padre::Constant::PATH;
package Padre::Config;

sub $name {
	my \$config = \$_[0]->[$store];
	return \$config->{$name} if exists \$config->{$name};
	return \$DEFAULT{$name};
}
END_PERL

	# Relative paths for project-specific paths
	return <<"END_PERL" if $store == Padre::Constant::PROJECT;
package Padre::Config;

sub $name {
	my \$config = \$_[0]->[$store];
	if ( \$config ) {
		my \$dirname  = \$config->dirname;
		my \$relative = \$config->{$name};
		if ( defined \$relative ) {
			my \$literal = File::Spec->catfile(
				\$dirname, \$relative,
			);
			return \$literal if -e \$literal;
		}
	}
	return \$DEFAULT{$name};
}
END_PERL

	# Literal paths for HOST values unless Portable mode is enabled
	return <<"END_PERL" unless Padre::Constant::PORTABLE;
package Padre::Config;

sub $name {
	my \$config = \$_[0]->[$store];
	if ( exists \$config->{$name} and -e \$config->{$name} ) {
		return \$config->{$name};
	}
	return \$DEFAULT{$name};
}
END_PERL

	# Auto-translating accessors for Portable mode
	return <<"END_PERL";
package Padre::Config;

use Padre::Portable ();

sub $name {
	my \$config = \$_[0]->[$store];
	my \$path   = ( exists \$config->{$name} and -e \$config->{$name} )
		? \$config->{$name}
		: \$DEFAULT{$name};
	return Padre::Portable::thaw(\$path);
}
END_PERL
}





#####################################################################
# Support Functions

sub _TYPE {
	return !!( defined $_[0] and not ref $_[0] and $_[0] =~ /^[0-4]\z/ );
}

sub _STORE {
	return !!( defined $_[0] and not ref $_[0] and $_[0] =~ /^[0-2]\z/ );
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

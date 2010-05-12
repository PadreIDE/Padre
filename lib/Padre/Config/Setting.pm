package Padre::Config::Setting;

# Simple data class for a configuration setting

use 5.008;
use strict;
use warnings;
use Carp            ();
use File::Spec      ();
use Params::Util    ();
use Padre::Constant ();

our $VERSION = '0.61';

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
			apply
			}
	],
};

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Param checking
	unless ( $self->name ) {
		Carp::croak("Missing or invalid name");
	}
	unless ( _TYPE( $self->type ) ) {
		Carp::croak("Missing or invalid type for setting $self->{name}");
	}
	unless ( _STORE( $self->store ) ) {
		Carp::croak("Missing or invalid store for setting $self->{name}");
	}
	unless ( exists $self->{default} ) {
		Carp::croak("Missing or invalid default for setting $self->{name}");
	}

	# It is illegal to store paths in the human config
	if (    $self->type == Padre::Constant::PATH
		and $self->store == Padre::Constant::HUMAN )
	{
		Carp::croak("PATH values must only be placed in the HOST store");
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

	# Vanilla code for everything other than PATH entries
	return <<"END_PERL" unless $self->type == Padre::Constant::PATH;
package Padre::Config;

sub $name {
	my \$config = \$_[0]->[$store];
	return \$config->{$name} if exists \$config->{$name};
	return \$DEFAULT{$name};
}
END_PERL

	# Literal paths for HOST values
	# NOTE: This will need to change if we want to support Portable.pm
	return <<"END_PERL" unless $store == Padre::Constant::PROJECT;
package Padre::Config;

sub $name {
	my \$config = \$_[0]->[$store];
	if ( exists \$config->{$name} and -e \$config->{$name} ) {
		return \$config->{$name};
	}
	return \$DEFAULT{$name};
}
END_PERL

	# Relative paths for project-specific paths
	return <<"END_PERL";
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

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

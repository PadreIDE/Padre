package Padre::PluginHandle;

use 5.008;
use strict;
use warnings;
use Carp         'croak';
use Params::Util qw{_IDENTIFIER _CLASS _INSTANCE};

our $VERSION = '0.25';

use overload
	'bool'     => sub { 1 },
	'""'       => 'name',
	'fallback' => 0;

use Class::XSAccessor
	getters => {
		name   => 'name',
		class  => 'class',
		object => 'object',
		errstr => 'errstr',
	};





#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = bless { @_, status => 'unloaded' }, $class;

	# Check params
	unless ( _IDENTIFIER($self->name) ) {
		croak("Missing or invalid name param for Padre::PluginHandle");
	}
	unless ( _CLASS($self->class) ) {
		croak("Missing or invalid class param for Padre::PluginHandle");
	}
	if ( defined $self->object and not _INSTANCE($self->object, $self->class) ) {
		croak("Invalid object param for Padre::PluginHandle");
	}
	unless ( _STATUS($self->status) ) {
		croak("Missing or invalid status param for Padre::PluginHandle");
	}

	return $self;
}





#####################################################################
# Status Methods

sub status {
	my $self = shift;
	if ( @_ ) {
		unless ( _STATUS($_[0]) ) {
			croak("Invalid PluginHandle status '$_[0]'");
		}
		$self->{status} = $_[0];
	}
	return $self->{status};
}

sub error {
	$_[0]->{status} eq 'error';
}

sub unloaded {
	$_[0]->{status} eq 'unloaded';
}

sub loaded {
	$_[0]->{status} eq 'loaded';
}

sub incompatible {
	$_[0]->{status} eq 'incompatible';
}

sub disabled {
	$_[0]->{status} eq 'disabled';
}

sub enabled {
	$_[0]->{status} eq 'enabled';
}

sub can_enable {
	$_[0]->{status} eq 'loaded'
	or
	$_[0]->{status} eq 'disabled'
}

sub can_disable {
	$_[0]->{status} eq 'enabled';
}

sub can_editor {
	$_[0]->{status} eq 'enabled'
	and
	$_[0]->{object}->can('editor_enable')
}





######################################################################
# Interface Methods

sub plugin_name {
	my $self   = shift;
	my $object = $self->object;
	if ( $object and $object->can('plugin_name') ) {
		return $object->plugin_name;
	} else {
		return $self->name;
	}
}

sub version {
	my $self   = shift;
	my $object = $self->object;
	if ( $object ) {
		return $object->VERSION;
	} else {
		return '???';
	}
}





######################################################################
# Pass-Through Methods

sub enable {
	my $self = shift;
	unless ( $self->can_enable ) {
		croak("Cannot enable plugin '$self'");
	}

	# Call the enable method for the object
	eval {
		$self->object->plugin_enable;
	};
	if ( $@ ) {
		# Crashed during plugin enable
		$self->status('error');
		warn $@;
		return 0;
	}

	# If the plugin defines document types, register them
	my @documents = $self->object->registered_documents;
	if ( @documents ) {
		Class::Autouse->load('Padre::Document');
	}
	while ( @documents ) {
		my $type  = shift @documents;
		my $class = shift @documents;
		$Padre::Document::MIME_CLASS{$type} = $class;
	}

	# Update the status
	$self->status('enabled');

	return 1;
}

sub disable {
	my $self = shift;
	unless ( $self->can_disable ) {
		croak("Cannot disable plugin '$self'");
	}

	# If the plugin defines document types, deregister them
	my @documents = $self->object->registered_documents;
	while ( @documents ) {
		my $type  = shift @documents;
		my $class = shift @documents;
		delete $Padre::Document::MIME_CLASS{$type};
	}

	# Call the plugin's own disable method
	eval {
		$self->object->plugin_disable;
	};
	if ( $@ ) {
		# Crashed during plugin disable
		$self->status('error');
		return 1;
	}

	# Update the status
	$self->status('disabled');

	return 0;
}





######################################################################
# Support Methods

sub _STATUS {
	(
		defined $_[0]
		and
		! ref $_[0]
		and +{
			error        => 1,
			unloaded     => 1,
			loaded       => 1,
			incompatible => 1,
			disabled     => 1,
			enabled      => 1,
		}->{$_[0]}
	) ? $_[0] : undef;
}

1;

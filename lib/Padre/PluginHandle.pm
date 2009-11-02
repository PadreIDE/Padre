package Padre::PluginHandle;

use 5.008;
use strict;
use warnings;
use Carp           ();
use Padre::Current ();
use Padre::Locale  ();
use Params::Util qw{ _STRING _IDENTIFIER _CLASS _INSTANCE };

our $VERSION = '0.49';

use overload
	'bool' => sub () {1},
	'""' => 'plugin_name',
	'fallback' => 0;

use Class::XSAccessor getters => {
	class  => 'class',
	object => 'object',
	},
	accessors => {
	errstr => 'errstr',
	};





#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self  = bless {
		@_,
		status => 'unloaded',
		errstr => '',
	}, $class;

	# Check params
	if ( exists $self->{name} ) {
		Carp::confess("PluginHandle->name should no longer be used (foo)");
	}
	unless ( _CLASS( $self->class ) ) {
		Carp::croak("Missing or invalid class param for Padre::PluginHandle");
	}
	if ( defined $self->object and not _INSTANCE( $self->object, $self->class ) ) {
		Carp::croak("Invalid object param for Padre::PluginHandle");
	}
	unless ( _STATUS( $self->status ) ) {
		Carp::croak("Missing or invalid status param for Padre::PluginHandle");
	}

	return $self;
}





#####################################################################
# Status Methods

sub locale_prefix {
	my $self   = shift;
	my $string = $self->class;
	$string =~ s/::/__/g;
	return $string;
}

sub status {
	my $self = shift;
	if (@_) {
		unless ( _STATUS( $_[0] ) ) {
			Carp::croak("Invalid PluginHandle status '$_[0]'");
		}
		$self->{status} = $_[0];
	}
	return $self->{status};
}

sub status_localized {
	my ($self) = @_;

	# we're forced to have a hash of translation so that gettext
	# tools can extract those to be localized.
	my %translation = (
		error        => Wx::gettext('error'),
		unloaded     => Wx::gettext('unloaded'),
		loaded       => Wx::gettext('loaded'),
		incompatible => Wx::gettext('incompatible'),
		disabled     => Wx::gettext('disabled'),
		enabled      => Wx::gettext('enabled'),
	);
	return $translation{ $self->{status} };
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
		or $_[0]->{status} eq 'disabled';
}

sub can_disable {
	$_[0]->{status} eq 'enabled';
}

sub can_editor {
	$_[0]->{status} eq 'enabled'
		and $_[0]->{object}->can('editor_enable');
}





######################################################################
# Interface Methods

sub plugin_icon {
	my $self = shift;
	my $icon = eval { $self->class->plugin_icon; };
	if ( _INSTANCE( $icon, 'Wx::Bitmap' ) ) {
		return $icon;
	} else {
		return;
	}
}

sub plugin_name {
	my $self   = shift;
	my $object = $self->object;
	if ( $object and $object->can('plugin_name') ) {
		return $object->plugin_name;
	} else {
		return $self->class;
	}
}

sub version {
	my $self   = shift;
	my $object = $self->object;
	if ($object) {
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
		Carp::croak("Cannot enable plugin '$self'");
	}

	# add the plugin catalog to the locale
	my $locale = Padre::Current->main->{locale};
	my $code   = Padre::Locale::rfc4646();
	my $prefix = $self->locale_prefix;
	$locale->AddCatalog("$prefix-$code");

	# Call the enable method for the object
	eval { $self->object->plugin_enable; };
	if ($@) {

		# Crashed during plugin enable
		$self->status('error');
		$self->errstr(
			sprintf(
				Wx::gettext("Failed to enable plugin '%s': %s"),
				$self->class,
				$@,
			)
		);
		return 0;
	}

	# If the plugin defines document types, register them
	my @documents = $self->object->registered_documents;
	if (@documents) {
		require Padre::MimeTypes;
	}
	while (@documents) {
		my $type  = shift @documents;
		my $class = shift @documents;
		Padre::MimeTypes->add_mime_class( $type, $class );
	}

	# TODO remove these when plugin is disabled (and make sure files
	# are not highlighted with this any more)
	if ( my @highlighters = $self->object->provided_highlighters ) {
		require Padre::MimeTypes;
		foreach my $h (@highlighters) {
			if ( ref $h ne 'ARRAY' ) {
				warn "Not array reference '$h'\n";
				next;
			}
			Padre::MimeTypes->add_highlighter(@$h);
		}
	}

	# TODO remove these when plugin is disabled (and make sure files
	# are not highlighted with this any more)
	if ( my %mime_types = $self->object->highlighting_mime_types ) {
		require Padre::MimeTypes;
		foreach my $module ( keys %mime_types ) {

			# TODO sanity check here too.
			foreach my $mime_type ( @{ $mime_types{$module} } ) {
				Padre::MimeTypes->add_highlighter_to_mime_type( $mime_type, $module );
			}
		}
	}

	# If the plugin has a hook for the context menu, cache it
	if ( $self->object->can('event_on_context_menu') ) {
		my $cxt_menu_hook_cache = Padre->ide->plugin_manager->plugins_with_context_menu;
		$cxt_menu_hook_cache->{ $self->class } = 1;
	}

	# Update the status
	$self->status('enabled');
	$self->errstr('');

	return 1;
}

sub disable {
	my $self = shift;
	unless ( $self->can_disable ) {
		Carp::croak("Cannot disable plugin '$self'");
	}

	# If the plugin defines document types, deregister them
	my @documents = $self->object->registered_documents;
	while (@documents) {
		my $type  = shift @documents;
		my $class = shift @documents;
		Padre::MimeTypes->remove_mime_class($type);
	}

	# Call the plugin's own disable method
	eval { $self->object->plugin_disable; };
	if ($@) {

		# Crashed during plugin disable
		$self->status('error');
		$self->errstr(
			sprintf(
				Wx::gettext("Failed to disable plugin '%s': %s"),
				$self->class,
				$@,
			)
		);
		return 1;
	}

	# If the plugin has a hook for the context menu, cache it
	my $cxt_menu_hook_cache = Padre->ide->plugin_manager->plugins_with_context_menu;
	delete $cxt_menu_hook_cache->{ $self->class };

	# Update the status
	$self->status('disabled');
	$self->errstr('');

	return 0;
}





######################################################################
# Support Methods

sub _STATUS {
	_STRING( $_[0] ) or return;
	return {
		error        => 1,
		unloaded     => 1,
		loaded       => 1,
		incompatible => 1,
		disabled     => 1,
		enabled      => 1,
	}->{ $_[0] };
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::PluginHandle;

use 5.008;
use strict;
use warnings;
use Carp           ();
use Params::Util   ();
use Padre::Current ();
use Padre::Locale  ();

our $VERSION = '0.90';

use overload
	'bool' => sub () {1},
	'""' => 'plugin_name',
	'fallback' => 0;

use Class::XSAccessor {
	getters => {
		class  => 'class',
		object => 'object',
	},
	accessors => {
		errstr => 'errstr',
	},
};





#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	$self->{status} = 'unloaded';
	$self->{errstr} = '';

	# Check params
	if ( exists $self->{name} ) {
		Carp::confess("PluginHandle->name should no longer be used (foo)");
	}
	unless ( Params::Util::_CLASS( $self->class ) ) {
		Carp::croak("Missing or invalid class param for Padre::PluginHandle");
	}
	if ( defined $self->object and not Params::Util::_INSTANCE( $self->object, $self->class ) ) {
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
	if ( Params::Util::_INSTANCE( $icon, 'Wx::Bitmap' ) ) {
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

	# Prefer the version from the loaded plugin
	return $object->VERSION if $object;

	# Intuit the version by reading the actual file
	require Class::Inspector;
	my $file = Class::Inspector->resolved_filename( $self->class );
	if ($file) {
		require Padre::Util;
		my $version = Padre::Util::parse_variable( $file, 'VERSION' );
		return $version if $version;
	}

	return '???';
}





######################################################################
# Pass-Through Methods

sub enable {
	my $self = shift;
	unless ( $self->can_enable ) {
		Carp::croak("Cannot enable plug-in '$self'");
	}

	# add the plugin catalog to the locale
	my $locale  = Padre::Current->main->{locale};
	my $code    = Padre::Locale::rfc4646();
	my $prefix  = $self->locale_prefix;
	my $manager = Padre->ide->plugin_manager;
	$locale->AddCatalog("$prefix-$code");

	# Call the enable method for the object
	eval { $self->object->plugin_enable; };
	if ($@) {

		# Crashed during plugin enable
		$self->status('error');
		$self->errstr(
			sprintf(
				Wx::gettext("Failed to enable plug-in '%s': %s"),
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

	# TO DO remove these when plugin is disabled (and make sure files
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

	# TO DO remove these when plugin is disabled (and make sure files
	# are not highlighted with this any more)
	if ( my %mime_types = $self->object->highlighting_mime_types ) {
		require Padre::MimeTypes;
		foreach my $module ( keys %mime_types ) {

			# TO DO sanity check here too.
			foreach my $mime_type ( @{ $mime_types{$module} } ) {
				Padre::MimeTypes->add_highlighter_to_mime_type( $mime_type, $module );
			}
		}
	}

	# If the plugin has a hook for the context menu, cache it
	if ( $self->object->can('event_on_context_menu') ) {
		my $cxt_menu_hook_cache = $manager->plugins_with_context_menu;
		$cxt_menu_hook_cache->{ $self->class } = 1;
	}

	# Look for Padre hooks
	if ( $self->object->can('padre_hooks') ) {
		my $hooks = $self->object->padre_hooks;

		if ( ref($hooks) ne 'HASH' ) {
			$manager->main->error(
				sprintf(
					Wx::gettext('Plugin %s returned %s instead of a hook list on ->padre_hooks'), $self->class, $hooks
				)
			);
			return;
		}

		for my $hookname ( keys( %{$hooks} ) ) {

			if ( !$Padre::PluginManager::PADRE_HOOKS{$hookname} ) {
				$manager->main->error(
					sprintf( Wx::gettext('Plugin %s tried to register invalid hook %s'), $self->class, $hookname ) );
				next;
			}

			for my $hook ( ( ref( $hooks->{$hookname} ) eq 'ARRAY' ) ? @{ $hooks->{$hookname} } : $hooks->{$hookname} )
			{
				if ( ref($hook) ne 'CODE' ) {
					$manager->main->error(
						sprintf( Wx::gettext('Plugin %s tried to register non-CODE hook %s'), $self->class, $hookname )
					);
					next;
				}
				push @{ $manager->{hooks}->{$hookname} }, [ $self->object, $hook ];
			}
		}
	}

	# Update the status
	$self->status('enabled');
	$self->errstr('');

	return 1;
}

sub disable {
	my $self = shift;
	unless ( $self->can_disable ) {
		Carp::croak("Cannot disable plug-in '$self'");
	}

	# NOTE: Horribly violates encapsulation
	my $manager = Padre->ide->plugin_manager;

	# If the plugin defines document types, deregister them
	my @documents = $self->object->registered_documents;
	while (@documents) {
		my $type  = shift @documents;
		my $class = shift @documents;
		Padre::MimeTypes->reset_mime_class($type);
	}

	# Call the plugin's own disable method
	eval { $self->object->plugin_disable; };
	if ($@) {

		# Crashed during plugin disable
		$self->status('error');
		$self->errstr(
			sprintf(
				Wx::gettext("Failed to disable plug-in '%s': %s"),
				$self->class,
				$@,
			)
		);
		return 1;
	}

	# If the plugin has a hook for the context menu, cache it
	my $cxt_menu_hook_cache = $manager->plugins_with_context_menu;
	delete $cxt_menu_hook_cache->{ $self->class };

	# Remove hooks
	# The ->padre_hooks method may not return constant values, scanning the hook
	# tree is much safer than removing the hooks reported _now_
	for my $hookname ( keys( %{ $manager->{hooks} } ) ) {
		my @new_list;
		for my $hook ( @{ $manager->{hooks}->{$hookname} } ) {
			next if $hook->[0] eq $self->object;
			push @new_list, $hook;
		}
		$self->{hooks}->{$hookname} = \@new_list;
	}

	# Update the status
	$self->status('disabled');
	$self->errstr('');

	# Save the last version we successfully enabled to the database


	return 0;
}





######################################################################
# Support Methods

sub _STATUS {
	Params::Util::_STRING( $_[0] ) or return;
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

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

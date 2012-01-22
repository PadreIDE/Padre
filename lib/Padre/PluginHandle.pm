package Padre::PluginHandle;

use 5.008;
use strict;
use warnings;
use Carp           ();
use Params::Util   ();
use Padre::Util    ();
use Padre::Current ();
use Padre::Locale::T;

our $VERSION = '0.94';

use Class::XSAccessor {
	getters => {
		class  => 'class',
		db     => 'db',
		plugin => 'plugin',
	},
};

my %STATUS = (
	error        => _T('Error'),
	unloaded     => _T('Unloaded'),
	loaded       => _T('Loaded'),
	incompatible => _T('Incompatible'),
	disabled     => _T('Disabled'),
	enabled      => _T('Enabled'),
);





#####################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $self = bless {
		@_,
		status => 'unloaded',
		errstr => [ '' ],
	}, $class;

	# Check params
	if ( exists $self->{name} ) {
		Carp::confess("PluginHandle->name should no longer be used (foo)");
	}
	my $module = $self->class;
	my $plugin = $self->plugin;
	unless ( Params::Util::_CLASS($module) ) {
		Carp::croak("Missing or invalid class param for Padre::PluginHandle");
	}
	if ( defined $plugin and not Params::Util::_INSTANCE( $plugin, $module ) ) {
		Carp::croak("Invalid plugin param for Padre::PluginHandle");
	}
	unless ( _STATUS( $self->status ) ) {
		Carp::croak("Missing or invalid status param for Padre::PluginHandle");
	}

	# Load or create the database configuration for the plugin
	unless ( Params::Util::_INSTANCE($self->db, 'Padre::DB::Plugin') ) {
		local $@;
		require Padre::DB;
		$self->{db} = eval {
			Padre::DB::Plugin->load($module);
		};
		$self->{db} ||= Padre::DB::Plugin->create(
			name => $module,

			# Track the last version of the plugin that we were
			# able to successfully enable (nothing to start with)
			version => undef,

			# Having undef here means no preference yet
			enabled => undef,
			config  => undef,
		);
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
	my $self = shift;
	my $text = $STATUS{ $self->{status} } or return;
	return Wx::gettext($text);
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
		and $_[0]->{plugin}->can('editor_enable');
}

sub can_context {
	$_[0]->{status} eq 'enabled'
	and
	$_[0]->{plugin}->can('event_on_context_menu')
}

sub errstr {
	my $self = shift;

	# Set the error string
	if ( @_ ) {
		$self->{errstr} = [ @_ ];
		return 1;
	}

	# Delay the translating sprintf and rerun each time,
	# so that plugin errors can appear in the currently active language
	# instead of the language at the time of the error.
	my @copy = @{ $self->{errstr} };
	my $text = Wx::gettext(shift @copy);
	return sprintf($text, @copy);
}





######################################################################
# Interface Methods

# Wrap any can call in an eval as the plugin might have a custom
# can method and we need to be paranoid around plugins.
sub plugin_can {
	my $self   = shift;
	my $plugin = $self->{plugin} or return undef;

	# Ignore errors and flatten to a boolean
	local $@;
	return !! eval {
		$plugin->can(shift)
	};
}

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
	my $self = shift;
	if ( $self->plugin_can('plugin_name') ) {
		local $@;
		return scalar eval {
			$self->plugin->plugin_name
		};
	} else {
		return $self->class;
	}
}

sub plugin_version {
	my $self = shift;

	# Prefer the version from the loaded plugin
	if ( $self->plugin_can('VERSION') ) {
		local $@;
		my $rv = eval {
			$self->plugin->VERSION;
		};
		return $rv;
	}

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

# Wrapper over the void context call to preferences
sub plugin_preferences {
	my $self = shift;
	if ( $self->plugin_can('plugin_preferences') ) {
		local $@;
		eval {
			$self->plugin->plugin_preferences
		};
	}
}





######################################################################
# Pass-Through Methods

sub enable {
	my $self = shift;
	unless ( $self->can_enable ) {
		Carp::croak("Cannot enable plug-in '$self'");
	}

	# Add the plugin catalog to the locale
	require Padre::Locale;
	my $prefix  = $self->locale_prefix;
	my $code    = Padre::Locale::rfc4646();
	my $current = $self->current;
	my $main    = $current->main;
	$main->{locale}->AddCatalog("$prefix-$code");

	# Call the enable method for the object
	eval {
		$self->plugin->plugin_enable;
	};
	if ($@) {

		# Crashed during plugin enable
		$self->status('error');
		$self->errstr(
			_T("Failed to enable plug-in '%s': %s"),
			$self->class,
			$@,
		);
		return 0;
	}

	# If the plugin defines document types, register them.
	# Skip document registration on error.
	my @documents = eval {
		$self->plugin->registered_documents;
	};
	if ( $@ ) {
		# Crashed during document registration
		$self->status('error');
		$self->errstr(
			_T("Failed to enable plug-in '%s': %s"),
			$self->class,
			$@,
		);
		return 0;
	}
	while (@documents) {
		my $type  = shift @documents;
		my $class = shift @documents;
		require Padre::MIME;
		Padre::MIME->find($type)->plugin($class);
	}

	# If the plugin defines syntax highlighters, register them.
	# Skip highlighter registration on error.
	# TO DO remove these when plugin is disabled (and make sure files
	# are not highlighted with this any more)
	my @highlighters = eval {
		$self->plugin->registered_highlighters;
	};
	if ( $@ ) {
		# Crashed during highlighter registration
		$self->status('error');
		$self->errstr(
			_T("Failed to enable plug-in '%s': %s"),
			$self->class,
			$@,
		);
		return 0;
	}
	while ( @highlighters ) {
		my $module = shift @highlighters;
		my $params = shift @highlighters;
		require Padre::Wx::Scintilla;
		Padre::Wx::Scintilla->add_highlighter( $module, $params );
	}

	# Look for Padre hooks
	if ( $self->plugin->can('padre_hooks') ) {
		my $hooks = eval {
			$self->plugin->padre_hooks;
		};
		if ( ref($hooks) ne 'HASH' ) {
			$main->error(
				sprintf(
					Wx::gettext('Plugin %s returned %s instead of a hook list on ->padre_hooks'),
					$self->class,
					$hooks,
				)
			);
			return;
		}

		my $manager = $current->ide->plugin_manager;
		for my $hookname ( keys( %{$hooks} ) ) {

			if ( !$Padre::PluginManager::PADRE_HOOKS{$hookname} ) {
				$main->error(
					sprintf( Wx::gettext('Plugin %s tried to register invalid hook %s'), $self->class, $hookname ) );
				next;
			}

			for my $hook ( ( ref( $hooks->{$hookname} ) eq 'ARRAY' ) ? @{ $hooks->{$hookname} } : $hooks->{$hookname} )
			{
				if ( ref($hook) ne 'CODE' ) {
					$main->error(
						sprintf( Wx::gettext('Plugin %s tried to register non-CODE hook %s'), $self->class, $hookname )
					);
					next;
				}
				push @{ $manager->{hooks}->{$hookname} }, [ $self->plugin, $hook ];
			}
		}
	}

	# Update the last-enabled version each time it is enabled
	$self->update( version => $self->plugin_version );

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

	# If the plugin defines document types, deregister them
	my @documents = $self->plugin->registered_documents;
	while (@documents) {
		my $type  = shift @documents;
		my $class = shift @documents;
		Padre::MIME->find($type)->reset;
	}

	# Call the plugin's own disable method
	eval { $self->plugin->plugin_disable; };
	if ($@) {

		# Crashed during plugin disable
		$self->status('error');
		$self->errstr(
			_T("Failed to disable plug-in '%s': %s"),
			$self->class,
			$@,
		);
		return 1;
	}

	# Remove hooks
	# The ->padre_hooks method may not return constant values, scanning the hook
	# tree is much safer than removing the hooks reported _now_
	# NOTE: Horribly violates encapsulation
	my $manager = $self->current->ide->plugin_manager;
	for my $hookname ( keys( %{ $manager->{hooks} } ) ) {
		my @new_list;
		for my $hook ( @{ $manager->{hooks}->{$hookname} } ) {
			next if $hook->[0] eq $self->plugin;
			push @new_list, $hook;
		}
		$manager->{hooks}->{$hookname} = \@new_list;
	}

	# Update the status
	$self->status('disabled');
	$self->errstr('');

	return 0;
}

sub unload {
	require Padre::Unload;
	Padre::Unload::unload( $_[0]->class );
}

sub update {
	shift->db->update(@_);
}





######################################################################
# Support Methods

sub current {
	if ( $_[0]->{plugin} ) {
		return $_[0]->{plugin}->current;
	} else {
		return Padre::Current->new;
	}
}

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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

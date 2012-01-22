package Padre::Wx::Action;

use 5.008;
use strict;
use warnings;
use Params::Util    ();
use Padre::Config   ();
use Padre::Constant ();
use Padre::Wx       ();

our $VERSION = '0.94';

# Generate faster accessors
use Class::XSAccessor {
	getters => {
		id            => 'id',
		name          => 'name',
		icon          => 'icon',
		menu_event    => 'menu_event',
		menu_method   => 'menu_method',
		toolbar_event => 'toolbar_event',
		toolbar_icon  => 'toolbar',
	},
	accessors => {
		shortcut => 'shortcut',
	},
};





#####################################################################
# Constructor

sub new {
	my $class   = shift;
	my $ide     = Padre->ide;
	my $config  = $ide->config;
	my $actions = $ide->actions;

	# Create the raw object
	my $self = bless {
		id       => -1,
		shortcut => '',
		@_,
	}, $class;

	# Check params
	my $name = $self->{name};
	unless ( defined $name and length $name ) {
		die join( ',', caller ) . ' tried to create an action without name';
	}
	if ( $name =~ /^menu\./ ) {

		# The menu prefix is dedicated to menus and must not be used by actions
		die join( ',', caller ) . ' tried to create an action with name prefix menu';
	}
	if ( $actions->{$name} and $name !~ /^view\.language\./ ) {
		warn "Found a duplicate action '$name'\n";
	}
	if ( defined $self->{need} and not Params::Util::_CODE( $self->{need} ) ) {
		die "Custom action 'need' param must be a CODE reference";
	}

	# Menu events are handled by Padre::Wx::Action, the real events
	# should go to {event}!
	if ( defined $self->{menu_event} ) {
		$self->add_event( $self->{menu_event} );
		$self->{menu_event} = sub {
			Padre->ide->actions->{$name}->_event(@_);
		};
	}
	$self->{queue_event} ||= $self->{menu_event};

	# Create shortcut setting for the action
	my $shortcut = $self->shortcut;
	my $setting  = $self->shortcut_setting;
	unless ( $config->can($setting) ) {
		$config->setting(
			name    => $setting,
			type    => Padre::Constant::ASCII,
			store   => Padre::Constant::HUMAN,
			default => $shortcut,
		);
	}

	# Load the shortcut from its configuration setting
	my $config_shortcut = eval '$config->' . $setting;
	warn "$@\n" if $@;
	$shortcut = $config_shortcut;
	$self->shortcut($shortcut);

	# Validate the shortcut
	if ($shortcut) {
		my $shortcuts = $ide->shortcuts;
		if ( exists $shortcuts->{$shortcut} ) {
			warn "Found a duplicate shortcut '$shortcut' with " . $shortcuts->{$shortcut}->name . " for '$name'\n";
		} else {
			$shortcuts->{$shortcut} = $self;
		}
	}

	# Save the action
	$actions->{$name} = $self;

	return $self;
}

# Translate on the fly when requested
sub label {
	return defined $_[0]->{label} ? Wx::gettext( $_[0]->{label} ) : Wx::gettext('(Undefined)');
}

# A label textual data without any strange menu characters
sub label_text {
	my $self  = shift;
	my $label = $self->label;
	$label =~ s/\&//g;
	return $label;
}

# Translate on the fly when requested
sub comment {
	Wx::gettext( $_[0]->{comment} );
}

# Label for use with menu (with shortcut)
# In some cases ( http://padre.perlide.org/trac/ticket/485 )
# if a stock menu item also gets a short-cut it stops working
# hence we add the shortcut only if id == -1 indicating this was not a
# stock menu item
# The case of F12 is a special case as it uses a stock icon that does not have
# a shortcut in itself so we added one.
# (BTW Print does not have a shortcut either)
sub label_menu {
	my $self  = shift;
	my $label = $self->label;

	my $shortcut = $self->shortcut;

	if ($shortcut
		and (  ( $shortcut eq 'F12' )
			or ( $self->id == -1 or Padre::Constant::WIN32() or Padre::Constant::MAC() ) )
		)
	{
		$label .= "\t" . $shortcut;
	}
	return $label;
}

sub shortcut_setting {
	my $self = shift;

	my $setting = 'keyboard_shortcut_' . $self->name;
	$setting =~ s/\W/_/g; # setting names must be valid subroutine names

	return $setting;
}

# Add an event to an action:
sub add_event {
	my $self      = shift;
	my $new_event = shift;

	if ( ref($new_event) ne 'CODE' ) {
		warn 'Error: ' . join( ',', caller ) . ' tried to add "' . $new_event . '" which is no CODE-ref!';
		return 0;
	}

	if ( ref( $self->{event} ) eq 'ARRAY' ) {
		push @{ $self->{event} }, $new_event;
	} elsif ( !defined( $self->{event} ) ) {
		$self->{event} = $new_event;
	} else {
		$self->{event} = [ $self->{event}, $new_event ];
	}

	return 1;
}

sub _event {
	my $self = shift;
	my @args = @_;

	return 1 unless defined( $self->{event} );

	if ( ref( $self->{event} ) eq 'CODE' ) {
		&{ $self->{event} }(@args);
	} elsif ( ref( $self->{event} ) eq 'ARRAY' ) {
		foreach my $item ( @{ $self->{event} } ) {
			next if ref($item) ne 'CODE'; # TO DO: Catch error and source (Ticket #666)
			&{$item}(@args);
		}
	} else {
		warn 'Expected array or code reference but got: ' . $self->{event};
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

__END__

=pod

=head1 NAME

Padre::Wx::Action - Padre Action Object

=head1 SYNOPSIS

  my $action = Padre::Wx::Action->new(
      name       => 'file.save',
      label      => 'Save',
      comment    => 'Saves the current file to disk',
      icon       => '...',
      shortcut   => 'Ctrl-S',
      menu_event => sub { },
  );

=head1 DESCRIPTION

This is the base class for the Padre Action API.

=head1 KEYS

Each module is constructed using a number of keys. While only the name is
technically required there are few reasons for actions which lack a label or
menu_event.

The keys are listed here in the order they usually appear.

=head2 name

Each action requires an unique name which is used to reference and call it.

The name usually has the syntax

  group.action

Both group and action should only contain \w+ chars.

=head2 label

Text which is shown in menus and allows the user to see what this action does.

Remember to use L<Wx::gettext> to make this translatable.

=head2 need_editor

This action should only be enabled/shown if there is a open editor window with
a (potentially unsaved) document in it.

The action may be called anyway even if there is no editor (all documents
closed), but it shouldn't.

Set to a value of 1 to use it.

=head2 need_file

This action should only be enabled/shown if the current document has a file name
(meaning there is a copy on disk which may be older than the in-memory
document).

The action may be called anyway even if there is no file name for the current
document, but it shouldn't.

Set to a value of 1 to use it.

=head2 need_modified

This action should only be enabled/shown if the current document has either
been modified after the last save or was never saved on disk at all.

The action may be called anyway even if the file is up-to-date with the
in-memory document, but it shouldn't.

Set to a value of 1 to use it.

=head2 need_selection

This action should only be enabled/shown if there is some text selected within
the current document.

The action may be called anyway even if nothing is selected, but it shouldn't.

Set to a value of 1 to use it.

=head2 need

Expected to contain a CODE reference which returns either true or false.

If the code returns true, the action should be enabled/shown, otherwise it
shouldn't, usually because it won't make sense to use this action without
whatever_is_checked_by_the_code. (For example, UNDO can't be used if there
was no change which could be undone.)

The CODE receives a list of objects which should help with the decision:

  config      Contains the current configuration object
  editor      The current editor object
  document    The current document object
  main        The main Wx object

A typical sub for handling would look like this:

  need => sub {
      my $current = shift;
      my $editor  = $current->editor or return 0;
      return $editor->CanUndo;
  },

Use this with caution! As this function is called very often there are few
to no checks and if this isn't a CODE reference, Padre may crash at all or
get very slow if your CODE is inefficient and requires a lot of processing
time.

=head2 comment

A comment (longer than label) which could be used in lists. It should contain
a short description of what this action does.

Remember to use L<Wx::gettext> to make this translatable.

=head2 icon

If there is an icon for this action, specify it here.

=head2 shortcut

The shortcut may be set by the user. This key sets the default shortcut to
be used if there is no user-defined value.

=head2 menu_event

This is expected to contain a CODE reference which does the job of this action
or an ARRAY reference of CODE references which are executed in order.

=head1 METHODS

=head2 new

A default constructor for action objects.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

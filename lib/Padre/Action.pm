package Padre::Action;

use 5.008;
use strict;
use warnings;

use Padre::Constant         ();
use Padre::Action::Help     ();
use Padre::Action::Perl     ();
use Padre::Action::Plugins  ();
use Padre::Action::Refactor ();
use Padre::Action::Run      ();
use Padre::Action::Search   ();

our $VERSION = '0.48';

# Generate faster accessors
use Class::XSAccessor getters => {
	id            => 'id',
	icon          => 'icon',
	name          => 'name',
	label         => 'label',
	shortcut      => 'shortcut',
	menu_event    => 'menu_event',
	toolbar_event => 'toolbar_event',
	menu_method   => 'menu_method',
};



#####################################################################
# Functions

# This sub calls all the other files which actually create the actions
sub create {
	my $main = shift;

	Padre::Action::Help->new($main);
	Padre::Action::Perl->new($main);
	Padre::Action::Plugins->new($main);
	Padre::Action::Refactor->new($main);
	Padre::Action::Run->new($main);
	Padre::Action::Search->new($main);


	# This is made for usage by the developers to create a complete
	# list of all actions used in Padre. It outputs some warnings
	# while dumping, but they're ignored for now as it should never
	# run within a productional copy.
	if ( $ENV{PADRE_EXPORT_ACTIONS} ) {
		require Data::Dumper;
		require File::Spec;
		$Data::Dumper::Purity = 1;
		open my $action_export_fh, '>', File::Spec->catfile( Padre::Constant::CONFIG_DIR, 'actions.dump' );
		print $action_export_fh Data::Dumper::Dumper( Padre->ide->actions );
		close $action_export_fh;
	}
}



#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;
	$self->{id} ||= -1;

	if ( ( !defined( $self->{name} ) ) or ( $self->{name} eq '' ) ) {
		warn join( ',', caller ) . " tried to create an action without name";
		return;
	}

	if ( defined( $self->{menu_event} ) ) {

		# Menu events are handled by Padre::Action, the real events
		# should go to {event}!
		$self->add_event( $self->{menu_event} );
		$self->{menu_event} =
			eval ' return sub { ' . "Padre->ide->actions->{'" . $self->{name} . "'}->_event(\@_);" . '};';
	}

	my $name     = $self->{name};
	my $shortcut = $self->{shortcut};

	my $actions = Padre->ide->actions;
	if ( $actions->{$name} ) {
		warn "Found a duplicate action '$name'\n";
	}

	if ($shortcut) {
		foreach my $n ( keys %$actions ) {
			my $a = $actions->{$n};
			next unless $a->shortcut;
			next unless $a->shortcut eq $shortcut;
			warn "Found a duplicate shortcut '$shortcut' with " . $a->name . " for '$name'\n";
			last;
		}
	}

	$actions->{ $self->{name} } = $self;

	return $self;
}

# A label textual data without any strange menu characters
sub label_text {
	my $self  = shift;
	my $label = $self->label;
	$label =~ s/\&//g;
	return $label;
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
	if ( $self->shortcut
		and ( ( $self->shortcut eq 'F12' ) or ( $self->id == -1 or Padre::Constant::WIN32() ) ) )
	{
		$label .= "\t" . $self->shortcut;
	}
	return $label;
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
		for my $item ( @{ $self->{event} } ) {
			next if ref($item) ne 'CODE'; # TODO: Catch error and source (Ticket #666)
			&{$item}(@args);
		}
	} else {
		warn 'Expected array or code reference but got: ' . $self->{event};
	}

	return 1;
}

#####################################################################
# Main Methods

=pod

=head1 NAME

Padre::Action - Padre Action Object

=head1 SYNOPSIS

  my $action = Padre::Action->new( 
    name       => 'file.save', 
    label      => 'Save', 
    comment    => 'Saves the current file to disk',
    icon       => '...', 
    shortcut   => 'CTRL-S', 
    menu_event => sub { },
  );

=head1 DESCRIPTION

This is the base class for the Padre Action API.

To be documented...

-- Ahmad M. Zawawi

=head1 KEYS

Each module is constructed using a number of keys. While only the name is
technicalls required there are few reasons for actions which lack a label or
menu_event.

The keys are listed here in the order they usually appear.

=head2 name

Each action requires an unique name which is used to reference and call it.

The name usually has the syntax

	group.action

Both group and action should only contain \w+ chars.

=head2 label

Text which is shown in menus and allows the user to see what this action does.

Remember to use Wx::gettext to make this translateable.

=head2 need_editor

This action should only be enabled/shown if there is a open editor window with
a (maybe unsafed) document in it.

The action may be called anyway even if there is no editor (all documents
closed), but it shouldn't.

Set to a value of 1 to use it.

=head2 need_file

This action should only be enabled/shown if the current document has a filename
(meaning there is a copy on disk which may be older than the in-memory
document).

The action may be called anyway even if there is no filename for the current
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
	config		contains the current configuration object
	editor		the current editor object
	document	the current document object
	main		the main Wx object

A typical sub for handling would look like this:

	need => sub {
			my %objects = @_;
			return 0 if !defined( $objects{editor} );
			return $objects{editor}->CanUndo;
		},

Use this with caution! As this function is called very often there are few
to no checks and if this isn't a CODE reference, Padre may crash at all or
get very slow if your CODE is inefficient and requires a lot of processing
time.

=head2 comment

A comment (longer than label) which could be used in lists. It should contain
a short decription of what this action does.

Remember to use Wx::gettext to make this translateable.

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

A default contructor for action objects.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

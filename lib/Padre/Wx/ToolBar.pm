package Padre::Wx::ToolBar;

# Implements a toolbar with a small amount of extra intelligence.
# Please note that currently this toolbar class is ONLY suitable for
# use as the toolbar for the main window and is not reusable.

use 5.008;
use strict;
use warnings;
use Params::Util      ();
use Padre::Current    ();
use Padre::Wx         ();
use Padre::Wx::Icon   ();
use Padre::Wx::Editor ();
use Padre::Constant   ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::ToolBar
};

# NOTE: Something is wrong with dockable toolbars on Windows
#       so disable them for now.
use constant DOCKABLE => !Padre::Constant::WIN32;





######################################################################
# Construction

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = $main->config;

	# Prepare the style
	my $style = Wx::TB_HORIZONTAL | Wx::TB_FLAT | Wx::TB_NODIVIDER | Wx::BORDER_NONE;
	if ( DOCKABLE and not $config->main_lockinterface ) {
		$style = $style | Wx::TB_DOCKABLE;
	}

	# Create the parent Wx object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		$style,
		5050,
	);

	# Default icon size is 16x15 for Wx, to use the 16x16 GPL
	# icon sets we need to be SLIGHTLY bigger.
	$self->SetToolBitmapSize( Wx::Size->new( 16, 16 ) );

	# This is a very first step to create a customizable toolbar.
	# Actually there is no dialog for editing this parameter, if
	# anyone wants to change the toolbar, it needs to be done manuelly
	# within config.yml.
	my @tools = split /\;/, $config->main_toolbar_items;

	foreach my $item (@tools) {
		if ( $item eq '|' ) {
			$self->add_separator;

		} elsif ( $item =~ /^(.+?)\((.*)\)$/ ) {
			$self->add_tool_item(
				action => "$1",
				args   => split( /\,/, $2 ),
			);

		} elsif ( $item =~ /^(.+?)$/ ) {
			$self->add_tool_item(
				action => "$1",
			);

		} else {

			# Silently ignore bad toolbar elements (for now)
			# warn( 'Unknown toolbar item: ' . $item );
		}
	}

	return $self;
}





######################################################################
# Main Methods

# Because some tools may not work, we only want to draw the separator
# for real once we are absolutely sure there is a real tool after it.
sub add_separator {
	$_[0]->{separator} = 1;
}

# Add a tool item to the toolbar re-using Padre menu action name
sub add_tool_item {
	my $self = shift;
	my %args = @_;

	# Find the action, silently aborting if it is unusable
	my $actions = $self->ide->actions;
	my $action  = $actions->{ $args{action} } or return;
	my $icon    = $action->toolbar_icon or return;

	# Make sure the item list if initialised
	unless ( Params::Util::_HASH0( $self->{item_list} ) ) {
		$self->{item_list} = {};
	}

	# The ID code should be unique otherwise it can break the event
	# system. If set to -1 such as in the default call below,
	# it will override any previous item with that id.
	my $id = Wx::NewId();
	$self->{item_list}->{$id} = $action;

	# If there is a delayed separator, add it now
	if ( $self->{separator} ) {
		$self->AddSeparator;
		$self->{separator} = 0;
	}

	# Create the tool
	$self->AddTool(
		$id,
		'',
		Padre::Wx::Icon::find($icon),
		$action->label_text,
	);

	# Add the optional event hook
	Wx::Event::EVT_TOOL(
		$self->main,
		$id,
		$action->menu_event,
	);

	return $id;
}

sub refresh {
	my $self     = shift;
	my $current  = Padre::Current::_CURRENT(@_);
	my $editor   = $current->editor;
	my $document = $current->document;
	my $modified = ( defined $document and $document->is_modified );
	my $text     = defined Params::Util::_STRING( $current->text );
	my $file     = ( defined $document and defined $document->file and defined $document->file->filename );

	foreach my $item ( keys( %{ $self->{item_list} } ) ) {
		my $action = $self->{item_list}->{$item};
		if ( $action->{need_editor} and not $editor ) {
			$self->EnableTool( $item, 0 );

		} elsif ( $action->{need_file} and not $file ) {
			$self->EnableTool( $item, 0 );

		} elsif ( $action->{need_modified} and not $modified ) {
			$self->EnableTool( $item, 0 );

		} elsif ( $action->{need_selection} and not $text ) {
			$self->EnableTool( $item, 0 );

		} elsif ( $action->{need} and not $action->{need}->($current) ) {
			$self->EnableTool( $item, 0 );

		} else {
			$self->EnableTool( $item, 1 );
		}
	}

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

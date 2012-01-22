package Padre::Wx::FunctionList;

use 5.008005;
use strict;
use warnings;
use Carp                  ();
use Scalar::Util          ();
use Params::Util          ();
use Padre::Feature        ();
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::Panel
};





#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;

	# Create the parent panel which will contain the search and tree
	my $self = $class->SUPER::new(
		$panel,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	# Temporary store for the function list.
	$self->{model} = [];

	# Remember the last document we were looking at
	$self->{document} = '';

	# Create the search control
	$self->{search} = Wx::TextCtrl->new(
		$self, -1, '',
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_PROCESS_ENTER | Wx::SIMPLE_BORDER,
	);

	# Create the functions list
	$self->{list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
		Wx::LB_SINGLE | Wx::BORDER_NONE
	);

	# Create a sizer
	my $sizerv = Wx::BoxSizer->new(Wx::VERTICAL);
	my $sizerh = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$sizerv->Add( $self->{search}, 0, Wx::ALL | Wx::EXPAND );
	$sizerv->Add( $self->{list},   1, Wx::ALL | Wx::EXPAND );
	$sizerh->Add( $sizerv,         1, Wx::ALL | Wx::EXPAND );

	# Fits panel layout
	$self->SetSizerAndFit($sizerh);
	$sizerh->SetSizeHints($self);

	# Handle double-click on a function name
	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->{list},
		sub {
			$self->on_list_item_activated($_[1]);
		}
	);

	# Handle double click on list.
	# Overwrite to avoid stealing the focus back from the editor.
	# On Windows this appears to kill the double-click feature entirely.
	unless (Padre::Constant::WIN32) {
		Wx::Event::EVT_LEFT_DCLICK(
			$self->{list},
			sub {
				return;
			}
		);
	}

	# Handle key events in list
	Wx::Event::EVT_KEY_UP(
		$self->{list},
		sub {
			$self->on_search_key_up($_[1]);
		},
	);

	# Handle char events in search box
	Wx::Event::EVT_CHAR(
		$self->{search},
		sub {
			$self->on_search_char($_[1]);
		},
	);

	# React to user search
	Wx::Event::EVT_TEXT(
		$self,
		$self->{search},
		sub {
			$self->render;
		}
	);

	# Right click menu
	Wx::Event::EVT_CONTEXT(
		$self,
		sub {
			$self->on_context_menu($_[1]);
		},
	);

	if (Padre::Feature::STYLE_GUI) {
		$self->main->theme->apply( $self->{list} );
	}

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	Wx::gettext('Functions');
}

sub view_close {
	$_[0]->main->show_functions(0);
}

sub view_stop {
	$_[0]->task_reset;
}





#####################################################################
# Event Handlers

sub on_search_key_up {
	my $self  = shift;
	my $event = shift;
	my $code  = $event->GetKeyCode;

	if ( $code == Wx::K_RETURN ) {
		$self->on_list_item_activated($event);
		$self->{search}->SetValue('');

	} elsif ( $code == Wx::K_ESCAPE ) {

		# Escape key clears search and returns focus
		# to the editor
		$self->{search}->SetValue('');
		$self->main->editor_focus;
	}

	$event->Skip(1);
}

sub on_search_char {
	my $self  = shift;
	my $event = shift;
	my $code  = $event->GetKeyCode;

	if ( $code == Wx::K_DOWN || $code == Wx::K_UP || $code == Wx::K_RETURN ) {

		# Up/Down and return keys focus on the functions lists
		$self->{list}->SetFocus;
		my $selection = $self->{list}->GetSelection;
		if ( $selection == -1 && $self->{list}->GetCount > 0 ) {
			$selection = 0;
		}
		$self->{list}->Select($selection);

	} elsif ( $code == Wx::K_ESCAPE ) {

		# Escape key clears search and returns focus
		# to the editor
		$self->{search}->SetValue('');
		$self->main->editor_focus;
	}

	$event->Skip(1);
}

sub on_list_item_activated {
	my $self   = shift;
	my $event  = shift;
	my $editor = $self->current->editor or return;

	# Which sub did they click
	my $name = $self->{list}->GetStringSelection;
	if ( defined Params::Util::_STRING($name) ) {
		$editor->goto_function($name);
	}

	return;
}

sub on_context_menu {
	my $self  = shift;
	my $event = shift;

	require Padre::Wx::FunctionList::Menu;
	my $menu = Padre::Wx::FunctionList::Menu->new( $self, $event );

	# Try to determine where to show the context menu
	if ( $event->isa('Wx::MouseEvent') ) {
		# Position is already window relative
		$self->PopupMenu( $menu->wx, $event->GetX, $event->GetY );

	} elsif ( $event->can('GetPosition') ) {
		# Assume other event positions are screen relative
		my $screen = $event->GetPosition;
		my $client = $self->ScreenToClient($screen);
		$self->PopupMenu( $menu->wx, $client->x, $client->y );

	} else {
		# Probably a wxCommandEvent
		# TO DO Capture a better location from the mouse directly
		$self->PopupMenu( $menu->wx, 50, 50 );
	}

	$event->Skip(0);
}





######################################################################
# General Methods

# Sets the focus on the search field
sub focus_on_search {
	$_[0]->{search}->SetFocus;
}

sub refresh {
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;

	# Abort any in-flight checks
	$self->task_reset;

	# Hide the widgets when no files are open
	unless ($document) {
		$self->{document} = '';
		$self->disable;
		return;
	}

	# Clear search when it is a different document
	my $id = Scalar::Util::refaddr($document);
	if ( $id ne $self->{document} ) {
		$self->{search}->ChangeValue('');
		$self->{document} = $id;
	}

	# Nothing to do if there is no content
	my $task = $document->task_functions;
	unless ($task) {
		$self->disable;
		return;
	}

	# Ensure the widget is visible
	$self->enable;

	# Shortcut if there is nothing to search for
	if ( $document->is_unused ) {
		return;
	}

	# Launch the background task
	$self->task_request(
		task  => $task,
		text  => $document->text_get,
		order => $current->config->main_functions_order,
	);

}

sub enable {
	my $self = shift;
	my $lock = $self->lock_update;
	$self->{search}->Show(1);
	$self->{list}->Show(1);

	# Rerun our layout in case the size of the function list
	# geometry changed while we were hidden.
	$self->Layout;
}

sub disable {
	my $self = shift;
	my $lock = $self->lock_update;
	$self->{search}->Hide;
	$self->{list}->Hide;
	$self->{list}->Clear;
	$self->{model} = [];
}

# Set an updated method list from the task
sub task_finish {
	my $self = shift;
	my $task = shift;
	my $list = $task->{list} or return;
	$self->{model} = $list;
	$self->render;
}

# Populate the functions list with search results
sub render {
	my $self   = shift;
	my $model  = $self->{model};
	my $search = $self->{search};
	my $list   = $self->{list};

	# Quote the search string to make it safer
	my $string = $search->GetValue;
	if ( $string eq '' ) {
		$string = '.*';
	} else {
		$string = quotemeta $string;
	}

	# Show the components and populate the function list
	SCOPE: {
		my $lock = $self->lock_update;
		$search->Show(1);
		$list->Show(1);
		$list->Clear;
		foreach my $method ( reverse @$model ) {
			if ( $method =~ /$string/i ) {
				$list->Insert( $method, 0 );
			}
		}
	}

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

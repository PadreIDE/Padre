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

our $VERSION = '0.90';
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
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	# Temporary store for the function list.
	$self->{model} = [];

	# Remember the last document we were looking at
	$self->{document} = '';

	# Create the search control
	$self->{search} = Wx::TextCtrl->new(
		$self, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER | Wx::wxSIMPLE_BORDER,
	);

	# Create the functions list
	$self->{list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxLB_SINGLE | Wx::wxBORDER_NONE
	);

	# Create a sizer
	my $sizerv = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizerh = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizerv->Add( $self->{search}, 0, Wx::wxALL | Wx::wxEXPAND );
	$sizerv->Add( $self->{list},   1, Wx::wxALL | Wx::wxEXPAND );
	$sizerh->Add( $sizerv,         1, Wx::wxALL | Wx::wxEXPAND );

	# Fits panel layout
	$self->SetSizerAndFit($sizerh);
	$sizerh->SetSizeHints($self);

	# Handle double-click on a function name
	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->{list},
		sub {
			my ( $this, $event ) = @_;
			$self->on_list_item_activated($event);
			return;
		}
	);

	# Handle double click on list.
	# Overwrite to avoid stealing the focus back from the editor.
	# On Windows this appears to kill the double-click feature entirely.
	unless (Padre::Constant::WXWIN32) {
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
			my ( $this, $event ) = @_;

			my $code = $event->GetKeyCode;
			if ( $code == Wx::WXK_RETURN ) {
				$self->on_list_item_activated($event);
			} elsif ( $code == Wx::WXK_ESCAPE ) {

				# Escape key clears search and returns focus
				# to the editor
				$self->{search}->SetValue('');
				my $editor = $self->current->editor;
				$editor->SetFocus if $editor;
			}

			$event->Skip(1);
			return;
		}
	);

	# Handle char events in search box
	Wx::Event::EVT_CHAR(
		$self->{search},
		sub {
			my ( $this, $event ) = @_;

			my $code = $event->GetKeyCode;
			if ( $code == Wx::WXK_DOWN || $code == Wx::WXK_UP || $code == Wx::WXK_RETURN ) {

				# Up/Down and return keys focus on the functions lists
				$self->{list}->SetFocus;
				my $selection = $self->{list}->GetSelection;
				if ( $selection == -1 && $self->{list}->GetCount > 0 ) {
					$selection = 0;
				}
				$self->{list}->Select($selection);
			} elsif ( $code == Wx::WXK_ESCAPE ) {

				# Escape key clears search and returns focus
				# to the editor
				$self->{search}->SetValue('');
				my $editor = $self->current->editor;
				$editor->SetFocus if $editor;
			}

			$event->Skip(1);
			return;
		}
	);

	# React to user search
	Wx::Event::EVT_TEXT(
		$self,
		$self->{search},
		sub {
			$self->render;
		}
	);

	if (Padre::Feature::STYLE_GUI) {
		$self->recolour;
	}

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	shift->gettext_label;
}

sub view_close {
	$_[0]->main->show_functions(0);
}

sub view_stop {
	$_[0]->task_reset;
}





#####################################################################
# Event Handlers

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

# Sets the focus on the search field
sub focus_on_search {
	$_[0]->{search}->SetFocus;
}





######################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Functions');
}

# Pick up colouring from the current editor style
sub recolour {
	my $self   = shift;
	my $config = $self->config;

	# Load the editor style
	require Padre::Wx::Editor;
	my $data = Padre::Wx::Editor::data( $config->editor_style ) or return;

	# Find the colours we need
	my $foreground = $data->{padre}->{colors}->{PADRE_BLACK}->{foreground};
	my $background = $data->{padre}->{background};

	# Apply them to the widgets
	if ( defined $foreground and defined $background ) {
		$foreground = Padre::Wx::color($foreground);
		$background = Padre::Wx::color($background);

		$self->{list}->SetForegroundColour($foreground);
		$self->{list}->SetBackgroundColour($background);

		# $self->{search}->SetForegroundColour($foreground);
		# $self->{search}->SetBackgroundColour($background);
	}

	return 1;
}

sub refresh {
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;
	my $search   = $self->{search};
	my $list     = $self->{list};
	my $lock     = $self->main->lock('UPDATE');

	# Hide the widgets when no files are open
	unless ($document) {
		$search->Hide;
		$list->Hide;
		$list->Clear;
		$self->{model}    = [];
		$self->{document} = '';
		return;
	}

	# Ensure the widget is visible
	$search->Show(1);
	$list->Show(1);

	# Clear search when it is a different document
	my $id = Scalar::Util::refaddr($document);
	if ( $id ne $self->{document} ) {
		$search->ChangeValue('');
		$self->{document} = $id;
	}

	# Nothing to do if there is no content
	my $task = $document->task_functions;
	if ( $document->is_unused or not $task ) {
		$list->Clear;
		return;
	}

	# Launch the background task
	$self->task_request(
		task  => $task,
		text  => $document->text_get,
		order => $current->config->main_functions_order,
	);
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
		my $lock = $self->main->lock('UPDATE');
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

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

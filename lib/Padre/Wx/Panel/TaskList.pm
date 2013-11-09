package Padre::Wx::Panel::TaskList;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task        ();
use Padre::Wx::Role::Idle    ();
use Padre::Wx::Role::View    ();
use Padre::Wx::Role::Context ();
use Padre::Wx::FBP::TaskList ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';
our @ISA        = qw{
	Padre::Role::Task
	Padre::Wx::Role::Idle
	Padre::Wx::Role::View
	Padre::Wx::Role::Context
	Padre::Wx::FBP::TaskList
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;
	my $self  = $class->SUPER::new($panel);

	# Temporary store for the task list.
	$self->{model} = [];

	# Remember the last document we were looking at
	$self->{document} = '';

	# Create the image list even though we don't use much of it
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{images} = {
		folder => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_FOLDER',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		file => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_NORMAL_FILE',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		result => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_FORWARD',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
	};
	$self->{tree}->AssignImageList($images);

	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self->{tree},
		sub {
			$_[0]->idle_method( item_clicked => $_[1]->GetItem );
		},
	);

	# Register for refresh calls
	$main->add_refresh_listener($self);

	$self->context_bind;

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	Wx::gettext('Task List');
}

sub view_close {
	$_[0]->task_reset;
	$_[0]->main->show_tasks(0);
}





######################################################################
# Padre::Wx::Role::Context Methods

sub context_menu {
	my $self = shift;
	my $menu = shift;

	$self->context_append_options( $menu => 'main_tasks_panel' );

	return;
}





######################################################################
# Refresh and Search

sub refresh {
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;
	my $search   = $self->{search};
	my $tree     = $self->{tree};

	# Flush and hide the list if there is no active document
	unless ($document) {
		my $lock = $self->lock_update;
		$search->Hide;
		$tree->Hide;
		$tree->Clear;
		$self->{model}    = [];
		$self->{document} = '';
		return;
	}

	# Ensure the widget is visible
	$search->Show(1);
	$tree->Show(1);

	# Clear search when it is a different document
	my $id = Scalar::Util::refaddr($document);
	if ( $id ne $self->{document} ) {
		$search->ChangeValue('');
		$self->{document} = $id;
	}

	# Unlike the Function List widget we copied to make this,
	# don't bother with a background task, since this is much quicker.
	my $regexp = $current->config->main_tasks_regexp;
	my $text   = $document->text_get;
	my @items  = ();
	SCOPE: {
		local $@;
		eval {
			while ( $text =~ /$regexp/gim )
			{
				push @items, { text => $1 || '<no text>', 'pos' => pos($text) };
			}
		};
		$self->main->error(
			sprintf(
				Wx::gettext('%s in TODO regex, check your config.'),
				$@,
			)
		) if $@;
	}
	while ( $text =~ /#\s*(Ticket #\d+.*?)$/gim ) {
		push @items, { text => $1, 'pos' => pos($text) };
	}

	if ( @items == 0 ) {
		$tree->Clear;
		$self->{model} = [];
		return;
	}

	# Update the model and rerender
	$self->{model} = \@items;
	$self->render;
}

# Populate the list with search results
sub render {
	my $self   = shift;
	my $model  = $self->{model};
	my $search = $self->{search};
	my $tree   = $self->{tree};

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
		$tree->Show(1);
		$tree->Clear;
		foreach my $task ( reverse @$model ) {
			my $text = $task->{text};
			if ( $text =~ /$string/i ) {
				$tree->Insert( $text, 0 );
			}
		}
	}

	return 1;
}





######################################################################
# General Methods

sub item_clicked {
	my $self   = shift;
	my $item   = shift or return;
	my $tree   = $self->{tree};
	my $data   = $tree->GetPlData($item) or return;
	my $line   = $data->{line} or return;
	my $editor = $self->current->editor or return;
	$editor->goto_pos_centerize($line);
	$editor->SetFocus;
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

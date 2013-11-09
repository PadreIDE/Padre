package Padre::Wx::Outline;

use 5.010;
use strict;
use warnings;
use Scalar::Util             ();
use Params::Util             ();
use Padre::Feature           ();
use Padre::Role::Task        ();
use Padre::Wx                ();
use Padre::Wx::Role::Idle    ();
use Padre::Wx::Role::View    ();
use Padre::Wx::Role::Main    ();
use Padre::Wx::Role::Context ();
use Padre::Wx::FBP::Outline  ();
use Padre::Logger;

our $VERSION = '1.00';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::Idle
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Padre::Wx::Role::Context
	Padre::Wx::FBP::Outline
};


######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;
	my $self  = $class->SUPER::new($panel);

	# This tool is just a single tree control
	my $tree = $self->{tree};
	$self->disable;
	$tree->SetIndent(10);

	# Prepare the available images
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
	};
	$tree->AssignImageList($images);

	# Binding for the idle time tree activation
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self->{tree},
		sub {
			$_[0]->idle_method( item_activated => $_[1]->GetItem );
		},
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{search},
		sub {
			$self->render;
		},
	);

	# Handle char events in search box
	Wx::Event::EVT_CHAR(
		$self->{search},
		sub {
			my ( $this, $event ) = @_;

			my $code = $event->GetKeyCode;
			if ( $code == Wx::K_DOWN or $code == Wx::K_UP or $code == Wx::K_RETURN ) {

				# Up/Down and return keys focus on the functions lists
				my $tree = $self->{tree};
				$tree->SetFocus;
				my $selection = $tree->GetSelection;
				if ( $selection == -1 and $tree->GetCount > 0 ) {
					$selection = 0;
				}
				$tree->SelectItem($selection);
			} elsif ( $code == Wx::K_ESCAPE ) {

				# Escape key clears search and returns focus
				# to the editor
				$self->{search}->SetValue('');
				$self->main->editor_focus;
			}

			$event->Skip(1);
			return;
		}
	);

	$self->context_bind;

	if (Padre::Feature::STYLE_GUI) {
		$self->main->theme->apply($self);
	}

	return $self;
}


#####################################################################
# Event Handlers

sub on_tree_item_right_click {
	my $self  = shift;
	my $event = shift;
	my $tree  = $self->{tree};
	my $item  = $event->GetItem or return;
	my $data  = $tree->GetPlData($item) or return;
	my $show  = 0;
	my $menu  = Wx::Menu->new;

	if ( defined $data->{line} and $data->{line} > 0 ) {
		my $goto = $menu->Append( -1, Wx::gettext('&Go to Element') );
		Wx::Event::EVT_MENU(
			$self, $goto,
			sub {
				$self->item_activated($item);
			},
		);
		$show++;
	}

	if ( defined $data->{type} and $data->{type} =~ /^(?:modules|pragmata)$/ ) {
		my $pod = $menu->Append( -1, Wx::gettext('Open &Documentation') );
		Wx::Event::EVT_MENU(
			$self, $pod,
			sub {

				# TO DO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
				require Padre::Wx::Browser;
				my $help = Padre::Wx::Browser->new;
				$help->help( $data->{name} );
				$help->SetFocus;
				$help->Show(1);
				return;
			},
		);
		$show++;
	}

	if ( $show > 0 ) {
		my $x = $event->GetPoint->x;
		my $y = $event->GetPoint->y;
		$tree->PopupMenu( $menu, $x, $y );
	}

	return;
}


######################################################################
# Padre::Wx::Role::Context Methods

sub context_menu {
	my $self = shift;
	my $menu = shift;
	$self->context_append_options( $menu => 'main_outline_panel' );
}


######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	Wx::gettext('Outline');
}

sub view_close {
	$_[0]->main->show_outline(0);
}

sub view_stop {
	$_[0]->task_reset;
}


######################################################################
# Padre::Role::Task Methods

sub task_finish {
	TRACE( $_[1] ) if DEBUG;
	my $self = shift;
	my $task = shift;
	my $data = Params::Util::_ARRAY( $task->{data} ) or return;
	my $lock = $self->lock_update;

	# Cache data model for faster searches
	$self->{data} = $data;

	# And render it
	$self->render;

	return 1;
}

sub render {
	my $self = shift;
	my $data = $self->{data};
	my $term = quotemeta $self->{search}->GetValue;
	my $lock = Wx::WindowUpdateLocker->new( $self->{tree} );

	# Clear any old content
	$self->clear;

	# Add the hidden unused root
	my $tree   = $self->{tree};
	my $images = $self->{images};
	my $root   = $tree->AddRoot(
		Wx::gettext('Outline'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	# Add the package trees
	foreach my $pkg (@$data) {
		my $branch = $tree->AppendItem(
			$root,
			$pkg->{name},
			-1, -1,
			Wx::TreeItemData->new(
				{   line => $pkg->{line},
					name => $pkg->{name},
					type => 'package',
				}
			)
		);
		$tree->SetItemImage( $branch, $images->{folder} );

		my @types = qw(classes grammars packages pragmata modules
			attributes methods events roles regexes);
		foreach my $type (@types) {
			$self->add_subtree( $pkg, $type, $branch );
		}
		$tree->Expand($branch);
	}

	# Set MIME type specific event handler
	Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK(
		$tree, $tree,
		sub {
			$self->on_tree_item_right_click( $_[1] );
		},
	);

	$self->GetBestSize;

	return;
}


######################################################################
# General Methods

sub item_activated {
	my $self = shift;
	my $item = shift or return;
	my $tree = $self->{tree};
	my $data = $tree->GetPlData($item) or return;
	my $line = $data->{line} or return;
	$self->select_line_in_editor($line);
}

# Sets the focus on the search field
sub focus_on_search {
	$_[0]->{search}->SetFocus;
}

sub clear {
	$_[0]->{tree}->DeleteAllItems;
}

sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self     = shift;
	my $current  = shift or return;
	my $document = $current->document;
	my $lock     = $self->lock_update;
	my $tree     = $self->{tree};

	# Cancel any existing outline task
	$self->task_reset;

	# Hide the widgets when no files are open
	unless ($document) {
		$self->disable;
		return;
	}

	# Is there an outline task for this document type
	my $task = $document->task_outline;
	unless ($task) {
		$self->disable;
		return;
	}

	# Shortcut if there is nothing to search for
	if ( $document->is_unused ) {
		$self->disable;
		return;
	}

	# Ensure the search box and tree are visible
	$self->enable;

	# Trigger the task to fetch the refresh data
	$self->task_request(
		task     => $task,
		document => $document,
	);
}

sub disable {
	my $self = shift;
	$self->{search}->Hide;
	$self->{tree}->Hide;
	$self->clear;
}

sub enable {
	my $self = shift;

	$self->{search}->Show;
	$self->{tree}->Show;

	# Recalculate our layout in case the view geometry
	# has changed from when we were hidden.
	$self->Layout;
}

sub add_subtree {
	my ( $self, $pkg, $type, $root ) = @_;
	my $tree   = $self->{tree};
	my $term   = quotemeta $self->{search}->GetValue;
	my $images = $self->{images};

	my %type_caption = (
		pragmata   => Wx::gettext('Pragmata'),
		modules    => Wx::gettext('Modules'),
		methods    => Wx::gettext('Methods'),
		attributes => Wx::gettext('Attributes'),
	);

	my $type_elem = undef;
	if ( defined( $pkg->{$type} ) && scalar( @{ $pkg->{$type} } ) > 0 ) {
		my $type_caption = ucfirst($type);
		if ( exists $type_caption{$type} ) {
			$type_caption = $type_caption{$type};
		} else {
			warn "Type not translated: $type_caption\n";
		}

		$type_elem = $tree->AppendItem(
			$root,
			$type_caption,
			-1,
			-1,
			Wx::TreeItemData->new
		);
		$tree->SetItemImage( $type_elem, $images->{folder} );

		my @sorted_entries = ();
		if ( $type eq 'methods' ) {
			my $config = $self->main->{ide}->config;
			if ( $config->main_functions_order eq 'original' ) {

				# That should be the one we got
				@sorted_entries = @{ $pkg->{$type} };
			} elsif ( $config->main_functions_order eq 'alphabetical_private_last' ) {

				# ~ comes after \w
				my @pre = map { $_->{name} =~ s/^_/~/; $_ } @{ $pkg->{$type} };
				@pre = sort { $a->{name} cmp $b->{name} } @pre;
				@sorted_entries = map { $_->{name} =~ s/^~/_/; $_ } @pre;
			} else {

				# Alphabetical (aka 'abc')
				@sorted_entries = sort { $a->{name} cmp $b->{name} } @{ $pkg->{$type} };
			}
		} else {
			@sorted_entries = sort { $a->{name} cmp $b->{name} } @{ $pkg->{$type} };
		}

		foreach my $item (@sorted_entries) {
			my $name = $item->{name};

			#ToDo hack to remove double spacing caused by a stray has with no value, works with PPIx 0.15_02 but overwites
			$name =~ s/\n//;

			next if $name !~ /$term/;
			my $item = $tree->AppendItem(
				$type_elem,
				$name, -1, -1,
				Wx::TreeItemData->new(
					{   line => $item->{line},
						name => $name,
						type => $type,
					}
				)
			);
			$tree->SetItemImage( $item, $images->{file} );
		}
	}
	if ( defined $type_elem ) {
		if ( length $term > 0 ) {
			$tree->Expand($type_elem);
		} else {
			if ( $type eq 'methods' ) {
				$tree->Expand($type_elem);
			} elsif ( $type eq 'attributes' ) {
				$tree->Expand($type_elem);
			} else {
				if ( $tree->IsExpanded($type_elem) ) {
					$tree->Collapse($type_elem);
				}
			}
		}
	}

	return;
}

sub select_line_in_editor {
	my $self   = shift;
	my $line   = shift;
	my $editor = $self->current->editor or return;
	if (   defined $line
		&& ( $line =~ /^\d+$/o )
		&& ( $line <= $editor->GetLineCount ) )
	{
		$line--;
		$editor->goto_line_centerize($line);
	}
	return;
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

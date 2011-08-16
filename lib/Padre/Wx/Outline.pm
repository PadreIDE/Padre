package Padre::Wx::Outline;

use 5.008;
use strict;
use warnings;
use Scalar::Util          ();
use Params::Util          ();
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Logger;

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::TreeCtrl
};





######################################################################
# Constructor and Accessors

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;

	# This tool is just a single tree control
	my $self = $class->SUPER::new(
		$panel,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_HAS_BUTTONS | Wx::wxTR_LINES_AT_ROOT
	);
	$self->SetIndent(10);

	Wx::Event::EVT_COMMAND_SET_FOCUS(
		$self, $self,
		sub {
			$self->on_tree_item_set_focus( $_[1] );
		},
	);

	# Double-click a function name
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self, $self,
		sub {
			$self->on_tree_item_activated( $_[1] );
		}
	);

	$self->Hide;

	# Cache document metadata for use when changing documents.
	# By substituting old metadata before we scan for new metadata,
	# we can make the widget APPEAR to be faster than it is and
	# offset the cost of doing the PPI parse in the background.
	# $self->{cache} = {};

	return $self;
}





#####################################################################
# Event Handlers

sub on_tree_item_right_click {
	my $self   = shift;
	my $event  = shift;
	my $show   = 0;
	my $menu   = Wx::Menu->new;
	my $pldata = $self->GetPlData( $event->GetItem );

	if ( defined($pldata) && defined( $pldata->{line} ) && $pldata->{line} > 0 ) {
		my $goto = $menu->Append( -1, Wx::gettext('&Go to Element') );
		Wx::Event::EVT_MENU(
			$self, $goto,
			sub {
				$self->on_tree_item_set_focus($event);
			},
		);
		$show++;
	}

	if (   defined($pldata)
		&& defined( $pldata->{type} )
		&& ( $pldata->{type} eq 'modules' || $pldata->{type} eq 'pragmata' ) )
	{
		my $pod = $menu->Append( -1, Wx::gettext('Open &Documentation') );
		Wx::Event::EVT_MENU(
			$self, $pod,
			sub {

				# TO DO Fix this wasting of objects (cf. Padre::Wx::Menu::Help)
				require Padre::Wx::Browser;
				my $help = Padre::Wx::Browser->new;
				$help->help( $pldata->{name} );
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
		$self->PopupMenu( $menu, $x, $y );
	}

	return;
}

# Method alias
sub on_tree_item_activated {
	shift->on_tree_item_set_focus(@_);
}

sub on_tree_item_set_focus {
	my $self      = shift;
	my $event     = shift;
	my $selection = $self->GetSelection;
	if ( $selection and $selection->IsOk ) {
		my $item = $self->GetPlData($selection);
		if ( defined $item ) {
			$self->select_line_in_editor( $item->{line} );
		}
	}
	return;
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
	my $lock = $self->main->lock('UPDATE');

	# Clear any old content
	$self->clear;

	# Add the hidden unused root
	my $root = $self->AddRoot(
		Wx::gettext('Outline'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	# Add the package trees
	foreach my $pkg (@$data) {
		my $branch = $self->AppendItem(
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
		my @types = qw(classes grammars packages pragmata modules
			attributes methods events roles regexes);
		foreach my $type (@types) {
			$self->add_subtree( $pkg, $type, $branch );
		}
		$self->Expand($branch);
	}

	# Set MIME type specific event handler
	Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK(
		$self, $self,
		sub {
			$_[0]->on_tree_item_right_click( $_[1] );
		},
	);

	# TO DO Expanding all is not acceptable: We need to keep the state
	# (i.e., keep the pragmata subtree collapsed if it was collapsed
	# by the user)
	#$self->ExpandAll;
	$self->GetBestSize;

	return 1;
}





######################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Outline');
}

sub clear {
	$_[0]->DeleteAllItems;
}

sub refresh {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Cancel any existing outline task
	$self->task_reset;

	# Shortcut if the document is empty
	my $document = $self->current->document;
	unless ( $document and not $document->is_unused ) {
		$self->clear;
		return 1;
	}

	# Is there an outline task for this document type
	my $task = $document->task_outline;
	unless ($task) {
		$self->clear;
		return;
	}

	# Trigger the task to fetch the refresh data
	$self->task_request(
		task     => $task,
		document => $document,
	);
}

sub add_subtree {
	my ( $self, $pkg, $type, $root ) = @_;

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

		$type_elem = $self->AppendItem(
			$root,
			$type_caption,
			-1,
			-1,
			Wx::TreeItemData->new
		);

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
			$self->AppendItem(
				$type_elem,
				$item->{name},
				-1, -1,
				Wx::TreeItemData->new(
					{   line => $item->{line},
						name => $item->{name},
						type => $type,
					}
				)
			);
		}
	}
	if ( defined $type_elem ) {
		if ( $type eq 'methods' ) {
			$self->Expand($type_elem);
		} else {
			if ( $self->IsExpanded($type_elem) ) {
				$self->Collapse($type_elem);
			}
		}
	}

	return;
}

sub select_line_in_editor {
	my $self   = shift;
	my $line   = shift;
	my $editor = $self->current->editor;
	if (   defined $line
		&& ( $line =~ /^\d+$/o )
		&& ( defined $editor )
		&& ( $line <= $editor->GetLineCount ) )
	{
		$line--;
		$editor->goto_line_centerize($line);
	}
	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

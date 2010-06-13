package Padre::Wx::Outline;

use 5.008;
use strict;
use warnings;
use Scalar::Util               ();
use Params::Util               ();
use Padre::Role::Task          ();
use Padre::Wx::Role::View      ();
use Padre::Wx::Role::Main ();
use Padre::Wx                  ();
use Padre::Logger;

our $VERSION = '0.64';
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
		$self,
		$self,
		sub {
			$self->on_tree_item_set_focus( $_[1] );
		},
	);

	# Double-click a function name
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self,
		sub {
			$self->on_tree_item_activated( $_[1] );
		}
	);

	$self->Hide;

	# Track state so we can do shortcutting
	$self->{document} = '';
	$self->{length}   = -1;

	# Cache document metadata for use when changing documents.
	# By substituting old metadata before we scan for new metadata,
	# we can make the widget APPEAR to be faster than it is and
	# offset the cost of doing the PPI parse in the background.
	# $self->{cache} = {};

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
	shift->main->show_outline(0);
}





######################################################################
# Padre::Role::Task Methods

sub task_response {
	my $self = shift;
	my $task = shift;
	my $data = Params::Util::_ARRAY($task->{data}) or return;
	my $lock = $self->main->lock('UPDATE');

	# Add the hidden unused root
	my $root = $self->AddRoot(
		Wx::gettext('Outline'),
		-1,
		-1,
		Wx::TreeItemData->new('')
	);

	# Add the packge trees
	foreach my $pkg ( @$data ) {
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
		foreach my $type (qw(pragmata modules attributes methods events)) {
			$self->add_subtree( $pkg, $type, $branch );
		}
		$self->Expand($branch);
	}

	# Set MIME type specific event handler
	Wx::Event::EVT_TREE_ITEM_RIGHT_CLICK(
		$self,
		$self,
		sub {
			$_[0]->on_tree_item_right_click($_[1]);
		},
	);

	# TO DO Expanding all is not acceptable: We need to keep the state
	# (i.e., keep the pragmata subtree collapsed if it was collapsed
	# by the user)
	#$self->ExpandAll;
	$self->GetBestSize;

	# Disable caching for the moment
	# $self->store_in_cache( $filename, [ $data, $right_click_handler ] );

	return 1;
}





#####################################################################
# Timer Control

sub running {
	!!( $_[0]->{timer} and $_[0]->{timer}->IsRunning );
}

sub start {
	my $self = shift;
	TRACE("Starting Outline timer") if DEBUG;

	# Set up or reinitialise the timer
	if ( Params::Util::_INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->{timer}->Stop if $self->{timer}->IsRunning;
	} else {
		$self->{timer} = Wx::Timer->new(
			$self,
			Padre::Wx::ID_TIMER_OUTLINE
		);
		Wx::Event::EVT_TIMER(
			$self,
			Padre::Wx::ID_TIMER_OUTLINE,
			sub {
				$_[0]->on_timer( $_[1], $_[2] );
			},
		);
	}
	$self->{timer}->Start(5000);

	return;
}

sub stop {
	my $self = shift;
	TRACE("Stopping Outline timer") if DEBUG;

	# Stop the timer
	if ( Params::Util::_INSTANCE( $self->{timer}, 'Wx::Timer' ) ) {
		$self->{timer}->Stop if $self->{timer}->IsRunning;
	}

	return;
}
	




#####################################################################
# Event Handlers

sub on_timer {
	my $self  = shift;
	my $event = shift;

	# Clear the event
	$event->Skip(0) if defined $event;

	# Reuse the refresh logic here
	$self->refresh;
}

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
			$self,
			$pod,
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
	my $selection = $self->GetSelection();
	if ( $selection and $selection->IsOk ) {
		my $item = $self->GetPlData($selection);
		if ( defined $item ) {
			$self->select_line_in_editor( $item->{line} );
		}
	}
	return;
}





################################################################
# Cache routines

# sub store_in_cache {
	# my ( $self, $cache_key, $content ) = @_;
# 
	# if ( defined $cache_key ) {
		# $self->{cache}->{$cache_key} = $content;
	# }
	# return;
# }
# 
# sub get_from_cache {
	# my ( $self, $cache_key ) = @_;
# 
	# if ( defined $cache_key and exists $self->{cache}->{$cache_key} ) {
		# return $self->{cache}->{$cache_key};
	# }
	# return;
# }





######################################################################
# General Methods

sub gettext_label {
	Wx::gettext('Outline');
}

sub clear {
	$_[0]->DeleteAllItems;
}

sub refresh {
	my $self     = shift;
	my $document = $self->current->document or return;
	my $length   = $document->text_length;

	if ( $document eq $self->{document} ) {
		# Shortcut if nothing has changed.
		# NOTE: Given the speed at which the timer fires a cheap
		# length check is better than an expensive MD5 check.
		if ( $length eq $self->{length} ) {
			return;
		}
	} else {
		# New file, don't keep the current list visible
		$self->clear;
	}
	$self->{document} = $document;
	$self->{length}   = $length;

	# Fire the background task discarding old results
	$self->task_reset;
	$self->task_request(
		task     => $document->task_outline,
		document => $document,
	);
}

sub add_subtree {
	my ( $self, $pkg, $type, $root ) = @_;

	my %type_caption = (
		pragmata => Wx::gettext('Pragmata'),
		modules  => Wx::gettext('Modules'),
		methods  => Wx::gettext('Methods'),
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
			Wx::TreeItemData->new()
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
			$self->Collapse($type_elem);
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
		$editor->EnsureVisible($line);
		$editor->goto_pos_centerize(
			$editor->GetLineIndentPosition($line)
		);
		$editor->SetFocus;
	}
	return;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

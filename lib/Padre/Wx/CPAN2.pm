package Padre::Wx::CPAN2;

use 5.008;
use strict;
use warnings;
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx             ();
use Padre::Task::CPAN2    ();
use Padre::Wx::FBP::CPAN  ();
use Padre::Logger qw(TRACE);

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::FBP::CPAN
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;
	my $self  = $class->SUPER::new($panel);

	# Set up column sorting
	$self->{sort_column} = 0;
	$self->{sort_desc}   = 1;

	# Setup columns
	my @column_headers = (
		Wx::gettext('Distribution'),
		Wx::gettext('Author'),
	);
	my $index = 0;
	for my $column_header (@column_headers) {
		$self->{list}->InsertColumn( $index++, $column_header );
	}

	# Column ascending/descending image
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{images} = {
		asc => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_UP',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		desc => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_DOWN',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
	};
	$self->{list}->AssignImageList( $images, Wx::IMAGE_LIST_SMALL );

	# Tidy the list
	Padre::Util::tidy_list( $self->{list} );

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	$_[0]->main->show_cpan(0);
}

sub view_start {
}

sub view_stop {
	my $self = shift;

	# Clear out any state and tasks
	$self->task_reset;
	$self->clear;

	return;
}

#####################################################################
# Event Handlers

sub on_refresh_click {
	$_[0]->main->cpan_explorer->refresh;
}

#####################################################################
# General Methods

sub gettext_label {
	Wx::gettext('CPAN Explorer');
}

# Clear everything...
sub clear {
	my $self = shift;

	$self->{list}->DeleteAllItems;

	return;
}

# Nothing to implement here
sub relocale {
	return;
}

sub refresh {
	my $self = shift;
	my $command = shift or Padre::Task::CPAN2::CPAN_SEARCH;

	# Abort any in-flight checks
	$self->task_reset;

	# Flush old results
	$self->clear;

	# Start a background CPAN command task
	$self->task_request(
		task    => 'Padre::Task::CPAN2',
		command => $command,
	);

	return 1;
}

sub task_finish {
	my $self = shift;
	my $task = shift;
	$self->{model} = Params::Util::_ARRAY0( $task->{model} ) or return;
	$self->render;
}

sub render {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear;

	return unless $self->{model};

	# Update the list sort image
	$self->set_icon_image( $self->{sort_column}, $self->{sort_desc} );

	my $list = $self->{list};

	# Tidy the list
	Padre::Util::tidy_list($list);

	return 1;
}

sub _sort_model {
	my ($self) = @_;

	my @model = @{ $self->{model} };
	if ( $self->{sort_column} == 0 ) {

		# Sort by status
		@model = sort { $a->{distribution} cmp $b->{distribution} } @model;

	} elsif ( $self->{sort_column} == 1 ) {

		# Sort by path
		@model = sort { $a->{author} cmp $b->{author} } @model;
	} else {
		TRACE( "sort_column: " . $self->{sort_column} . " is not implemented" ) if DEBUG;
	}

	if ( $self->{sort_desc} ) {

		# reverse the sorting
		@model = reverse @model;
	}

	$self->{model} = \@model;
}

# Called when a CPAN list column is clicked
sub on_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sort_column};
	my $reversed = $self->{sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sort_column} = $column;
	$self->{sort_desc}   = $reversed;

	# Reset the previous column sort image
	$self->set_icon_image( $prevcol, -1 );

	$self->render;

	return;
}

sub set_icon_image {
	my ( $self, $column, $image_index ) = @_;

	my $item = Wx::ListItem->new;
	$item->SetMask(Wx::LIST_MASK_IMAGE);
	$item->SetImage($image_index);
	$self->{list}->SetColumn( $column, $item );

	return;
}

sub on_list_item_activated {
	my ( $self, $event ) = @_;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

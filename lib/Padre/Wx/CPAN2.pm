package Padre::Wx::CPAN2;

use 5.008;
use strict;
use warnings;
use Padre::Constant        ();
use Padre::Role::Task      ();
use Padre::Wx::Role::View  ();
use Padre::Wx              ();
use Padre::Task::CPAN2     ();
use Padre::Wx::Role::Dwell ();
use Padre::Wx::FBP::CPAN   ();
use Padre::Logger qw(TRACE);

our $VERSION = '0.91';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Dwell
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
	$self->{sort_desc}   = 0;

	$self->_setup_columns;

	# Column ascending/descending image
	$self->_setup_column_images;

	# Handle char events in search box
	#TODO move to FBP superclass once EVT_CHAR is properly supported
	Wx::Event::EVT_CHAR(
		$self->{search},
		sub {
			$self->_on_char_search(@_);
		}
	);

	#TODO move to FBP superclass once EVT_CHAR is properly supported
	Wx::Event::EVT_CHAR(
		$self->{list},
		sub {
			$self->_on_char_list(@_);
		}
	);

	#TODO move to FBP superclass once EVT_CHAR is properly supported
	Wx::Event::EVT_CHAR(
		$self->{recent_list},
		sub {
			$self->_on_char_list(@_);
		}
	);

	#TODO move to FBP superclass once EVT_CHAR is properly supported
	Wx::Event::EVT_CHAR(
		$self->{favorite_list},
		sub {
			$self->_on_char_list(@_);
		}
	);

	# Tidy the list
	Padre::Util::tidy_list( $self->{list} );
	Padre::Util::tidy_list( $self->{recent_list} );
	Padre::Util::tidy_list( $self->{favorite_list} );

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
	$_[0]->main->show_cpan_explorer(0);
}

sub view_start {
	my $self = shift;

	$self->{synopsis}->Hide;
	$self->{install}->Hide;

}

sub view_stop {
	my $self = shift;

	# Clear, reset running task and stop dwells
	$self->clear( Padre::Task::CPAN2::CPAN_SEARCH );
	$self->clear( Padre::Task::CPAN2::CPAN_RECENT );
	$self->clear( Padre::Task::CPAN2::CPAN_FAVORITE );
	$self->task_reset;
	$self->dwell_stop('refresh'); # Just in case

	return;
}

#####################################################################
# General Methods

sub _setup_column_images {
	my $self = shift;

	# Create bitmaps
	my $up_arrow_bitmap = Wx::ArtProvider::GetBitmap(
		'wxART_GO_UP',
		'wxART_OTHER_C',
		[ 16, 16 ],
	);
	my $down_arrow_bitmap = Wx::ArtProvider::GetBitmap(
		'wxART_GO_DOWN',
		'wxART_OTHER_C',
		[ 16, 16 ],
	);
	my $file_bitmap = Wx::ArtProvider::GetBitmap(
		'wxART_NORMAL_FILE',
		'wxART_OTHER_C',
		[ 16, 16 ],
	);

	# Search list column bitmaps
	$self->{images} = $self->_setup_image_list(
		list => $self->{list},
		up   => $up_arrow_bitmap,
		down => $down_arrow_bitmap,
		file => $file_bitmap,
	);

	# Recent list column bitmaps
	$self->{recent_images} = $self->_setup_image_list(
		list => $self->{recent_list},
		up   => $up_arrow_bitmap,
		down => $down_arrow_bitmap,
		file => $file_bitmap,
	);

	# Favorite list column bitmaps
	$self->{favorite_images} = $self->_setup_image_list(
		list => $self->{favorite_list},
		up   => $up_arrow_bitmap,
		down => $down_arrow_bitmap,
		file => $file_bitmap,
	);

	return;
}

sub _setup_image_list {
	my ( $self, %args ) = @_;

	my $images = Wx::ImageList->new( 16, 16 );
	my $result = {
		asc  => $images->Add( $args{up} ),
		desc => $images->Add( $args{down} ),
		file => $images->Add( $args{file} ),
	};
	$args{list}->AssignImageList( $images, Wx::IMAGE_LIST_SMALL );

	return $result;
}


# Setup columns
sub _setup_columns {
	my $self = shift;

	my $list = $self->{list};
	my $index;
	my @column_headers;

	@column_headers = (
		Wx::gettext('Distribution'),
		Wx::gettext('Author'),
	);
	$index = 0;
	for my $column_header (@column_headers) {
		$self->{list}->InsertColumn( $index++, $column_header );
	}

	@column_headers = (
		Wx::gettext('Distribution'),
		Wx::gettext('Abstract'),
	);
	$index = 0;
	for my $column_header (@column_headers) {
		$self->{recent_list}->InsertColumn( $index++, $column_header );
	}

	@column_headers = (
		Wx::gettext('Distribution'),
		Wx::gettext('Abstract'),
	);
	$index = 0;
	for my $column_header (@column_headers) {
		$self->{favorite_list}->InsertColumn( $index++, $column_header );
	}

	return;
}

# Sets the focus on the search field
sub focus_on_search {
	$_[0]->{search}->SetFocus;
}

sub gettext_label {
	Wx::gettext('CPAN Explorer');
}

# Clear everything...
sub clear {
	my ( $self, $command ) = @_;

	if( $command eq Padre::Task::CPAN2::CPAN_RECENT ) {
		$self->{recent_list}->DeleteAllItems;
	} elsif($command eq Padre::Task::CPAN2::CPAN_SEARCH ) { 
		$self->{list}->DeleteAllItems;
	} elsif($command eq Padre::Task::CPAN2::CPAN_FAVORITE ) { 
		$self->{favorite_list}->DeleteAllItems;
	} else {
		die "Unhandled $command in ->clear";
	}

	return;
}

# Nothing to implement here
sub relocale {
	return;
}

sub refresh {
	my $self    = shift;
	my $command = shift || Padre::Task::CPAN2::CPAN_SEARCH;
	my $query   = shift || lc( $self->{search}->GetValue );

	# Abort any in-flight checks
	$self->task_reset;

	# Start a background CPAN command task
	$self->task_request(
		task    => 'Padre::Task::CPAN2',
		command => $command,
		query   => $query,
	);

	return 1;
}

sub task_finish {
	my $self = shift;
	my $task = shift;

	my $command = $task->{command};
	print $command . "\n";
	if ( $command eq Padre::Task::CPAN2::CPAN_SEARCH ) {
		$self->{model} = Params::Util::_ARRAY0( $task->{model} ) or return;
		$self->render;
	} elsif ( $command eq Padre::Task::CPAN2::CPAN_POD ) {
		$self->{pod_model} = Params::Util::_HASH( $task->{model} ) or return;
		$self->render_doc;
	} elsif ( $command eq Padre::Task::CPAN2::CPAN_RECENT ) {
		$self->{recent_model} = Params::Util::_ARRAY0( $task->{model} ) or return;
		$self->render_recent;
	} elsif ( $command eq Padre::Task::CPAN2::CPAN_FAVORITE ) {
		$self->{favorite_model} = Params::Util::_ARRAY0( $task->{model} ) or return;
		$self->render_favorite;
	} else {
		die "Cannot handle $command\n";
	}
}

sub render {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear( Padre::Task::CPAN2::CPAN_SEARCH );

	return unless $self->{model};

	# Update the list sort image
	$self->set_icon_image( $self->{list}, $self->{sort_column}, $self->{sort_desc} );

	my $list = $self->{list};
	$self->_sort_model( recent => 0 );
	my $model = $self->{model};

	my $alternate_color = $self->_alternate_color;
	my $index           = 0;
	for my $rec (@$model) {

		# Add a CPAN distribution and author as a row to the list
		$list->InsertImageStringItem( $index, $rec->{documentation}, $self->{images}{file} );
		$list->SetItemData( $index, $index );
		$list->SetItem( $index, 1, $rec->{author} );
		$list->SetItemBackgroundColour( $index, $alternate_color ) unless $index % 2;
		$index++;
	}

	$self->_update_ui( $list, scalar @$model > 0 );

	return 1;
}

# Show & Tidy or hide the list
sub _update_ui {
	my ( $self, $list, $shown ) = @_;

	if ($shown) {
		if ( $list == $self->{list} ) {
			Padre::Util::tidy_list($list);
		} else {
			$list->SetColumnWidth( 0, 140 );
			$list->SetColumnWidth( 1, Wx::LIST_AUTOSIZE );
		}
		$list->Show;
		$self->Layout;
	} else {
		$self->{synopsis}->Hide;
		$self->{install}->Hide;
		$list->Hide;
		$self->Layout;
	}

	return;
}

sub _sort_model {
	my ( $self, %args ) = @_;

	my $is_recent = $args{recent} || 0;
	my @model = @{ $is_recent ? $self->{recent_model} : $self->{model} };
	if ( $self->{sort_column} == 0 ) {

		# Sort by distribution or documentation
		@model = sort {
			      $is_recent
				? $a->{distribution} cmp $b->{distribution}
				: $a->{documentation} cmp $b->{documentation}
		} @model;

	} elsif ( $self->{sort_column} == 1 ) {

		# Sort by abstract or author
		@model = sort { $is_recent ? $a->{abstract} cmp $b->{abstract} : $a->{author} cmp $b->{author} } @model;

	} elsif ( $self->{sort_column} == 2 ) {

		# Sort by date
		@model = sort { $a->{date} cmp $b->{date} } @model;

	} else {
		TRACE( "sort_column: " . $self->{sort_column} . " is not implemented" ) if DEBUG;
	}

	if ( $self->{sort_desc} ) {

		# reverse the sorting
		@model = reverse @model;
	}

	if ($is_recent) {
		$self->{recent_model} = \@model;
	} else {
		$self->{model} = \@model;
	}
}

#####################################################################
# Event Handlers

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
	$self->set_icon_image( $self->{list}, $prevcol, -1 );

	$self->render;

	return;
}

# Called when a recent CPAN list column is clicked
sub on_recent_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sort_column};
	my $reversed = $self->{sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sort_column} = $column;
	$self->{sort_desc}   = $reversed;

	# Reset the previous column sort image
	$self->set_icon_image( $self->{recent_list}, $prevcol, -1 );

	$self->render_recent;

	return;
}

sub set_icon_image {
	my ( $self, $list, $column, $image_index ) = @_;

	my $item = Wx::ListItem->new;
	$item->SetMask(Wx::LIST_MASK_IMAGE);
	$item->SetImage($image_index);
	$list->SetColumn( $column, $item );

	return;
}

# Called when a CPAN list item is selected
sub on_list_item_selected {
	my ( $self, $event ) = @_;

	my $module = $event->GetLabel;
	my $doc    = $self->{doc};
	$doc->SetPage(
		sprintf(
			Wx::gettext(q{<b>Loading %s...</b>}),
			$module
		)
	);
	$doc->SetBackgroundColour( Wx::Colour->new( 253, 252, 187 ) );

	$self->refresh( Padre::Task::CPAN2::CPAN_POD, $module );
}

# Renders the documentation/SYNOPSIS section
sub render_doc {
	my $self = shift;

	my $model = $self->{pod_model} or return;
	my ( $pod_html, $synopsis, $distro ) = (
		$model->{html},
		$model->{synopsis},
		$model->{distro},
	);

	$self->{doc}->SetPage($pod_html);
	$self->{doc}->SetBackgroundColour( Wx::Colour->new( 253, 252, 187 ) );

	if ( length $synopsis > 0 ) {
		$self->{synopsis}->Show;
	} else {
		$self->{synopsis}->Hide;
	}
	$self->{install}->Show;
	$self->Layout;
	$self->{SYNOPSIS} = $synopsis;
	$self->{distro}   = $distro;

	return;
}

# Called when the synopsis is clicked
sub on_synopsis_click {
	my ( $self, $event ) = @_;
	return unless $self->{SYNOPSIS};

	# Open a new Perl document containing the SYNOPSIS text
	$self->main->new_document_from_string( $self->{SYNOPSIS}, 'application/x-perl' );

	return;
}

# Called when search text control is changed
sub on_search_text {
	$_[0]->main->cpan_explorer->dwell_start( 'refresh', 333 );
}

# Called when the install button is clicked
sub on_install_click {
	my $self = shift;

	# Install selected distribution using App::cpanminus
	my $distro = $self->{distro} or return;
	require File::Which;
	my $cpanm = File::Which::which('cpanm');
	$cpanm = qq{"cpanm"} if Padre::Constant::WIN32;
	$self->main->run_command("$cpanm $distro");

	return;
}

# Called when the Refresh recent button is clicked
sub on_refresh_recent_click {
	$_[0]->refresh(Padre::Task::CPAN2::CPAN_RECENT);
	return;
}

# Renders the recent CPAN list
sub render_recent {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear( Padre::Task::CPAN2::CPAN_RECENT );

	my $list = $self->{recent_list};

	# Update the list sort image
	$self->set_icon_image( $list, $self->{sort_column}, $self->{sort_desc} );

	my $model = $self->{recent_model} or return;
	$self->_sort_model( recent => 1 );

	my $alternate_color = $self->_alternate_color;
	my $index           = 0;
	for my $rec (@$model) {

		# Add a CPAN distribution and abstract as a row to the list
		my $distribution = $rec->{distribution};
		$distribution =~ s/-/::/g;
		$list->InsertImageStringItem( $index, $distribution, $self->{recent_images}{file} );
		$list->SetItemData( $index, $index );
		$list->SetItem( $index, 1, $rec->{abstract} ) if defined $rec->{abstract};
		$list->SetItemBackgroundColour( $index, $alternate_color ) unless $index % 2;
		$index++;
	}

	$self->_update_ui( $list, scalar @$model > 0 );

	return;
}

sub _alternate_color {
	my $self = shift;

	# Calculate odd/even row colors (for readability)
	my $real_color = Wx::SystemSettings::GetColour(Wx::SYS_COLOUR_WINDOW);
	return Wx::Colour->new(
		int( $real_color->Red * 0.9 ),
		int( $real_color->Green * 0.9 ),
		$real_color->Blue,
	);
}


sub _on_char_search {
	my ( $self, $this, $event ) = @_;

	my $code = $event->GetKeyCode;
	if ( $code == Wx::K_DOWN || $code == Wx::K_UP || $code == Wx::K_RETURN ) {

		# Up/Down and return keys focus on the list
		my $list = $self->{list};
		$list->SetFocus;
		my $selection = -1;
		$selection = $list->GetNextItem(
			$selection,
			Wx::LIST_NEXT_ALL,
			Wx::LIST_STATE_SELECTED
		);
		if ( $selection == -1 && $self->{list}->GetItemCount > 0 ) {
			$selection = 0;
		}
		$list->SetItemState(
			$selection,
			Wx::LIST_STATE_SELECTED, Wx::LIST_STATE_SELECTED
		) if $selection != -1;
	} elsif ( $code == Wx::K_ESCAPE ) {

		# Escape key clears search and returns focus
		# to the editor
		$self->{search}->SetValue('');
		my $editor = $self->current->editor;
		$editor->SetFocus if $editor;
	}
	$event->Skip(1);
	return;
}

sub _on_char_list {
	my ( $self, $this, $event ) = @_;

	my $code = $event->GetKeyCode;
	if ( $code == Wx::K_ESCAPE ) {

		# Escape key clears search and returns focus
		# to the editor
		$self->{search}->SetValue('');
		my $editor = $self->current->editor;
		$editor->SetFocus if $editor;
	}

	$event->Skip(1);

	return;
}

# Called when the Refresh favorite button is clicked
sub on_refresh_favorite_click {
	$_[0]->refresh(Padre::Task::CPAN2::CPAN_FAVORITE);
	return;
}

# Renders the most favorite CPAN list
sub render_favorite {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear( Padre::Task::CPAN2::CPAN_FAVORITE );

	my $list = $self->{favorite_list};

	# Update the list sort image
	$self->set_icon_image( $list, $self->{sort_column}, $self->{sort_desc} );

	my $model = $self->{recent_model} or return;
	$self->_sort_model( recent => 1 );

	my $alternate_color = $self->_alternate_color;
	my $index           = 0;
	for my $rec (@$model) {

		# Add a CPAN distribution and abstract as a row to the list
		my $distribution = $rec->{distribution};
		$distribution =~ s/-/::/g;
		$list->InsertImageStringItem( $index, $distribution, $self->{recent_images}{file} );
		$list->SetItemData( $index, $index );
		$list->SetItem( $index, 1, $rec->{abstract} ) if defined $rec->{abstract};
		$list->SetItemBackgroundColour( $index, $alternate_color ) unless $index % 2;
		$index++;
	}

	$self->_update_ui( $list, scalar @$model > 0 );

	return;
}

# Called when a favorite CPAN list column is clicked
sub on_favorite_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{sort_column};
	my $reversed = $self->{sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{sort_column} = $column;
	$self->{sort_desc}   = $reversed;

	# Reset the previous column sort image
	$self->set_icon_image( $self->{recent_list}, $prevcol, -1 );

	$self->render_favorite;

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

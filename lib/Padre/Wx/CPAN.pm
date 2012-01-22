package Padre::Wx::CPAN;

use 5.008;
use strict;
use warnings;
use Padre::Constant        ();
use Padre::Role::Task      ();
use Padre::Wx              ();
use Padre::Wx::Util        ();
use Padre::Wx::Role::View  ();
use Padre::Wx::Role::Dwell ();
use Padre::Wx::FBP::CPAN   ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Dwell
	Padre::Wx::FBP::CPAN
};

# Constants
use constant {
	YELLOW_POD => Wx::Colour->new( 253, 252, 187 ),
};

# Constructor
sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->right;
	my $self  = $class->SUPER::new($panel);

	# Set up column sorting
	$self->{search_sort_column}   = undef;
	$self->{search_sort_desc}     = 0;
	$self->{recent_sort_column}   = undef;
	$self->{recent_sort_desc}     = 0;
	$self->{favorite_sort_column} = undef;
	$self->{favorite_sort_desc}   = 0;

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
		$self->{search_list},
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
	Padre::Wx::Util::tidy_list( $self->{search_list} );
	Padre::Wx::Util::tidy_list( $self->{recent_list} );
	Padre::Wx::Util::tidy_list( $self->{favorite_list} );

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'right';
}

sub view_label {
	Wx::gettext('CPAN Explorer');
}

sub view_close {
	$_[0]->main->show_cpan(0);
}

sub view_start {
	my $self = shift;
	$self->{synopsis}->Hide;
	$self->{metacpan}->Hide;
	$self->{install}->Hide;

}

sub view_stop {
	my $self = shift;

	# Clear, reset running task and stop dwells
	$self->clear('search');
	$self->clear('recent');
	$self->clear('favorite');
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
		list => $self->{search_list},
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

	my $list = $self->{search_list};
	my $index;
	my @column_headers;

	@column_headers = (
		Wx::gettext('Distribution'),
		Wx::gettext('Author'),
	);
	$index = 0;
	for my $column_header (@column_headers) {
		$self->{search_list}->InsertColumn( $index++, $column_header );
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
		Wx::gettext('Count'),
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

# Clear everything...
sub clear {
	my ( $self, $command ) = @_;

	if ( $command eq 'recent' ) {
		$self->{recent_list}->DeleteAllItems;
	} elsif ( $command eq 'search' ) {
		$self->{search_list}->DeleteAllItems;
	} elsif ( $command eq 'favorite' ) {
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
	my $command = shift || 'search';
	my $query   = shift || lc( $self->{search}->GetValue );

	# Abort any in-flight checks
	$self->task_reset;

	# Start a background CPAN command task
	$self->task_request(
		task    => 'Padre::Task::CPAN',
		command => $command,
		query   => $query,
	);

	return 1;
}

sub task_finish {
	my $self    = shift;
	my $task    = shift;
	my $command = $task->{command};

	if ( $command eq 'search' ) {
		$self->{search_model} = Params::Util::_ARRAY0( $task->{model} ) or return;
		$self->render_search;
	} elsif ( $command eq 'pod' ) {
		$self->{pod_model} = Params::Util::_HASH( $task->{model} ) or return;
		$self->render_doc;
	} elsif ( $command eq 'recent' ) {
		$self->{recent_model} = Params::Util::_ARRAY0( $task->{model} ) or return;
		$self->render_recent;
	} elsif ( $command eq 'favorite' ) {
		$self->{favorite_model} = Params::Util::_ARRAY0( $task->{model} ) or return;
		$self->render_favorite;
	} else {
		die "Cannot handle $command\n";
	}
}

sub render_search {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear('search');

	return unless $self->{search_model};

	my $list        = $self->{search_list};
	my $sort_column = $self->{search_sort_column};
	if ( defined $sort_column ) {

		# Update the list sort image
		$self->set_icon_image( $list, $sort_column, $self->{search_sort_desc} );

		# and sort the model
		$self->_sort_model('search');
	}

	my $model = $self->{search_model};

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
		if ( $list == $self->{recent_list} ) {
			$list->SetColumnWidth( 0, 140 );
			$list->SetColumnWidth( 1, Wx::LIST_AUTOSIZE );
		} elsif ( $list == $self->{favorite_list} ) {
			$list->SetColumnWidth( 0, 140 );
			$list->SetColumnWidth( 1, 50 );
		} else {
			Padre::Wx::Util::tidy_list($list);
		}
		$list->Show;
		$self->Layout;
	} else {
		$self->{synopsis}->Hide;
		$self->{metacpan}->Hide;
		$self->{install}->Hide;
		$list->Hide;
		$self->Layout;
	}

	return;
}

sub _sort_model {
	my ( $self, $command ) = @_;

	my @model;
	my ( $sort_column, $sort_desc );
	if ( $command eq 'search' ) {
		@model       = @{ $self->{search_model} };
		$sort_column = $self->{search_sort_column};
		$sort_desc   = $self->{search_sort_desc};
	} elsif ( $command eq 'recent' ) {
		@model       = @{ $self->{recent_model} };
		$sort_column = $self->{recent_sort_column};
		$sort_desc   = $self->{recent_sort_desc};
	} elsif ( $command eq 'favorite' ) {
		@model       = @{ $self->{favorite_model} };
		$sort_column = $self->{favorite_sort_column};
		$sort_desc   = $self->{favorite_sort_desc};
	} else {
		die "Handled $command in ->sort_model\n";
	}
	if ( $sort_column == 0 ) {

		# Sort by distribution, name or term
		@model = sort {
			if ( $command eq 'search' )
			{
				$a->{documentation} cmp $b->{documentation};
			} elsif ( $command eq 'recent' ) {
				$a->{name} cmp $b->{name};
			} elsif ( $command eq 'favorite' ) {
				$a->{term} cmp $b->{term};
			}
		} @model;

	} elsif ( $sort_column == 1 ) {

		# Sort by abstract or author
		@model = sort {
			if ( $command eq 'search' )
			{
				$a->{author} cmp $b->{author};
			} elsif ( $command eq 'recent' ) {
				$a->{abstract} cmp $b->{abstract};
			} elsif ( $command eq 'favorite' ) {
				$a->{count} cmp $b->{count};
			}
		} @model;

	} elsif ( $sort_column == 2 ) {

		# Sort by date
		@model = sort { $a->{date} cmp $b->{date} } @model;

	} else {
		TRACE( "sort_column: " . $sort_column . " is not implemented" ) if DEBUG;
	}

	# Reverse the model if descending order is needed
	@model = reverse @model if $sort_desc;

	if ( $command eq 'search' ) {
		$self->{search_model} = \@model;
	} elsif ( $command eq 'recent' ) {
		$self->{recent_model} = \@model;
	} elsif ( $command eq 'favorite' ) {
		$self->{favorite_model} = \@model;
	}

	return;
}

#####################################################################
# Event Handlers

# Called when a CPAN search list column is clicked
sub on_search_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{search_sort_column} || 0;
	my $reversed = $self->{search_sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{search_sort_column} = $column;
	$self->{search_sort_desc}   = $reversed;

	# Reset the previous column sort image
	$self->set_icon_image( $self->{search_list}, $prevcol, -1 );

	$self->render_search;

	return;
}

# Called when a recent CPAN list column is clicked
sub on_recent_list_column_click {
	my ( $self, $event ) = @_;

	my $column   = $event->GetColumn;
	my $prevcol  = $self->{recent_sort_column} || 0;
	my $reversed = $self->{recent_sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{recent_sort_column} = $column;
	$self->{recent_sort_desc}   = $reversed;

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

# Called when a CPAN Search list item is selected
sub on_list_item_selected {
	my ( $self, $event ) = @_;

	my $list = $event->GetEventObject;
	my ($download_url, $module);
	if ( $list == $self->{recent_list} ) {
		my @model = @{ $self->{recent_model} };
		my $item = $model[ $event->GetIndex ];
		$download_url = $item->{download_url};
		$module = $item->{distribution};
		$module =~ s/-/::/g;
	} else {
		$module = $event->GetLabel;
	}
	my $doc    = $self->{doc};
	$doc->SetPage(
		sprintf(
			Wx::gettext(q{<b>Loading %s...</b>}),
			$module
		)
	);
	$doc->SetBackgroundColour(YELLOW_POD);

	$self->refresh( 'pod',
		{   module       => $module,
			download_url => $download_url,
		},
	);
}

# Renders the documentation/SYNOPSIS section
sub render_doc {
	my $self = shift;

	my $model = $self->{pod_model} or return;
	my ( $pod_html, $synopsis, $distro, $download_url ) = (
		$model->{html},
		$model->{synopsis},
		$model->{distro},
		$model->{download_url},
	);

	$self->{doc}->SetPage($pod_html);
	$self->{doc}->SetBackgroundColour(YELLOW_POD);

	if ( length $synopsis > 0 ) {
		$self->{synopsis}->Show;
	} else {
		$self->{synopsis}->Hide;
	}
	$self->{metacpan}->Show;
	$self->{install}->Show;
	$self->Layout;
	$self->{SYNOPSIS} = $synopsis;
	$self->{distro}   = $distro;
	$self->{download_url} = $download_url;

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
	$_[0]->main->cpan->dwell_start( 'refresh', 333 );
}

# Called when the install button is clicked
sub on_install_click {
	my $self = shift;

	# Install selected distribution using App::cpanminus
	my $distro = $self->{distro} or return;
	my $download_url = $self->{download_url};
	require File::Which;
	my $cpanm = File::Which::which('cpanm');
	$cpanm = qq{"cpanm"} if Padre::Constant::WIN32;
	if(defined $download_url) {
		$self->main->run_command("$cpanm $download_url");
	} else {
		$self->main->run_command("$cpanm $distro");
	}

	return;
}

# Called when the Refresh recent button is clicked
sub on_refresh_recent_click {
	$_[0]->refresh('recent');
	return;
}

# Renders the recent CPAN list
sub render_recent {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear('recent');

	return unless $self->{recent_model};

	my $list        = $self->{recent_list};
	my $sort_column = $self->{recent_sort_column};
	if ( defined $sort_column ) {

		# Update the list sort image
		$self->set_icon_image( $list, $sort_column, $self->{recent_sort_desc} );

		# and sort the model
		$self->_sort_model('recent');
	}
	my $model = $self->{recent_model};

	my $alternate_color = $self->_alternate_color;
	my $index           = 0;
	for my $rec (@$model) {

		# Add a CPAN distribution and abstract as a row to the list
		my $name = $rec->{name};
		$list->InsertImageStringItem( $index, $name, $self->{recent_images}{file} );
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
		my $list = $self->{search_list};
		$list->SetFocus;
		my $selection = -1;
		$selection = $list->GetNextItem(
			$selection,
			Wx::LIST_NEXT_ALL,
			Wx::LIST_STATE_SELECTED
		);
		if ( $selection == -1 && $self->{search_list}->GetItemCount > 0 ) {
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
		$self->main->editor_focus;
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
		$self->main->editor_focus;
	}

	$event->Skip(1);

	return;
}

# Called when the Refresh favorite button is clicked
sub on_refresh_favorite_click {
	$_[0]->refresh('favorite');
	return;
}

# Renders the most favorite CPAN list
sub render_favorite {
	my $self = shift;

	# Clear if needed. Please note that this is needed
	# for sorting
	$self->clear('favorite');

	return unless $self->{favorite_model};

	my $list        = $self->{favorite_list};
	my $sort_column = $self->{favorite_sort_column};
	if ( defined $sort_column ) {

		# Update the list sort image
		$self->set_icon_image( $list, $sort_column, $self->{favorite_sort_desc} );

		# and sort the model
		$self->_sort_model('favorite');
	}
	my $model = $self->{favorite_model};

	my $alternate_color = $self->_alternate_color;
	my $index           = 0;
	for my $rec (@$model) {

		# Add a CPAN distribution and abstract as a row to the list
		my $distribution = $rec->{term};
		$distribution =~ s/-/::/g;
		$list->InsertImageStringItem( $index, $distribution, $self->{favorite_images}{file} );
		$list->SetItemData( $index, $index );
		$list->SetItem( $index, 1, $rec->{count} ) if defined $rec->{count};
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
	my $prevcol  = $self->{favorite_sort_column} || 0;
	my $reversed = $self->{favorite_sort_desc};
	$reversed = $column == $prevcol ? !$reversed : 0;
	$self->{favorite_sort_column} = $column;
	$self->{favorite_sort_desc}   = $reversed;

	# Reset the previous column sort image
	$self->set_icon_image( $self->{favorite_list}, $prevcol, -1 );

	$self->render_favorite;

	return;
}

# Called when the 'MetaCPAN!' button is clicked
sub on_metacpan_click {
	my $self = shift;

	return unless defined $self->{distro};
	Padre::Wx::launch_browser( 'https://metacpan.org/module/' . $self->{distro} );

	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

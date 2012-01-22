package Padre::Wx::Dialog::WindowList;

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Icon ();

our $VERSION = '0.94';
our @ISA     = 'Wx::Dialog';

use Class::XSAccessor {
	accessors => {
		_butdelete   => '_butdelete',   # delete button
		_butopen     => '_butopen',     # open button
		_list        => '_list',        # list on the left of the pane
		_sortcolumn  => '_sortcolumn',  # column used for list sorting
		_sortreverse => '_sortreverse', # list sorting is reversed
		_vbox        => '_vbox',        # the window vbox sizer
	}
};

# -- constructor

sub new {
	my $class  = shift;
	my $parent = shift;
	my %args   = @_;

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext( $args{title} || Wx::gettext('Window list') ),
		Wx::DefaultPosition,
		Wx::Size->new( 480, 300 ),
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);

	foreach ( keys %args ) {
		$self->{$_} = $args{$_};
	}

	$self->{button_clicks} = [
		\&_button_clicked_0, \&_button_clicked_1,
		\&_button_clicked_2, \&_button_clicked_3, \&_button_clicked_4,
		\&_button_clicked_5, \&_button_clicked_6, \&_button_clicked_7,
		\&_button_clicked_8, \&_button_clicked_9
	];

	$self->SetIcon(Padre::Wx::Icon::PADRE);

	if ( scalar Padre->ide->wx->main->editors ) {

		# Create dialog
		$self->_create;
	} else {
		$self->{_empty} = 1;
	}

	return $self;
}

# -- public methods

sub show {
	my $self = shift;

	if ( $self->{_empty} ) {
		$self->Destroy;
		return 0;
	}

	$self->{visible} = 1;

	$self->_refresh_list;
	$self->_select_first_item;
	$self->ShowModal;
}

# -- gui handlers

#
# $self->_on_butclose_clicked;
#
# handler called when the close button has been clicked.
#
sub _on_butclose_clicked {
	my $self = shift;
	$self->Destroy;
	$self->{visible} = 0;
}

sub _on_button_clicked {
	my $self      = shift;
	my $button_no = shift;

	my @pages;

	foreach my $listitem ( 0 .. ( $self->_list->GetItemCount - 1 ) ) {
		my $item = $self->{items}->[ $self->_list->GetItem($listitem)->GetData ];
		next unless $item->{selected};
		push @pages, $item->{page};
	}

	my $code = $self->{buttons}->[$button_no]->[1];

	if ( ref($code) eq 'CODE' ) {
		&{$code}(@pages);
	} else {
		warn 'Button code is no CODE reference: ' . $code . ' (' . ref($code) . ')';
	}

	$self->Destroy;
	$self->{visible} = 0;
}

#
# $self->_on_list_col_click;
#
# handler called when a column has been clicked, to reorder the list.
#
sub _on_list_col_click {
	my ( $self, $event ) = @_;
	my $col = $event->GetColumn;

	my $prevcol  = $self->_sortcolumn  || 0;
	my $reversed = $self->_sortreverse || 0;
	$reversed = $col == $prevcol ? !$reversed : 0;
	$self->_sortcolumn($col);
	$self->_sortreverse($reversed);
	$self->_refresh_list( $col, $reversed );
}

#
# $self->_on_list_item_selected( $event );
#
# handler called when a list item has been selected. it will in turn update
# the buttons state.
#
# $event is a Wx::ListEvent.
#
sub _on_list_item_selected {
	my ( $self, $event ) = @_;

	$self->{items}->[ $event->GetIndex ]->{selected} = 1;

	# update buttons
	$self->_update_buttons_state;
}

#
# $self->_on_list_item_deselected( $event );
#
# handler called when a list item has lost selection. it will in turn update
# the buttons state.
#
# $event is a Wx::ListEvent.
#
sub _on_list_item_deselected {
	my ( $self, $event ) = @_;

	$self->{items}->[ $event->GetIndex ]->{selected} = 0;

	# update buttons
	$self->_update_buttons_state;
}

# -- private methods

#
# $self->_create;
#
# create the dialog itself. it will have a list with all open files, and
# some buttons to manage them.
#
# no params, no return values.
#
sub _create {
	my $self = shift;

	# create vertical box that will host all controls
	my $vbox = Wx::BoxSizer->new(Wx::VERTICAL);
	$self->SetSizer($vbox);
	$self->CenterOnParent;

	#$self->SetMinSize( [ 640, 480 ] );
	$self->_vbox($vbox);

	$self->_create_list;
	$self->_create_options;
	$self->_create_buttons;
	$self->_list->SetFocus;
}

#
# $dialog->_create_list;
#
# create the open file list.
#
# no params. no return values.
#
sub _create_list {
	my $self = shift;
	my $vbox = $self->_vbox;

	# title label
	my $label = Wx::StaticText->new(
		$self, -1,
		$self->{list_title} || Wx::gettext('List of open files')
	);
	$vbox->Add( $label, 0, Wx::ALL, 5 );

	# create list
	my $list = Wx::ListCtrl->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LC_REPORT,
	);
	$list->InsertColumn( 0, Wx::gettext('Project') );
	$list->InsertColumn( 1, Wx::gettext('File') );
	$list->InsertColumn( 2, Wx::gettext('Editor') );
	$list->InsertColumn( 3, Wx::gettext('Disk') );
	$self->_list($list);

	# install event handler
	Wx::Event::EVT_LIST_ITEM_DESELECTED( $self, $list, \&_on_list_item_deselected );
	Wx::Event::EVT_LIST_ITEM_SELECTED( $self, $list, \&_on_list_item_selected );
	Wx::Event::EVT_LIST_COL_CLICK( $self, $list, \&_on_list_col_click );

	# pack the list
	$vbox->Add( $list, 1, Wx::ALL | Wx::EXPAND, 5 );
}

#
# $dialog->_create_options;
#
# create the options
#
# no params. no return values.
#
sub _create_options {
	my $self = shift;

	my $config = Padre->ide->config;

	# the hbox
	my $hbox = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->_vbox->Add( $hbox, 0, Wx::ALL | Wx::EXPAND, 5 );

	# CheckBox
	#	$self->{autosave} = Wx::CheckBox->new(
	#		$self,
	#		-1,
	#		Wx::gettext('Save session automatically'),
	#	);
	#	$self->{autosave}->SetValue( $config->session_autosave ? 1 : 0 );
	#
	#	$hbox->Add( $self->{autosave}, 0, Wx::ALL, 5 );
}

#
# $dialog->_create_buttons;
#
# create the buttons pane.
#
# no params. no return values.
#
sub _create_buttons {
	my $self = shift;

	# the hbox
	my $hbox = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$self->_vbox->Add( $hbox, 0, Wx::ALL | Wx::EXPAND, 5 );

	# the buttons
	my $bc = Wx::Button->new( $self, Wx::ID_CANCEL, Wx::gettext('Close') );
	Wx::Event::EVT_BUTTON( $self, $bc, \&_on_butclose_clicked );

	foreach my $button_no ( 0 .. $#{ $self->{buttons} || [] } ) {
		if ( !defined( $self->{button_clicks}->[$button_no] ) ) {
			warn 'Too many buttons defined!';
			last;
		}
		my $button = $self->{buttons}->[$button_no];
		$button->[2] = Wx::Button->new( $self, -1, $button->[0] );
		Wx::Event::EVT_BUTTON( $self, $button->[2], $self->{button_clicks}->[$button_no] );
		$hbox->Add( $button->[2], 0, Wx::ALL, 5 );
	}
	$hbox->AddStretchSpacer;
	$hbox->Add( $bc, 0, Wx::ALL, 5 );
}

#
# $dialog->_refresh_list($column, $reverse);
#
# refresh list of open files. list is sorted according to $column (default to
# first column), and may be reversed (default to no).
#
sub _refresh_list {
	my ( $self, $column, $reverse ) = @_;

	my $main = Padre->ide->wx->main;

	# default sorting
	$column  ||= 0;
	$reverse ||= 0;

	# clear list & fill it again
	my $list = $self->_list;
	$list->DeleteAllItems;
	$self->{items} = []; # Clear
	foreach my $editor ( $main->editors ) {

		my $document = $editor->{Document};

		my $disk_state = $document->has_changed_on_disk;
		next if $self->{no_fresh} and ( !( $document->is_modified or $disk_state ) );

		my $filename;

		my $documentfile = $document->file;
		if ( defined($documentfile) ) {

			$filename = $documentfile->filename;
			my $project_dir = $document->project_dir;
			$filename =~ s/^\Q$project_dir\E// if defined($project_dir);

			# Apply filter (if any)
			if ( defined( $self->{filter} ) ) {
				next unless &{ $self->{filter} }( $editor, $project_dir, $filename, $document );
			}
		} else {
			$filename = $document->get_title;
		}

		# inserting the file in the list
		my $item = Wx::ListItem->new;
		$item->SetId(0);
		$item->SetColumn(0);
		$item->SetText( defined( $document->project ) ? $document->project->name : '' );
		$item->SetData( $#{ $self->{items} } );
		my $idx = $list->InsertItem($item);
		splice @{ $self->{items} }, $idx, 0, { page => $editor };

		$list->SetItem( $idx, 1, $filename );
		$list->SetItem( $idx, 2, $document->is_modified ? Wx::gettext('CHANGED') : Wx::gettext('fresh') );

		my $disk_text;
		if ( $disk_state == 0 ) {
			$disk_text = Wx::gettext('fresh');
		} elsif ( $disk_state == -1 ) {
			$disk_text = Wx::gettext('DELETED');
		} else {
			$disk_text = Wx::gettext('CHANGED');
		}
		$list->SetItem( $idx, 3, $disk_text );
	}

	# auto-resize columns
	my $flag =
		$list->GetItemCount
		? Wx::LIST_AUTOSIZE
		: Wx::LIST_AUTOSIZE_USEHEADER;
	$list->SetColumnWidth( $_, $flag ) for 0 .. 2;

	# making sure the list can show all columns
	my $width = 15; # taking vertical scrollbar into account
	$width += $list->GetColumnWidth($_) for 0 .. 2;
	$list->SetMinSize( [ $width, -1 ] );
}

#
# $self->_select_first_item;
#
# select first item in the list, or none if there are none. in that case,
# update the current row and name selection to undef.
#
sub _select_first_item {
	my $self = shift;

	# Select first item in the list
	my $list = $self->_list;

	if ( $list->GetItemCount ) {
		my $item = $list->GetItem(0);
		$item->SetState(Wx::LIST_STATE_SELECTED);
		$list->SetItem($item);
	} else {

		# Remove current selection
		foreach my $method (qw{ _currow _curname }) {
			next unless $self->can($method);
			$self->$method(undef);
		}
	}
}

#
# $self->_update_buttons_state;
#
# update state of delete and open buttons: they should not be clickable if nothing
# is selected.
#
sub _update_buttons_state {
	my ($self) = @_;

	my $count;
	foreach my $item ( @{ $self->{items} } ) {
		++$count if $item->{selected};
	}

	my $method = $count ? 'Enable' : 'Disable';

	foreach my $button ( @{ $self->{buttons} || [] } ) {
		$button->[2]->$method if defined( $button->[2] );
	}

}

# Sorry, I found no other way to solve this
sub _button_clicked_0 { $_[0]->_on_button_clicked(0); }
sub _button_clicked_1 { $_[0]->_on_button_clicked(1); }
sub _button_clicked_2 { $_[0]->_on_button_clicked(2); }
sub _button_clicked_3 { $_[0]->_on_button_clicked(3); }
sub _button_clicked_4 { $_[0]->_on_button_clicked(4); }
sub _button_clicked_5 { $_[0]->_on_button_clicked(5); }
sub _button_clicked_6 { $_[0]->_on_button_clicked(6); }
sub _button_clicked_7 { $_[0]->_on_button_clicked(7); }
sub _button_clicked_8 { $_[0]->_on_button_clicked(8); }
sub _button_clicked_9 { $_[0]->_on_button_clicked(9); }

1;

__END__


=head1 NAME

Padre::Wx::Dialog::WindowList - Windows list dialog for Padre



=head1 DESCRIPTION

This module could be used to apply custom actions to some of the open files/windows.


=head1 PUBLIC API

=head2 Constructor

=head3 C<new>

    my $dialog = PWD::SM->new( $parent )

Create and return a new Wx dialog listing all the windows. It needs a
C<$parent> window (usually Padre's main window).

=head2 Public methods

=head3 C<show>

    $dialog->show;

Request the window list dialog to be shown. It will be refreshed first with
a current list of open files/windows.


=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.


=cut

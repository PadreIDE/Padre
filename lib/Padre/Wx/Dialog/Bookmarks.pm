package Padre::Wx::Dialog::Bookmarks;

use strict;
use warnings;
use Padre::DB         ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.43';

# workaround: need to be accessible from outside in oder to write unit test ( t/03-wx.t )
# TODO - Don't store run-time data in package lexicals
my $dialog;

sub get_dialog {
	return $dialog;
}

sub get_layout {
	my $text      = shift;
	my $shortcuts = shift;

	my @layout;
	if ($text) {
		push @layout, [ [ 'Wx::TextCtrl', 'entry', $text ] ];
	}

	push @layout,
		[
		[ 'Wx::StaticText', undef, Wx::gettext("Existing bookmarks:") ],
		],
		[
		[ 'Wx::Treebook', 'tb', $shortcuts ],
		],
		[
		[ 'Wx::Button', 'ok',     Wx::wxID_OK ],
		[ 'Wx::Button', 'cancel', Wx::wxID_CANCEL ],
		];

	if (@$shortcuts) {
		push @{ $layout[-1] }, [ 'Wx::Button', 'delete',     Wx::wxID_DELETE ];
		push @{ $layout[-1] }, [ 'Wx::Button', 'delete_all', Wx::gettext('Delete &All') ];
	}

	return \@layout;
}

sub dialog {
	my $class = shift;
	my $main  = shift;
	my $text  = shift;
	my $names = Padre::DB::Bookmark->select_names;
	my $title =
		$text
		? Wx::gettext("Set Bookmark")
		: Wx::gettext("GoTo Bookmark");

	my $layout = get_layout( $text, $names );
	$dialog = Padre::Wx::Dialog->new(
		parent => $main,
		title  => $title,
		layout => $layout,
		width  => [ 300, 50 ],
	);
	if ( $dialog->{_widgets_}->{entry} ) {
		$dialog->{_widgets_}->{entry}->SetSize( 10 * length $text, -1 );
	}

	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{_widgets_}->{ok},
		sub {
			$dialog->EndModal(Wx::wxID_OK);
		}
	);
	Wx::Event::EVT_BUTTON(
		$dialog,
		$dialog->{_widgets_}->{cancel},
		sub {
			$dialog->EndModal(Wx::wxID_CANCEL);
		}
	);
	$dialog->{_widgets_}->{ok}->SetDefault;

	if ( $dialog->{_widgets_}->{delete} ) {
		Wx::Event::EVT_BUTTON(
			$dialog,
			$dialog->{_widgets_}->{delete},
			\&on_delete_bookmark
		);
		Wx::Event::EVT_BUTTON(
			$dialog,
			$dialog->{_widgets_}->{delete_all},
			\&on_delete_all_bookmark
		);
	}

	if ($text) {
		$dialog->{_widgets_}->{entry}->SetFocus;
	} else {
		$dialog->{_widgets_}->{tb}->SetFocus;
	}

	return $dialog;
}

sub _get_data {
	my $dialog   = shift;
	my $shortcut = $dialog->{_widgets_}->{entry}->GetValue;
	$dialog->Destroy;
	$dialog = undef;
	return ( $dialog, { shortcut => $shortcut } );
}

sub set_bookmark {
	my $class   = shift;
	my $main    = shift;
	my $current = $main->current;
	my $editor  = $current->editor or return;
	my $path    = $current->filename;
	unless ( defined $path ) {
		$main->error( Wx::gettext("Cannot set bookmark in unsaved document") );
		return;
	}

	# Ask the user for the bookmark name
	my $line   = $editor->GetCurrentLine;
	my $file   = File::Basename::basename( $path || '' );
	my ($text) = $editor->GetLine($line);
	$text =~ s/\r?\n?$//;
	my $dialog = $class->dialog(
		$main,
		sprintf( Wx::gettext("%s line %s: %s"), $file, $line, $text )
	);
	$dialog->show_modal or return;

	# Create (or replace an existing) bookmark
	my $data = _get_data($dialog);
	my $name = delete $data->{shortcut} or return;
	Padre::DB->begin;
	Padre::DB::Bookmark->delete(
		'where name = ?', $name,
	);
	Padre::DB::Bookmark->create(
		name => $name,
		file => $path,
		line => $line,
	);
	Padre::DB->commit;

	return;
}

sub goto_bookmark {
	my $class = shift;
	my $main  = shift;

	# Show the bookmarks dialog
	my $dialog = $class->dialog($main);
	$dialog->show_modal or return;

	# Find the bookmark they selected
	my $treebook  = $dialog->{_widgets_}->{tb};
	my $selection = $treebook->GetSelection;
	my $name      = $treebook->GetPageText($selection);
	my $bookmark  = Padre::DB::Bookmark->fetch_name($name);
	unless ($bookmark) {

		# Deleted since the dialog was shown
		$main->error( sprintf( Wx::gettext("The bookmark '%s' no longer exists"), $name ) );
		return;
	}

	# Is the file already open
	my $file   = $bookmark->{file};
	my $line   = $bookmark->{line};
	my $pageid = $main->find_editor_of_file($file);

	unless ( defined $pageid ) {

		# Load the file
		if ( -e $file ) {
			$main->setup_editor($file);
			$pageid = $main->find_editor_of_file($file);
		}
	}

	# Go to the relevant editor and row
	if ( defined $pageid ) {
		$main->on_nth_pane($pageid);
		my $page = $main->notebook->GetPage($pageid);
		$page->goto_line_centerize($line);
	}

	return;
}

sub on_delete_bookmark {
	my $dialog = shift;

	# Locate the selected bookmark
	my $treebook  = $dialog->{_widgets_}->{tb};
	my $selection = $treebook->GetSelection;
	my $name      = $treebook->GetPageText($selection);
	my $bookmark  = Padre::DB::Bookmark->fetch_name($name);

	# Delete it from the database
	if ($bookmark) {
		$bookmark->delete;
	}

	# Delete it from the dialog
	$treebook->DeletePage($selection);

	return;
}

sub on_delete_all_bookmark {
	my $dialog = shift;

	# Delete everything from the database
	Padre::DB::Bookmark->truncate;

	# Delete everything from the dialog
	$dialog->{_widgets_}->{tb}->DeleteAllPages;

	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

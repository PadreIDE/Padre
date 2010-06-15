package Padre::Wx::Dialog::OpenResource;

use 5.008;
use strict;
use warnings;
use Cwd                        ();
use Padre::DB                  ();
use Padre::Wx                  ();
use Padre::Wx::Icon            ();
use Padre::Wx::Role::Main ();
use Padre::MimeTypes           ();
use Padre::Role::Task          ();

our $VERSION = '0.64';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::Main
	Wx::Dialog
};

# -- constructor
sub new {
	my $class = shift;
	my $main  = shift;

	# Create object
	my $self = $class->SUPER::new(
		$main,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE | Wx::wxTAB_TRAVERSAL,
	);

	$self->init_search;

	# Dialog's icon as is the same as Padre
	$self->SetIcon( Padre::Wx::Icon::PADRE );

	# Create dialog
	$self->_create;

	return $self;
}


#
# Initialize search
#
sub init_search {
	my $self     = shift;
	my $current  = $self->current;
	my $document = $current->document;
	my $filename = $current->filename;

	# Check if we have an open file so we can use its directory
	my $directory = $filename
		# Current document's project or base directory
		? Padre::Util::get_project_dir($filename)
			|| File::Basename::dirname($filename)
		# Current working directory
		: Cwd::getcwd();

	# Restart search if the project/current directory is different
	my $previous = $self->{directory};
	if ( $previous && $previous ne $directory ) {
		$self->{matched_files} = undef;
	}

	$self->{directory} = $directory;
	$self->SetLabel( Wx::gettext('Open Resource') . ' - ' . $directory );
}

# -- event handler

#
# handler called when the ok button has been clicked.
#
sub ok_button {
	my $self = shift;
	my $main = $self->main;

	$self->Hide;

	#Open the selected resources here if the user pressed OK
	my @selections = $self->{matches_list}->GetSelections;
	foreach my $selection ( @selections ) {
		my $filename = $self->{matches_list}->GetClientData($selection);

		# Fetch the recently used files from the database
		require Padre::DB::RecentlyUsed;
		my $recently_used = Padre::DB::RecentlyUsed->select(
			"where type = ? and value = ?",
			'RESOURCE',
			$filename,
		) || [];

		my $found = scalar @$recently_used > 0;

		eval {
			# Try to open the file now
			if ( my $id = $main->find_editor_of_file($filename) ) {
				my $page = $main->notebook->GetPage($id);
				$page->SetFocus;
			} else {
				$main->setup_editors($filename);
			}
		};
		if ( $@ ) {
			Wx::MessageBox(
				Wx::gettext('Error while trying to perform Padre action'),
				Wx::gettext('Error'),
				Wx::wxOK,
				$main,
			);
		} else {

			# And insert a recently used tuple if it is not found
			# and the action is successful.
			if ( $found ) {
				Padre::DB->do(
					"update recently_used set last_used = ? where name = ? and type = ?",
					{}, time(), $filename, 'RESOURCE',
				);
			} else {
				Padre::DB::RecentlyUsed->create(
					name      => $filename,
					value     => $filename,
					type      => 'RESOURCE',
					last_used => time(),
				);
			}
		}
	}

}


# -- private methods

#
# create the dialog itself.
#
sub _create {
	my $self = shift;

	# create sizer that will host all controls
	$self->{sizer} = Wx::BoxSizer->new(Wx::wxVERTICAL);

	# create the controls
	$self->_create_controls;
	$self->_create_buttons;

	# wrap everything in a vbox to add some padding
	$self->SetMinSize( [ 360, 340 ] );
	$self->SetSizer( $self->{sizer} );

	# center/fit the dialog
	$self->Fit;
	$self->CentreOnParent;
}

#
# create the buttons pane.
#
sub _create_buttons {
	my $self  = shift;

	$self->{ok_button} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		Wx::gettext('&OK'),
	);
	$self->{ok_button}->SetDefault;
	$self->{cancel_button} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		Wx::gettext('&Cancel'),
	);

	my $buttons = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{ok_button},     0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$buttons->Add( $self->{cancel_button}, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$self->{sizer}->Add( $buttons, 0, Wx::wxALL | Wx::wxEXPAND | Wx::wxALIGN_CENTER, 5 );

	Wx::Event::EVT_BUTTON( $self, Wx::wxID_OK, \&ok_button );
}

#
# create controls in the dialog
#
sub _create_controls {
	my $self = shift;

	# search textbox
	my $search_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('&Select an item to open (? = any character, * = any string):')
	);
	$self->{search_text} = Wx::TextCtrl->new(
		$self,
		-1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);

	# matches result list
	my $matches_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('&Matching Items:')
	);

	$self->{matches_list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		[],
		Wx::wxLB_EXTENDED,
	);

	# Shows how many items are selected and information about what is selected
	$self->{status_text} = Wx::TextCtrl->new(
		$self,
		-1,
		Wx::gettext('Current Directory: ') . $self->{directory},
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_READONLY,
	);

	my $folder_image = Wx::StaticBitmap->new(
		$self,
		-1,
		Padre::Wx::Icon::find("places/stock_folder")
	);

	$self->{copy_button} = Wx::BitmapButton->new(
		$self,
		-1,
		Padre::Wx::Icon::find("actions/edit-copy"),
	);

	$self->{popup_button} = Wx::BitmapButton->new(
		$self,
		-1,
		Padre::Wx::Icon::find("actions/down")
	);

	$self->{popup_menu} = Wx::Menu->new;
	$self->{skip_vcs_files} = $self->{popup_menu}->AppendCheckItem(
		-1,
		Wx::gettext("Skip version control system files"),
	);
	$self->{skip_using_manifest_skip} = $self->{popup_menu}->AppendCheckItem(
		-1,
		Wx::gettext("Skip using MANIFEST.SKIP"),
	);

	$self->{skip_vcs_files}->Check(1);
	$self->{skip_using_manifest_skip}->Check(1);

	my $hb;
	$self->{sizer}->AddSpacer(10);
	$self->{sizer}->Add( $search_label, 0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$hb = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$hb->AddSpacer(2);
	$hb->Add( $self->{search_text},  1, Wx::wxALIGN_CENTER_VERTICAL, 2 );
	$hb->Add( $self->{popup_button}, 0, Wx::wxALL | Wx::wxEXPAND,    2 );
	$hb->AddSpacer(1);
	$self->{sizer}->Add( $hb,                  0, Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$self->{sizer}->Add( $matches_label,       0, Wx::wxALL | Wx::wxEXPAND,    2 );
	$self->{sizer}->Add( $self->{matches_list}, 1, Wx::wxALL | Wx::wxEXPAND,    2 );
	$hb = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$hb->AddSpacer(2);
	$hb->Add( $folder_image,       0, Wx::wxALL | Wx::wxEXPAND,    1 );
	$hb->Add( $self->{status_text}, 1, Wx::wxALIGN_CENTER_VERTICAL, 1 );
	$hb->Add( $self->{copy_button}, 0, Wx::wxALL | Wx::wxEXPAND,    1 );
	$hb->AddSpacer(1);
	$self->{sizer}->Add( $hb, 0, Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$self->_setup_events;

	return;
}

#
# Adds various events
#
sub _setup_events {
	my $self = shift;

	Wx::Event::EVT_CHAR(
		$self->{search_text},
		sub {
			my $this  = shift;
			my $event = shift;
			my $code  = $event->GetKeyCode;

			$self->{matches_list}->SetFocus
				if ( $code == Wx::WXK_DOWN )
				or ( $code == Wx::WXK_NUMPAD_PAGEDOWN )
				or ( $code == Wx::WXK_PAGEDOWN );

			$event->Skip(1);
		}
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{search_text},
		sub {
			unless ( $self->{matched_files} ) {
				$self->search;
			}
			$self->render;
			return;
		}
	);

	Wx::Event::EVT_LISTBOX(
		$self,
		$self->{matches_list},
		sub {
			my $self         = shift;
			my @matches      = $self->{matches_list}->GetSelections;
			my $num_selected = scalar @matches;
			if ( $num_selected == 1 ) {
				$self->{status_text}->ChangeValue(
					$self->_path( $self->{matches_list}->GetClientData( $matches[0] ) )
				);
				$self->{copy_button}->Enable(1);
			} elsif ( $num_selected > 1 ) {
				$self->{status_text}->ChangeValue( $num_selected . " items selected" );
				$self->{copy_button}->Enable(0);
			} else {
				$self->{status_text}->ChangeValue('');
				$self->{copy_button}->Enable(0);
			}

			return;
		}
	);

	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->{matches_list},
		sub {
			$self->ok_button;
		}
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{copy_button},
		sub {
			my @matches      = $self->{matches_list}->GetSelections();
			my $num_selected = scalar @matches;
			if ( $num_selected == 1 ) {
				if ( Wx::wxTheClipboard->Open ) {
					Wx::wxTheClipboard->SetData(
						Wx::TextDataObject->new( $self->{matches_list}->GetClientData( $matches[0] ) )
					);
					Wx::wxTheClipboard->Close;
				}
			}
		}
	);

	Wx::Event::EVT_MENU(
		$self,
		$self->{skip_vcs_files},
		sub {
			$self->restart;
		},
	);
	Wx::Event::EVT_MENU(
		$self,
		$self->{skip_using_manifest_skip},
		sub {
			$self->restart;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{popup_button},
		sub {
			my ( $self, $event ) = @_;
			$self->PopupMenu(
				$self->{popup_menu},
				$self->{popup_button}->GetPosition->x,
				$self->{popup_button}->GetPosition->y +
				$self->{popup_button}->GetSize->GetHeight
			);
		}
	);

	$self->_show_recent_while_idle;
}

#
# Restarts search
#
sub restart {
	my $self = shift;
	$self->search;
	$self->render;
}

#
# Focus on it if it shown or restart its state and show it if it is hidden.
#
sub show {
	my $self = shift;

	$self->init_search;

	if ( $self->IsShown ) {
		$self->SetFocus;
	} else {
		my $editor = $self->current->editor;
		if ($editor) {
			my $selection        = $editor->GetSelectedText;
			my $selection_length = length $selection;
			if ( $selection_length > 0 ) {
				$self->{search_text}->ChangeValue($selection);
				$self->restart;
			} else {
				$self->{search_text}->ChangeValue('');
			}
		} else {
			$self->{search_text}->ChangeValue('');
		}

		$self->_show_recent_while_idle;

		$self->Show(1);
	}
}

#
# Shows recently opened stuff while idle
#
sub _show_recent_while_idle {
	my $self = shift;

	Wx::Event::EVT_IDLE(
		$self,
		sub {
			$self->_show_recently_opened_resources;

			# focus on the search text box
			$self->{search_text}->SetFocus;

			# unregister from idle event
			Wx::Event::EVT_IDLE( $self, undef );
		}
	);
}

#
# Shows the recently opened resources
#
sub _show_recently_opened_resources {
	my $self = shift;

	# Fetch them from Padre's RecentlyUsed database table
	require Padre::DB::RecentlyUsed;
	my $recently_used = Padre::DB::RecentlyUsed->select( 'where type = ?', 'RESOURCE' ) || [];
	my @recent_files  = ();
	foreach my $e ( @$recently_used ) {
		push @recent_files, $self->_path( $e->value );
	}
	@recent_files = sort {
		File::Basename::fileparse($a) cmp File::Basename::fileparse($b)
	} @recent_files;

	# Show results in matching items list
	$self->{matched_files} = \@recent_files;
	$self->render;

	# No need to store them anymore
	$self->{matched_files} = undef;
}

#
# Search for files and cache result
#
sub search {
	my $self = shift;

	$self->{status_text}->ChangeValue(
		Wx::gettext('Reading items. Please wait...')
	);

	# Kick off the resource search
	$self->task_request(
		task                     => 'Padre::Task::OpenResource',
		directory                => $self->{directory},
		skip_vcs_files           => $self->{skip_vcs_files}->IsChecked,
		skip_using_manifest_skip => $self->{skip_using_manifest_skip}->IsChecked,
	);

	return;
}

sub task_response {
	my $self    = shift;
	my $task    = shift;
	my $matched = $task->{matched} or return;
	$self->{matched_files} = $matched;
	$self->render;
	return 1;
}

#
# Update matches list box from matched files list
#
sub render {
	my $self = shift;
	return unless $self->{matched_files};

	my $search_expr = $self->{search_text}->GetValue;

	# Quote the search string to make it safer
	# and then tranform * and ? into .* and .
	$search_expr = quotemeta $search_expr;
	$search_expr =~ s/\\\*/.*?/g;
	$search_expr =~ s/\\\?/./g;

	#Populate the list box now
	$self->{matches_list}->Clear;
	my $pos = 0;
	foreach my $file ( @{ $self->{matched_files} } ) {
		my $filename = File::Basename::fileparse($file);
		if ( $filename =~ /^$search_expr/i ) {

			# Display package name if it is a Perl file
			my $pkg = '';
			my $mime_type = Padre::MimeTypes->guess_mimetype( undef, $file );
			if ( $mime_type eq 'application/x-perl' or $mime_type eq 'application/x-perl6' ) {
				my $contents = Padre::Util::slurp($file);
				if ( $contents && $$contents =~ /\s*package\s+(.+);/ ) {
					$pkg = "  ($1)";
				}
			}
			$self->{matches_list}->Insert( $filename . $pkg, $pos, $file );
			$pos++;
		}
	}
	if ( $pos > 0 ) {
		$self->{matches_list}->Select(0);
		$self->{status_text}->ChangeValue(
			$self->_path( $self->{matches_list}->GetClientData(0) )
		);
		$self->{status_text}->Enable(1);
		$self->{copy_button}->Enable(1);
		$self->{ok_button}->Enable(1);
	} else {
		$self->{status_text}->ChangeValue('');
		$self->{status_text}->Enable(0);
		$self->{copy_button}->Enable(0);
		$self->{ok_button}->Enable(0);
	}

	return;
}

#
# Cleans a path on various platforms
#
sub _path {
	my $self = shift;
	my $path = shift;
	if ( Padre::Constant::WIN32 ) {
		$path =~ s/\//\\/g;
	}
	return $path;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog::OpenResource - Open Resource dialog

=head1 DESCRIPTION

=head2 Open Resource (Shortcut: C<Ctrl+Shift+R>)

This opens a nice dialog that allows you to find any file that exists
in the current document or working directory. You can use C<?> to replace
a single character or C<*> to replace an entire string. The matched files list
are sorted alphabetically and you can select one or more files to be opened in
Padre when you press the B<OK> button.

You can simply ignore F<CVS>, F<.svn> and F<.git> folders using a simple check-box
(enhancement over Eclipse).

=head1 AUTHOR

Ahmad M. Zawawi E<lt>ahmad.zawawi at gmail.comE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

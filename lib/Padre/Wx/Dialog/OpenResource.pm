package Padre::Wx::Dialog::OpenResource;

use warnings;
use strict;

# package exports and version
our $VERSION   = '0.16';
our @EXPORT_OK = ();

# module imports
use Padre::Wx ();

# is a subclass of Wx::Dialog
use base 'Wx::Dialog';

# accessors
use Class::XSAccessor accessors => {
	_plugin                   => '_plugin',                   # plugin instance
	_sizer                    => '_sizer',                    # window sizer
	_search_text              => '_search_text',              # search text control
	_matches_list             => '_matches_list',             # matches list
	_status_text              => '_status_text',              # status label
	_directory                => '_directory',                # searched directory
	_matched_files            => '_matched_files',            # matched files list
	_copy_button              => '_copy_button',              # copy button
	_popup_button             => '_popup_button',             # popup button for options
	_popup_menu               => '_popup_menu',               # options popup menu
	_skip_vcs_files           => '_skip_vcs_files',           # Skip VCS files menu item
	_skip_using_manifest_skip => '_skip_using_manifest_skip', # Skip using MANIFEST.SKIP menu item
};

# -- constructor
sub new {
	my ( $class, $plugin, %opt ) = @_;

	#Check if we have an open file so we can use its directory
	my $main = $plugin->main;
	my $filename = ( defined $main->current->document ) ? $main->current->document->filename : undef;
	my $directory;
	if ($filename) {

		# current document's project or base directory
		$directory = Padre::Util::get_project_dir($filename)
			|| File::Basename::dirname($filename);
	} else {

		# current working directory
		$directory = Cwd::getcwd();
	}

	# create object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Open Resource') . ' - ' . $directory,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE | Wx::wxTAB_TRAVERSAL,
	);

	$self->SetIcon( Wx::GetWxPerlIcon() );
	$self->_directory($directory);
	$self->_plugin($plugin);

	# create dialog
	$self->_create;

	# Dialog's icon as is the same as plugin's
	$self->SetIcon( $plugin->logo_icon );

	return $self;
}


# -- event handler

#
# handler called when the ok button has been clicked.
#
sub _on_ok_button_clicked {
	my ($self) = @_;

	my $main = $self->_plugin->main;
	$self->Hide;

	#Open the selected resources here if the user pressed OK
	my @selections = $self->_matches_list->GetSelections();
	foreach my $selection (@selections) {
		my $filename = $self->_matches_list->GetClientData($selection);

		# Keep the last 20 recently opened resources available
		# and save it to plugin's configuration object
		my $config = $self->_plugin->config_read;
		my @recently_opened = split /\|/, $config->{recently_opened};
		if ( scalar @recently_opened >= 20 ) {
			shift @recently_opened;
		}
		push @recently_opened, $filename;
		my %unique = map { $_, 1 } @recently_opened;
		@recently_opened = keys %unique;
		@recently_opened = sort { File::Basename::fileparse($a) cmp File::Basename::fileparse($b) } @recently_opened;
		$config->{recently_opened} = join '|', @recently_opened;
		$self->_plugin->config_write($config);

		# try to open the file now
		if ( my $id = $main->find_editor_of_file($filename) ) {
			my $page = $main->notebook->GetPage($id);
			$page->SetFocus;
		} else {
			$main->setup_editors($filename);
		}
	}

}


# -- private methods

#
# create the dialog itself.
#
sub _create {
	my ($self) = @_;

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$self->_sizer($sizer);

	# create the controls
	$self->_create_controls;
	$self->_create_buttons;

	# wrap everything in a vbox to add some padding
	$self->SetMinSize( [ 315, 315 ] );
	$self->SetSizer($sizer);


	# focus on the search text box
	$self->_search_text->SetFocus();

	# center the dialog
	$self->Fit;
	$self->CentreOnParent;
}

#
# create the buttons pane.
#
sub _create_buttons {
	my ($self) = @_;
	my $sizer = $self->_sizer;

	my $butsizer = $self->CreateStdDialogButtonSizer( Wx::wxOK | Wx::wxCANCEL );
	$sizer->Add( $butsizer, 0, Wx::wxALL | Wx::wxEXPAND | Wx::wxALIGN_CENTER, 5 );
	Wx::Event::EVT_BUTTON( $self, Wx::wxID_OK, \&_on_ok_button_clicked );
}

#
# create controls in the dialog
#
sub _create_controls {
	my ($self) = @_;

	# search textbox
	my $search_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('&Select an item to open (? = any character, * = any string):')
	);
	$self->_search_text(
		Wx::TextCtrl->new(
			$self,                 -1, '',
			Wx::wxDefaultPosition, Wx::wxDefaultSize,
		)
	);

	# matches result list
	my $matches_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('&Matching Items:')
	);

	$self->_matches_list(
		Wx::ListBox->new(
			$self, -1, Wx::wxDefaultPosition, Wx::wxDefaultSize, [],
			Wx::wxLB_EXTENDED
		)
	);

	# Shows how many items are selected and information about what is selected
	$self->_status_text(
		Wx::TextCtrl->new(
			$self,                 -1,                Wx::gettext('Current Directory: ') . $self->_directory,
			Wx::wxDefaultPosition, Wx::wxDefaultSize, Wx::wxTE_READONLY
		)
	);

	my $folder_image = Wx::StaticBitmap->new(
		$self, -1,
		Padre::Wx::Icon::find("places/stock_folder")
	);

	$self->_copy_button(
		Wx::BitmapButton->new(
			$self, -1,
			Padre::Wx::Icon::find("actions/edit-copy")
		)
	);


	$self->_popup_button(
		Wx::BitmapButton->new(
			$self, -1,
			Padre::Wx::Icon::find("actions/down")
		)
	);
	$self->_popup_menu( Wx::Menu->new );
	$self->_skip_vcs_files( $self->_popup_menu->AppendCheckItem( -1, Wx::gettext("Skip VCS files") ) );
	$self->_skip_using_manifest_skip(
		$self->_popup_menu->AppendCheckItem( -1, Wx::gettext("Skip using MANIFEST.SKIP") ) );

	$self->_skip_vcs_files->Check(1);
	$self->_skip_using_manifest_skip->Check(1);

	my $hb;
	$self->_sizer->AddSpacer(10);
	$self->_sizer->Add( $search_label, 0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$hb = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$hb->AddSpacer(2);
	$hb->Add( $self->_search_text,  1, Wx::wxALIGN_CENTER_VERTICAL, 2 );
	$hb->Add( $self->_popup_button, 0, Wx::wxALL | Wx::wxEXPAND,    2 );
	$hb->AddSpacer(1);
	$self->_sizer->Add( $hb,                  0, Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$self->_sizer->Add( $matches_label,       0, Wx::wxALL | Wx::wxEXPAND,    2 );
	$self->_sizer->Add( $self->_matches_list, 1, Wx::wxALL | Wx::wxEXPAND,    2 );
	$hb = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$hb->AddSpacer(2);
	$hb->Add( $folder_image,       0, Wx::wxALL | Wx::wxEXPAND,    1 );
	$hb->Add( $self->_status_text, 1, Wx::wxALIGN_CENTER_VERTICAL, 1 );
	$hb->Add( $self->_copy_button, 0, Wx::wxALL | Wx::wxEXPAND,    1 );
	$hb->AddSpacer(1);
	$self->_sizer->Add( $hb, 0, Wx::wxBOTTOM | Wx::wxEXPAND, 5 );
	$self->_setup_events();

	return;
}

#
# Adds various events
#
sub _setup_events {
	my $self = shift;

	Wx::Event::EVT_CHAR(
		$self->_search_text,
		sub {
			my $this  = shift;
			my $event = shift;
			my $code  = $event->GetKeyCode;

			if ( $code == Wx::WXK_DOWN ) {
				$self->_matches_list->SetFocus();
			}

			$event->Skip(1);
		}
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->_search_text,
		sub {

			if ( not $self->_matched_files ) {
				$self->_search();
			}
			$self->_update_matches_list_box;

			return;
		}
	);

	Wx::Event::EVT_LISTBOX(
		$self,
		$self->_matches_list,
		sub {
			my $self         = shift;
			my @matches      = $self->_matches_list->GetSelections();
			my $num_selected = scalar @matches;
			if ( $num_selected == 1 ) {
				$self->_status_text->SetLabel( $self->_matches_list->GetClientData( $matches[0] ) );
				$self->_copy_button->Enable(1);
			} elsif ( $num_selected > 1 ) {
				$self->_status_text->SetLabel( $num_selected . " items selected" );
				$self->_copy_button->Enable(0);
			} else {
				$self->_status_text->SetLabel('');
				$self->_copy_button->Enable(0);
			}

			return;
		}
	);

	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->_matches_list,
		sub {
			$self->_on_ok_button_clicked();
		}
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->_copy_button,
		sub {
			my @matches      = $self->_matches_list->GetSelections();
			my $num_selected = scalar @matches;
			if ( $num_selected == 1 ) {
				if ( Wx::wxTheClipboard->Open() ) {
					Wx::wxTheClipboard->SetData(
						Wx::TextDataObject->new( $self->_matches_list->GetClientData( $matches[0] ) ) );
					Wx::wxTheClipboard->Close();
				}
			}
		}
	);

	Wx::Event::EVT_IDLE(
		$self,
		sub {
			$self->_show_recently_opened_resources;

			# focus on the search text box
			$self->_search_text->SetFocus;

			# unregister from idle event
			Wx::Event::EVT_IDLE( $self, undef );
		}
	);

	Wx::Event::EVT_MENU(
		$self,
		$self->_skip_vcs_files,
		sub { $self->_restart_search; },
	);
	Wx::Event::EVT_MENU(
		$self,
		$self->_skip_using_manifest_skip,
		sub { $self->_restart_search; },
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->_popup_button,
		sub {
			my ( $self, $event ) = @_;
			$self->PopupMenu(
				$self->_popup_menu,
				$self->_popup_button->GetPosition->x,
				$self->_popup_button->GetPosition->y + $self->_popup_button->GetSize->GetHeight
			);
		}
	);
}

#
# Restarts search
#
sub _restart_search() {
	my $self = shift;
	$self->_search();
	$self->_update_matches_list_box;
}

#
# Shows the recently opened resources
#
sub _show_recently_opened_resources() {
	my $self = shift;

	my $config = $self->_plugin->config_read;
	my @recently_opened = split /\|/, $config->{recently_opened};
	$self->_matched_files( \@recently_opened );
	$self->_update_matches_list_box;
	$self->_matched_files(undef);
}

#
# Search for files and cache result
#
sub _search() {
	my $self = shift;

	$self->_status_text->SetLabel( Wx::gettext("Reading items. Please wait...") );

	require Padre::Plugin::Ecliptic::OpenResourceSearchTask;
	my $search_task = Padre::Plugin::Ecliptic::OpenResourceSearchTask->new(
		dialog                   => $self,
		directory                => $self->_directory,
		skip_vcs_files           => $self->_skip_vcs_files->IsChecked,
		skip_using_manifest_skip => $self->_skip_using_manifest_skip->IsChecked,
	);
	$search_task->schedule;

	return;
}

#
# Update matches list box from matched files list
#
sub _update_matches_list_box() {
	my $self = shift;

	return if not $self->_matched_files;

	my $search_expr = $self->_search_text->GetValue();

	#quote the search string to make it safer
	#and then tranform * and ? into .* and .
	$search_expr = quotemeta $search_expr;
	$search_expr =~ s/\\\*/.*?/g;
	$search_expr =~ s/\\\?/./g;

	#Populate the list box now
	$self->_matches_list->Clear();
	my $pos = 0;
	foreach my $file ( @{ $self->_matched_files } ) {
		my $filename = File::Basename::fileparse($file);
		if ( $filename =~ /^$search_expr/i ) {
			$self->_matches_list->Insert( $filename, $pos, $file );
			$pos++;
		}
	}
	if ( $pos > 0 ) {
		$self->_matches_list->Select(0);
		$self->_status_text->SetLabel( $self->_matches_list->GetClientData(0) );
		$self->_status_text->Enable(1);
		$self->_copy_button->Enable(1);
	} else {
		$self->_status_text->SetLabel('');
		$self->_status_text->Enable(0);
		$self->_copy_button->Enable(0);
	}

	return;
}


1;

__END__

=head1 NAME

Padre::Wx::Dialog::OpenResource - Ecliptic's Open Resource dialog

=head1 DESCRIPTION

=head2 Open Resource (Shortcut: Ctrl + Shift + R)

This opens a nice dialog that allows you to find any file that exists 
in the current document or working directory. You can use ? to replace 
a single character or * to replace an entire string. The matched files list 
are sorted alphabetically and you can select one or more files to be opened in 
Padre when you press the OK button.

You can simply ignore CVS, .svn and .git folders using a simple checkbox 
(enhancement over Eclipse).

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 C<< <ahmad.zawawi at gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.
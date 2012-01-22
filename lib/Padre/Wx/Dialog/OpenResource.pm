package Padre::Wx::Dialog::OpenResource;

use 5.008;
use strict;
use warnings;
use Cwd                   ();
use Padre::DB             ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Wx::Role::Main ();
use Padre::MIME      ();
use Padre::Role::Task     ();
use Padre::Logger;

our $VERSION = '0.94';
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
		Wx::gettext('Open Resources'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);

	$self->init_search;

	# Dialog's icon as is the same as Padre
	$self->SetIcon(Padre::Wx::Icon::PADRE);

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
	my $project  = $current->project;

	# Check if we have an open file so we can use its directory
	my $directory = $filename

		# Current document's project or base directory
		? $project
			? $project->root
			: File::Basename::dirname($filename)

			# Current working directory
		: Cwd::getcwd();

	# Restart search if the project/current directory is different
	my $previous = $self->{directory};
	if ( $previous && $previous ne $directory ) {
		$self->{matched_files} = undef;
	}

	$self->{directory} = $directory;
	$self->SetLabel( Wx::gettext('Open Resources') . ' - ' . $directory );
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
	foreach my $selection (@selections) {
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
			if ( my $id = $main->editor_of_file($filename) ) {
				my $page = $main->notebook->GetPage($id);
				$page->SetFocus;
			} else {
				$main->setup_editors($filename);
			}
		};
		if ($@) {
			$main->error(sprintf( Wx::gettext('Error while trying to perform Padre action: %s'), $@ ));
			TRACE("Error while trying to perform Padre action: $@") if DEBUG;
		} else {

			# And insert a recently used tuple if it is not found
			# and the action is successful.
			if ($found) {
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
	$self->{sizer} = Wx::BoxSizer->new(Wx::VERTICAL);

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
	my $self = shift;

	$self->{ok_button} = Wx::Button->new(
		$self,
		Wx::ID_OK,
		Wx::gettext('&OK'),
	);
	$self->{ok_button}->SetDefault;
	$self->{cancel_button} = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext('&Cancel'),
	);

	my $buttons = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{ok_button},     0, Wx::ALL | Wx::EXPAND, 5 );
	$buttons->Add( $self->{cancel_button}, 0, Wx::ALL | Wx::EXPAND, 5 );
	$self->{sizer}->Add( $buttons, 0, Wx::ALL | Wx::EXPAND | Wx::ALIGN_CENTER, 5 );

	Wx::Event::EVT_BUTTON( $self, Wx::ID_OK, \&ok_button );
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
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{search_text}->SetToolTip( Wx::gettext('Enter parts of the resource name to find it') );

	$self->{popup_button} = Wx::BitmapButton->new(
		$self,
		-1,
		Padre::Wx::Icon::find("actions/go-down")
	);
	$self->{popup_button}->SetToolTip( Wx::gettext('Click on the arrow for filter settings') );

	# matches result list
	my $matches_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext('&Matching Items:')
	);

	$self->{matches_list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
		Wx::LB_EXTENDED,
	);
	$self->{matches_list}->SetToolTip( Wx::gettext('Select one or more resources to open') );

	# Shows how many items are selected and information about what is selected
	$self->{status_text} = Wx::TextCtrl->new(
		$self,
		-1,
		Wx::gettext('Current Directory: ') . $self->{directory},
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_READONLY,
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
	$self->{copy_button}->SetToolTip( Wx::gettext('Copy filename to clipboard') );

	$self->{popup_menu}     = Wx::Menu->new;
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
	$self->{sizer}->Add( $search_label, 0, Wx::ALL | Wx::EXPAND, 2 );
	$hb = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$hb->AddSpacer(2);
	$hb->Add( $self->{search_text},  1, Wx::ALIGN_CENTER_VERTICAL, 2 );
	$hb->Add( $self->{popup_button}, 0, Wx::ALL | Wx::EXPAND,      2 );
	$hb->AddSpacer(1);
	$self->{sizer}->Add( $hb,                   0, Wx::BOTTOM | Wx::EXPAND, 5 );
	$self->{sizer}->Add( $matches_label,        0, Wx::ALL | Wx::EXPAND,    2 );
	$self->{sizer}->Add( $self->{matches_list}, 1, Wx::ALL | Wx::EXPAND,    2 );
	$hb = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$hb->AddSpacer(2);
	$hb->Add( $folder_image,        0, Wx::ALL | Wx::EXPAND,      1 );
	$hb->Add( $self->{status_text}, 1, Wx::ALIGN_CENTER_VERTICAL, 1 );
	$hb->Add( $self->{copy_button}, 0, Wx::ALL | Wx::EXPAND,      1 );
	$hb->AddSpacer(1);
	$self->{sizer}->Add( $hb, 0, Wx::BOTTOM | Wx::EXPAND, 5 );
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
				if ( $code == Wx::K_DOWN )
				or ( $code == Wx::K_UP )
				or ( $code == Wx::K_NUMPAD_PAGEDOWN )
				or ( $code == Wx::K_PAGEDOWN )
				or ( $code == Wx::K_NUMPAD_PAGEUP )
				or ( $code == Wx::K_PAGEUP );


			$event->Skip(1);
		}
	);

	Wx::Event::EVT_CHAR(
		$self->{matches_list},
		sub {
			my $this  = shift;
			my $event = shift;
			my $code  = $event->GetKeyCode;

			$self->{search_text}->SetFocus
				unless ( $code == Wx::K_DOWN )
				or ( $code == Wx::K_UP )
				or ( $code == Wx::K_NUMPAD_PAGEDOWN )
				or ( $code == Wx::K_PAGEDOWN )
				or ( $code == Wx::K_NUMPAD_PAGEUP )
				or ( $code == Wx::K_PAGEUP );

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
				$self->{status_text}
					->ChangeValue( $self->_path( $self->{matches_list}->GetClientData( $matches[0] ) ) );
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
			my @matches      = $self->{matches_list}->GetSelections;
			my $num_selected = scalar @matches;
			if ( $num_selected == 1 ) {
				if ( Wx::TheClipboard->Open ) {
					Wx::TheClipboard->SetData(
						Wx::TextDataObject->new( $self->{matches_list}->GetClientData( $matches[0] ) ) );
					Wx::TheClipboard->Close;
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
				$self->{popup_button}->GetPosition->y + $self->{popup_button}->GetSize->GetHeight
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
	my $recently_used = Padre::DB::RecentlyUsed->select( 'where type = ? order by last_used desc', 'RESOURCE' ) || [];
	my @recent_files = ();
	foreach my $e (@$recently_used) {
		push @recent_files, $self->_path( $e->value );
	}

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

	$self->{status_text}->ChangeValue( Wx::gettext('Reading items. Please wait...') );

	# Kick off the resource search
	$self->task_request(
		task                     => 'Padre::Task::OpenResource',
		directory                => $self->{directory},
		skip_vcs_files           => $self->{skip_vcs_files}->IsChecked,
		skip_using_manifest_skip => $self->{skip_using_manifest_skip}->IsChecked,
	);

	return;
}

sub task_finish {
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

	# Save user selections for later
	my @matches = $self->{matches_list}->GetSelections;

	# prepare more general search expression
	my $is_perl_package_expr = 0;
	if ( $search_expr =~ s/\\:\\:/\//g ) { # undo quotemeta and substitute / for ::
		$is_perl_package_expr = 1;
	}
	if ( $search_expr =~ s/\\:/\//g ) {    # undo quotemeta and substitute / for :
		$is_perl_package_expr = 1;
	}

	# Populate the list box
	$self->{matches_list}->Clear;
	my $pos = 0;
	my %contains_file;

	# direct filename matches
	foreach my $file ( @{ $self->{matched_files} } ) {
		my $filename = File::Basename::fileparse($file);
		if ( $filename =~ /^$search_expr/i ) {

			# display package name if it is a Perl file
			my $pkg = '';
			my $mime_type = Padre::MIME->detect(
				file  => $file,
				perl6 => $self->config->lang_perl6_auto_detection,
			);
			if ( $mime_type eq 'application/x-perl' or $mime_type eq 'application/x-perl6' ) {
				my $contents = Padre::Util::slurp($file);
				if ( $contents && $$contents =~ /\s*package\s+(.+);/ ) {
					$pkg = "  ($1)";
				}
			}
			$self->{matches_list}->Insert( $filename . $pkg, $pos, $file );
			$contains_file{ $filename . $pkg } = 1;
			$pos++;
		}
	}

	# path matches
	my @ignore_path_extensions = '.t';
	foreach my $file ( @{ $self->{matched_files} } ) {
		if ( $file =~ /^$self->{directory}.+$search_expr/i ) {
			my ( $filename, $path, $suffix ) = File::Basename::fileparse( $file, @ignore_path_extensions );

			my $pkg_name = '';

			if ( length $suffix > 0 ) {
				next unless $filename =~ /$search_expr/i; # ignore path for certain files
				$filename .= $suffix;                     # add suffix again
			} else {

				# display package name if it is a Perl file
				my $mime_type = Padre::MIME->detect(
					file => $file,
					perl6 => $self->config->lang_perl6_auto_detection,
				);
				if ( $mime_type eq 'application/x-perl' or $mime_type eq 'application/x-perl6' ) {
					my $contents = Padre::Util::slurp($file);
					if ( $contents && $$contents =~ /\s*package\s+(.+);/ ) {
						$pkg_name = "  ($1)";
					}
				} else {
					next if $is_perl_package_expr;        # do nothing if input contains : or ::
				}
			}

			unless ( exists $contains_file{ $filename . $pkg_name } ) {
				$self->{matches_list}->Insert( $filename . $pkg_name, $pos, $file );
				$pos++;
			}
		}
	}

	if ( $pos > 0 ) {

		# keep the old user selection if it is possible
		$self->{matches_list}->Select( scalar @matches > 0 ? $matches[0] : 0 );
		$self->{status_text}->ChangeValue( $self->_path( $self->{matches_list}->GetClientData(0) ) );
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
	if (Padre::Constant::WIN32) {
		$path =~ s/\//\\/g;
	}
	return $path;
}

1;

__END__

=pod

=head1 NAME

Padre::Wx::Dialog::OpenResource - Open Resources dialog

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

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

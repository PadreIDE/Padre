package Padre::Wx::Dialog::HelpSearch;

use 5.008;
use strict;
use warnings;

# package exports and version
our $VERSION = '0.94';
our @ISA     = 'Wx::Dialog';

# module imports
use Padre::Wx       ();
use Padre::Wx::Icon ();
use Padre::Wx::HtmlWindow ();

# accessors
use Class::XSAccessor {
	accessors => {
		_hbox           => '_hbox',           # horizontal box sizer
		_topic_selector => '_topic_selector', # Topic selector
		_search_text    => '_search_text',    # search text control
		_list           => '_list',           # matches list
		_index          => '_index',          # help topic list
		_help_viewer    => '_help_viewer',    # HTML Help Viewer
		_main           => '_main',           # Padre's main window
		_topic          => '_topic',          # default help topic
		_help_provider  => '_help_provider',  # Help Provider
		_status         => '_status'          # status label
	}
};

# -- constructor
sub new {
	my ( $class, $main, %opt ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Help Search'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);

	$self->_main($main);
	$self->_topic( $opt{topic} || '' );

	# Dialog's icon as is the same as Padre
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# create dialog
	$self->_create;

	# fit and center the dialog
	$self->Fit;
	$self->CentreOnParent;

	return $self;
}

# Display a message in the help html window in big bold letters
sub _display_msg {
	my ( $self, $text ) = @_;
	$self->_help_viewer->SetPage(qq{<b><font size="+2">$text</font></b>});
}

#
# Fetches the current selection's help HTML
#
sub _display_help_in_viewer {
	my $self = shift;

	my ( $html, $location );
	my $selection = $self->_list->GetSelection;
	if ( $selection != -1 ) {
		my $topic = $self->_list->GetClientData($selection);

		if ( $topic && $self->_help_provider ) {
			eval { ( $html, $location ) = $self->_help_provider->help_render($topic); };
			if ($@) {
				$self->_display_msg( sprintf( Wx::gettext('Error while calling %s %s'), 'help_render', $@ ) );
				return;
			}
		}
	}

	if ($html) {

		# Highlights <pre> code sections with a grey background
		$html =~ s/<pre>/<table border="0" width="100%" bgcolor="#EEEEEE"><tr><td><pre>/ig;
		$html =~ s/<\/pre>/<\/pre\><\/td><\/tr><\/table>/ig;
	} else {
		$html = '<b><font size="+2">' . Wx::gettext('No Help found') . '</font></b>';
	}

	$self->SetTitle( Wx::gettext('Help Search') . ( defined $location ? ' - ' . $location : '' ) );
	$self->_help_viewer->SetPage($html);

	return;
}

#
# create the dialog itself.
#
sub _create {
	my $self = shift;

	# create sizer that will host all controls
	$self->_hbox( Wx::BoxSizer->new(Wx::HORIZONTAL) );

	# create the controls
	$self->_create_controls;

	# wrap everything in a box to add some padding
	$self->SetMinSize( [ 750, 550 ] );
	$self->SetSizer( $self->_hbox );

	return;
}

#
# create controls in the dialog
#
sub _create_controls {
	my $self = shift;

	my $topic_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('Select the help &topic')
	);
	my @topics = ('perl 5');
	$self->_topic_selector(
		Wx::Choice->new(
			$self, -1,
			Wx::DefaultPosition,
			Wx::DefaultSize,
			\@topics,
		)
	);

	#Wx::Event::EVT_CHOICE($self, $topic_selector, \&select_topic);

	# search textbox
	my $search_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('Type a help &keyword to read:')
	);
	$self->_search_text( Wx::TextCtrl->new( $self, -1, '' ) );

	# matches result list
	my $matches_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('&Matching Help Topics:')
	);
	$self->_list(
		Wx::ListBox->new(
			$self,
			-1,
			Wx::DefaultPosition,
			[ 180, -1 ],
			[],
			Wx::LB_SINGLE
		)
	);

	# HTML Help Viewer
	$self->_help_viewer(
		Padre::Wx::HtmlWindow->new(
			$self,
			-1,
			Wx::DefaultPosition,
			Wx::DefaultSize,
			Wx::BORDER_STATIC
		)
	);
	$self->_help_viewer->SetPage('');

	my $close_button = Wx::Button->new( $self, Wx::ID_CANCEL, Wx::gettext('&Close') );
	$self->_status( Wx::StaticText->new( $self, -1, '' ) );

	my $vbox = Wx::BoxSizer->new(Wx::VERTICAL);

	$vbox->Add( $topic_label,           0, Wx::ALL | Wx::EXPAND,     2 );
	$vbox->Add( $self->_topic_selector, 0, Wx::ALL | Wx::EXPAND,     2 );
	$vbox->Add( $search_label,          0, Wx::ALL | Wx::EXPAND,     2 );
	$vbox->Add( $self->_search_text,    0, Wx::ALL | Wx::EXPAND,     2 );
	$vbox->Add( $matches_label,         0, Wx::ALL | Wx::EXPAND,     2 );
	$vbox->Add( $self->_list,           1, Wx::ALL | Wx::EXPAND,     2 );
	$vbox->Add( $self->_status,         0, Wx::ALL | Wx::EXPAND,     0 );
	$vbox->Add( $close_button,          0, Wx::ALL | Wx::ALIGN_LEFT, 0 );
	$self->_hbox->Add( $vbox, 0, Wx::ALL | Wx::EXPAND, 2 );
	$self->_hbox->Add(
		$self->_help_viewer,                                                1,
		Wx::ALL | Wx::ALIGN_TOP | Wx::ALIGN_CENTER_HORIZONTAL | Wx::EXPAND, 1
	);

	$self->_setup_events;

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

			if ( $code == Wx::K_DOWN || $code == Wx::K_PAGEDOWN ) {
				$self->_list->SetFocus;
			}

			$event->Skip(1);
		}
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->_search_text,
		sub {

			$self->_update_list_box;

			return;
		}
	);

	Wx::Event::EVT_HTML_LINK_CLICKED(
		$self,
		$self->_help_viewer,
		\&_on_link_clicked,
	);


	Wx::Event::EVT_LISTBOX(
		$self,
		$self->_list,
		sub {
			$self->_display_help_in_viewer;
		}
	);

	return;
}

#
# Focus on it if it shown or restart its state and show it if it is hidden.
#
sub show {
	my ( $self, $topic ) = @_;

	if ( not $self->IsShown ) {
		if ( not $topic ) {
			$topic = $self->_find_help_topic || '';
		}
		$self->_topic($topic);
		$self->_search_text->ChangeValue( $self->_topic );
		my $document = Padre::Current->document;
		if ($document) {
			$self->_help_provider(undef);
		}
		$self->Show(1);
		$self->_search_text->Enable(0);
		$self->_topic_selector->Enable(0);
		$self->_list->Enable(0);
		$self->_display_msg( Wx::gettext('Reading items. Please wait') );
		Wx::Event::EVT_IDLE(
			$self,
			sub {
				$self->_index(undef);
				if ( $self->_update_list_box ) {
					$self->_search_text->Enable(1);
					$self->_topic_selector->Enable(1);
					$self->_list->Enable(1);
					$self->_search_text->SetFocus;
				} else {
					$self->_search_text->ChangeValue('');
				}
				Wx::Event::EVT_IDLE( $self, undef );
			}
		);
	}
	$self->_search_text->SetFocus;

	return;
}

#
# Search for files and cache result
#
sub _search {
	my $self = shift;

	# Generate a sorted file-list based on filename
	if ( not $self->_help_provider ) {
		my $document = Padre::Current->document;
		if ($document) {
			eval { $self->_help_provider( $document->get_help_provider ); };
			if ($@) {
				$self->_display_msg( sprintf( Wx::gettext('Error while calling %s %s'), 'get_help_provider', $@ ) );
				return;
			}
			if ( not $self->_help_provider ) {
				$self->_display_msg(
					Wx::gettext("Could not find a help provider for ") .
					Wx::gettext($document->mime->name)
				);
				return;
			}
		} else {

			# If there no document, use Perl 5 help provider
			require Padre::Document::Perl::Help;
			$self->_help_provider( Padre::Document::Perl::Help->new );
		}
	}
	return unless $self->_help_provider;
	eval { $self->_index( $self->_help_provider->help_list ); };
	if ($@) {
		$self->_display_msg( sprintf( Wx::gettext('Error while calling %s %s'), 'help_list', $@ ) );
		return;
	}

	return 1;
}

#
# Returns the selected or under the cursor help topic
#
sub _find_help_topic {
	my $self = shift;

	my $document = Padre::Current->document;
	return '' unless $document;

	my $topic = $document->find_help_topic;

	#fallback
	unless ($topic) {
		my $editor = $document->editor;
		my $pos    = $editor->GetCurrentPos;

		# The selected/under the cursor word is a help topic
		$topic = $editor->GetSelectedText;
		if ( not $topic ) {
			$topic = $editor->GetTextRange(
				$editor->WordStartPosition( $pos, 1 ),
				$editor->WordEndPosition( $pos, 1 )
			);
		}

		# trim whitespace
		$topic =~ s/^\s*(.*?)\s*$/$1/;
	}

	return $topic;
}

#
# Update matches list box from matched files list
#
sub _update_list_box {
	my $self = shift;

	# Clear the list and status
	$self->_list->Clear;
	$self->_status->SetLabel('');

	# Try to fetch a help index and return nothing if otherwise
	$self->_search unless $self->_index;
	return unless $self->_index;

	my $search_expr = $self->_search_text->GetValue;
	$search_expr = quotemeta $search_expr;

	#Populate the list box now
	my $pos = 0;
	foreach my $target ( @{ $self->_index } ) {
		if ( $target =~ /^$search_expr$/i ) {
			$self->_list->Insert( $target, 0, $target );
			$pos++;
		} elsif ( $target =~ /$search_expr/i ) {
			$self->_list->Insert( $target, $pos, $target );
			$pos++;
		}
	}
	if ( $pos > 0 ) {
		$self->_list->Select(0);
	}
	$self->_status->SetLabel( sprintf( Wx::gettext("Found %s help topic(s)\n"), $pos ) );
	$self->_display_help_in_viewer;

	return 1;
}

#
# Called when the user clicks a link in the
# help viewer HTML window
#
sub _on_link_clicked {
	my $self = shift;
	require URI;
	my $uri      = URI->new( $_[0]->GetLinkInfo->GetHref );
	my $linkinfo = $_[0]->GetLinkInfo;
	my $scheme   = $uri->scheme;
	if ( defined($scheme) and $scheme eq 'perldoc' ) {

		# handle 'perldoc' links
		my $topic = $uri->path;
		$topic =~ s/^\///;
		$self->_search_text->SetValue($topic);
	} else {

		# otherwise, let the default browser handle it...
		Padre::Wx::launch_browser($uri);
	}
}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::HelpSearch - Padre Shiny Help Search Dialog

=head1 DESCRIPTION

This opens a dialog where you can search for help topics...

Note: This used to be Perl 6 Help Dialog (in C<Padre::Plugin::Perl6>) and but it
has been moved to Padre core.

In order to setup a help system see L<Padre::Help>.

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

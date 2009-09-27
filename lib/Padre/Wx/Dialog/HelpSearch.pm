package Padre::Wx::Dialog::HelpSearch;

use 5.008;
use strict;
use warnings;

# package exports and version
our $VERSION = '0.47';
our @ISA     = 'Wx::Dialog';

# module imports
use Padre::Wx       ();
use Padre::Wx::Icon ();

# accessors
use Class::XSAccessor accessors => {
	_hbox          => '_hbox',          # horizontal box sizer
	_search_text   => '_search_text',   # search text control
	_list          => '_list',          # matches list
	_index         => '_index',         # help topic list
	_help_viewer   => '_help_viewer',   # HTML Help Viewer
	_main          => '_main',          # Padre's main window
	_topic         => '_topic',         # default help topic
	_help_provider => '_help_provider', # Help Provider
	_status        => '_status'         # status label
};

# -- constructor
sub new {
	my ( $class, $main, %opt ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Help Search'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE | Wx::wxTAB_TRAVERSAL,
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


#
# Fetches the current selection's help HTML
#
sub _display_help_in_viewer {
	my $self = shift;

	my ( $html, $location );
	my $selection = $self->_list->GetSelection();
	if ( $selection != -1 ) {
		my $topic = $self->_list->GetClientData($selection);

		if ( $topic && $self->_help_provider ) {
			eval { ( $html, $location ) = $self->_help_provider->help_render($topic); };
			if ($@) {
				warn "Error while calling help_render: $@\n";
			}
		}
	}

	if ($html) {

		# Highlights <pre> code sections with a grey background
		$html =~ s/<pre>/<table border="0" width="100%" bgcolor="#EEEEEE"><tr><td><pre>/ig;
		$html =~ s/<\/pre>/<\/pre\><\/td><\/tr><\/table>/ig;
	} else {
		$html = '<b>' . Wx::gettext('No Help found') . '</b>';
	}

	$self->SetTitle( Wx::gettext('Help Search') . ( defined $location ? ' - ' . $location : '' ) );
	$self->_help_viewer->SetPage($html);

	return;
}

# -- private methods

#
# create the dialog itself.
#
sub _create {
	my $self = shift;

	# create sizer that will host all controls
	$self->_hbox( Wx::BoxSizer->new(Wx::wxHORIZONTAL) );

	# create the controls
	$self->_create_controls;

	# wrap everything in a box to add some padding
	$self->SetMinSize( [ 640, 480 ] );
	$self->SetSizer( $self->_hbox );

	return;
}

#
# create controls in the dialog
#
sub _create_controls {
	my $self = shift;

	# search textbox
	my $search_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('&Type a help topic to read:')
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
			Wx::wxDefaultPosition,
			[ 180, -1 ],
			[],
			Wx::wxLB_SINGLE
		)
	);

	# HTML Help Viewer
	require Padre::Wx::HtmlWindow;
	$self->_help_viewer(
		Padre::Wx::HtmlWindow->new(
			$self,
			-1,
			Wx::wxDefaultPosition,
			Wx::wxDefaultSize,
			Wx::wxBORDER_STATIC
		)
	);
	$self->_help_viewer->SetPage('');

	my $close_button = Wx::Button->new( $self, Wx::wxID_CANCEL, Wx::gettext('&Close') );
	$self->_status( Wx::StaticText->new( $self, -1, '' ) );

	my $vbox = Wx::BoxSizer->new(Wx::wxVERTICAL);

	$vbox->Add( $search_label,       0, Wx::wxALL | Wx::wxEXPAND,     2 );
	$vbox->Add( $self->_search_text, 0, Wx::wxALL | Wx::wxEXPAND,     2 );
	$vbox->Add( $matches_label,      0, Wx::wxALL | Wx::wxEXPAND,     2 );
	$vbox->Add( $self->_list,        1, Wx::wxALL | Wx::wxEXPAND,     2 );
	$vbox->Add( $self->_status,      0, Wx::wxALL | Wx::wxEXPAND,     0 );
	$vbox->Add( $close_button,       0, Wx::wxALL | Wx::wxALIGN_LEFT, 0 );
	$self->_hbox->Add( $vbox, 0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$self->_hbox->Add(
		$self->_help_viewer,                                                        1,
		Wx::wxALL | Wx::wxALIGN_TOP | Wx::wxALIGN_CENTER_HORIZONTAL | Wx::wxEXPAND, 1
	);

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

			if ( $code == Wx::WXK_DOWN || $code == Wx::WXK_PAGEDOWN ) {
				$self->_list->SetFocus();
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
		\&on_link_clicked,
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
sub showIt {
	my ( $self, $topic ) = @_;

	if ( not $self->IsShown ) {
		if ( not $topic ) {
			$topic = $self->find_help_topic || '';
		}
		$self->_topic($topic);
		$self->_search_text->ChangeValue( $self->_topic );
		my $doc = Padre::Current->document;
		if ($doc) {
			$self->_help_provider(undef);
		}
		$self->_search;
		$self->_update_list_box;
		$self->Show(1);
	}
	$self->_search_text->SetFocus();

	return;
}

#
# Search for files and cache result
#
sub _search {
	my $self = shift;

	# a default..
	my @empty = ();
	$self->_index( \@empty );

	# Generate a sorted file-list based on filename
	if ( not $self->_help_provider ) {
		my $doc = Padre::Current->document;
		if ($doc) {
			eval { $self->_help_provider( $doc->get_help_provider ); };
			if ($@) {
				warn "Error while calling get_help_provider: $@\n";
			}
		}
	}
	return if not $self->_help_provider;
	eval {
		my @targets_index = @{ $self->_help_provider->help_list };
		$self->_index( \@targets_index );
	};
	if ($@) {
		warn "Error while calling help_list: $@\n";
	}

	return;
}

#
# Returns the selected or under the cursor help topic
#
sub find_help_topic {
	my $self = shift;

	my $topic = '';
	my $doc   = Padre::Current->document;
	if ($doc) {
		my $editor = $doc->editor;
		my $pos    = $editor->GetCurrentPos;
		if ( $doc->isa('Padre::Document::Perl') ) {
			require PPI;
			my $text = $editor->GetText;
			my $doc  = PPI::Document->new( \$text );

			# Find token under the cursor!
			my $line       = $editor->LineFromPosition($pos);
			my $line_start = $editor->PositionFromLine($line);
			my $line_end   = $editor->GetLineEndPosition($line);
			my $col        = $pos - $line_start;

			require Padre::PPI;
			my $token = Padre::PPI::find_token_at_location(
				$doc, [ $line + 1, $col + 1 ],
			);

			if ($token) {
				print $token->class . "\n";
				if ( $token->isa('PPI::Token::Symbol') ) {
					if ( $token->content =~ /^[\$\@\%].+?$/ ) {
						$topic = 'perldata';
					}
				} elsif ( $token->isa('PPI::Token::Operator') ) {
					$topic = $token->content;
				}
			}

		}


		unless ($topic) {

			#fallback

			# The selected/under the cursor word is a help topic
			$topic = $editor->GetSelectedText;
			if ( not $topic ) {
				$topic = $editor->GetTextRange(
					$editor->WordStartPosition( $pos, 1 ),
					$editor->WordEndPosition( $pos, 1 )
				);
			}
		}
	}

	return $topic;
}

#
# Update matches list box from matched files list
#
sub _update_list_box {
	my $self = shift;

	if ( not $self->_index ) {
		$self->_search;
	}

	my $search_expr = $self->_search_text->GetValue();
	$search_expr = quotemeta $search_expr;

	#Populate the list box now
	$self->_list->Clear();
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
	$self->_status->SetLabel("Found $pos help topic(s)\n");
	$self->_display_help_in_viewer;

	return;
}

#
# Called when the user clicks a link in the
# help viewer HTML window
#
sub on_link_clicked {
	my $self = shift;
	require URI;
	my $uri      = URI->new( $_[0]->GetLinkInfo->GetHref );
	my $linkinfo = $_[0]->GetLinkInfo;
	my $scheme   = $uri->scheme;
	if ( $scheme eq 'perldoc' ) {

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

=head1 NAME

Padre::Wx::Dialog::HelpSearch - Padre Shiny Help Search Dialog

=head1 DESCRIPTION

This opens a dialog where you can search for help topics... 

Note: This used to be Perl 6 Help Dialog (in Padre::Plugin::Perl6) and but it
has been moved to Padre core

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

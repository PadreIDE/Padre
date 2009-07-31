package Padre::Wx::DocBrowser;

use 5.008;
use strict;
use warnings;
use URI                   ();
use Encode                ();
use Scalar::Util          ();
use List::MoreUtils       ();
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();
use Scalar::Util          ();
use Params::Util qw(
	_INSTANCE _INVOCANT _CLASSISA _HASH _STRING
);
use Padre::Wx::AuiManager   ();
use Padre::Wx::Dialog       ();
use Padre::Task::DocBrowser ();
use Padre::DocBrowser       ();
use Padre::Util qw( _T );
use Wx::Perl::Dialog::Simple ();

our $VERSION = '0.42';
our @ISA     = 'Wx::Frame';

use Class::XSAccessor accessors => {
	notebook => 'notebook',
	provider => 'provider',
};

our %VIEW = (
	'text/html'   => 'Padre::Wx::HtmlWindow',
	'text/xhtml'  => 'Padre::Wx::HtmlWindow',
	'text/x-html' => 'Padre::Wx::HtmlWindow',
);

=pod

=head1 NAME

Padre::Wx::DocBrowser - Wx front-end for Padre::DocBrowser

=head1 Welcome to Padre DocBrowser

Padre::Wx::DocBrowser ( Wx::Frame )

=head1 DESCRIPTION

User interface for Padre::DocBrowser. 

=head1 METHODS

=head2 new

Constructor , see L<Wx::Frame>

=head2 help

Accepts a string, L<URI> or L<Padre::Document> and attempts to render 
documentation for such in a new AuiNoteBook tab. Links matching a scheme 
accepted by L<Padre::DocBrowser> will (when clicked) be resolved and 
displayed in a new tab.

=head2 display

Accepts a L<Padre::Document> or workalike

=head1 SEE ALSO

L<Padre::DocBrowser> L<Padre::Task::DocBrowser>

=cut

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'DocBrowser',
		Wx::wxDefaultPosition,
		[ 750, 700 ],
	);

	$self->{provider} = Padre::DocBrowser->new;

	# Until we get a real icon use the same one as the others
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	my $top_s = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $but_s = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	my $notebook = Wx::AuiNotebook->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_DEFAULT_STYLE
	);
	$self->notebook($notebook);

	my $entry = Wx::TextCtrl->new(
		$self, -1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);
	$entry->SetToolTip( Wx::ToolTip->new("Search for perldoc - eg Padre::Task, Net::LDAP") );

	Wx::Event::EVT_TEXT_ENTER(
		$self, $entry,
		sub {
			$self->OnSearchTextEnter($entry);
		}
	);

	# this could be lame:
	$self->{_searchEntry} = $entry;

	my $label = Wx::StaticText->new(
		$self,                 -1, 'Search',
		Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxALIGN_RIGHT
	);
	$label->SetToolTip( Wx::ToolTip->new("Search for perldoc - eg Padre::Task, Net::LDAP") );

	$but_s->Add( $label, 2, Wx::wxALIGN_RIGHT | Wx::wxALIGN_CENTER_VERTICAL );
	$but_s->Add( $entry, 1, Wx::wxALIGN_RIGHT | Wx::wxALIGN_CENTER_VERTICAL );

	$top_s->Add( $but_s,    0, Wx::wxEXPAND );
	$top_s->Add( $notebook, 1, Wx::wxGROW );
	$self->SetSizer($top_s);

	#$self->_setup_welcome;

	# to do this we really need a menu bar... trial this
	# not really the case now.. create fictional EVT_MENU items as needed.
	# http://www.perl.com/lpt/a/960
	# try to add an Accelerator Table for the escape key for the window
	# http://www.nntp.perl.org/group/perl.wxperl.users/2008/06/msg5924.html
	#my $table = Wx::AcceleratorTable->new( [wxACCEL_NORMAL, WXK_ESCAPE, $menuid ] );
	#$self->SetAcceleratorTable( $table );
	my $exitMenu = Wx::Menu->new();

	#my @menu_id;
	$exitMenu->Append( Wx::wxID_CLOSE, Wx::gettext("&Close\tCtrl+W") );
	$exitMenu->Append( Wx::wxID_OPEN,  Wx::gettext("&Open\tCtrl+O") );
	my $exitID = Wx::NewId;

	$exitMenu->Append( $exitID, Wx::gettext("E&xit\tCtrl+X") );

	my $menuBar = Wx::MenuBar->new();
	$menuBar->Append( $exitMenu, "File" );
	$self->SetMenuBar($menuBar);

	my $table = Wx::AcceleratorTable->new( [ Wx::wxACCEL_NORMAL, Wx::WXK_ESCAPE, $exitID ] );
	$self->SetAcceleratorTable($table);

	# you can create fictional menu items for use by the accelerator table
	Wx::Event::EVT_MENU( $self, $exitID,        sub { $_[0]->_close(); } );
	Wx::Event::EVT_MENU( $self, Wx::wxID_CLOSE, sub { $_[0]->_close_tab(); } );
	Wx::Event::EVT_MENU( $self, Wx::wxID_OPEN,  sub { $_[0]->_open_doc(); } );

	# not sure about this but we want to throw the close X event ot _close so it gets
	# rid of a busy cursor if it's busy..
	# bind the close event to our close method

	# This doesn't work... !!!   :(  It should do though!
	# http://www.nntp.perl.org/group/perl.wxperl.users/2007/06/msg3154.html
	# http://www.gigi.co.uk/wxperl/pdk/perltrayexample.txt
	# use a similar syntax.... for some reason this doesn't call _close()

	# TODO: Figure out what needs to be done to check and shutdown a
	# long running thread
	# To trigger this, search for perltoc in the search text entry.

	Wx::Event::EVT_CLOSE( $self, sub { $_[0]->_close(); } );

	$self->SetAutoLayout(1);

	return $self;
}

sub OnLinkClicked {
	my $self     = shift;
	my $uri      = URI->new( $_[0]->GetLinkInfo->GetHref );
	my $linkinfo = $_[0]->GetLinkInfo;
	my $scheme   = $uri->scheme;
	if ( $self->provider->accept( $uri->scheme ) ) {
		$self->ResolveRef($uri);
	} else {
		Padre::Wx::launch_browser($uri);
	}
}

sub OnSearchTextEnter {
	my $self = shift;
	my $text = $_[0]->GetValue;

	# need to see where to put the busy cursor
	# we want to see a busy cursor
	# cheating a bit here:
	$self->{_busyCursor} = Wx::BusyCursor->new();

	$self->ResolveRef($text);
}

sub help {
	my ( $self, $query, $hint ) = @_;

	if ( _INSTANCE( $query, 'Padre::Document' ) ) {
		$query = $self->padre2docbrowser($query);
	}

	my %hints = (
		$self->_hints,
		_HASH($hint) ? %$hint : (),
	);

	if ( _INVOCANT($query) and $query->isa('Padre::DocBrowser::document') ) {

		return $self->display($query)
			if $self->viewer_for( $query->guess_mimetype );

		my $render   = $self->provider->viewer_for( $query->mimetype );
		my $generate = $self->provider->provider_for( $query->mimetype );

		if ($generate) {
			my $task = Padre::Task::DocBrowser->new(
				document         => $query,
				type             => 'docs',
				args             => \%hints,
				main_thread_only => sub {
					$self->display( $_[0], $query );
				},
			);
			$task->schedule;
			return 1;
		}
		if ($render) {
			my $talk = Padre::Task::DocBrowser->new(
				document         => $query,
				type             => 'browse',
				args             => \%hints,
				main_thread_only => sub {
					$self->display( $_[0], $query );
				}
			);

		}
		$self->not_found( $query, \%hints );
		return;
	} elsif ( defined $query ) {
		my $task = Padre::Task::DocBrowser->new(
			document         => $query,
			type             => 'resolve',
			args             => \%hints,
			main_thread_only => sub {
				$self->help( $_[0], { referrer => $query } );
			}
		);
		$task->schedule;
		return 1;
	} else {
		$self->not_found( $hints{referrer} );
	}
}

sub ResolveRef {
	my ( $self, $ref ) = @_;
	my $task = Padre::Task::DocBrowser->new(
		document         => $ref,
		type             => 'resolve',
		args             => { $self->_hints },
		main_thread_only => sub {
			if ( $_[0] ) {
				$self->display( $_[0], $ref );
			} else {
				$self->not_found($ref);
			}
		}
	);
	$task->schedule;
}

# FIXME , add our own output panel
sub debug {
	Padre->ide->wx->main->output->AppendText( $_[1] . $/ );
}

=head2 display


=cut

sub display {
	my ( $self, $docs, $query ) = @_;
	if ( _INSTANCE( $docs, 'Padre::DocBrowser::document' ) ) {

		# if doc is html just display it
		# TODO, a means to register other wx display windows such as ?!
		return $self->ShowPage( $docs, $query )
			if ( $self->viewer_for( $docs->mimetype ) );

		my $task = Padre::Task::DocBrowser->new(
			document         => $docs,
			type             => 'browse',
			main_thread_only => sub {
				$self->display( $_[0], $query );
			}
		);
		$task->schedule;
		return 1;
	} else {
		$self->not_found( $docs, $query );

	}
}

sub ShowPage {
	my ( $self, $docs, $query ) = @_;
	unless ( _INSTANCE( $docs, 'Padre::DocBrowser::document' ) ) {
		return $self->not_found($query);
	}

	my $title = Wx::gettext('Untitled');
	my $mime  = 'text/xhtml';

	# Best effort to title the tab ANYTHING more useful
	# than 'Untitled'
	if ( _INSTANCE( $query, 'Padre::DocBrowser::document' ) ) {
		$title = $query->title;
	} elsif ( $docs->title ) {
		$title = $docs->title;
	} elsif ( _STRING($query) ) {
		$title = $query;
	}

	# Bashing on Indicies in the attempt to replace an open
	# tab with the same title.
	my $found = $self->notebook->GetPageCount;
	my @opened;
	my $i = 0;
	while ( $i < $found ) {
		my $page = $self->notebook->GetPage($i);
		if ( $self->notebook->GetPageText($i) eq $title ) {
			push @opened,
				{
				page  => $page,
				index => $i,
				};
		}
		$i++;
	}
	if ( my $last = pop @opened ) {
		$last->{page}->SetPage( $docs->body );
		$self->notebook->SetSelection( $last->{index} );
	} else {
		my $page = $self->NewPage( $docs->mimetype, $title );
		$page->SetPage( $docs->body );
	}

	# and turn off the busy cursor
	$self->{_busyCursor} = undef;

	# not sure if I can do this:
	# yep seems I can!
	$self->{_searchEntry}->SetFocus();

}

sub NewPage {
	my ( $self, $mime, $title ) = @_;
	my $page = eval {
		if ( exists $VIEW{$mime} )
		{
			my $class = $VIEW{$mime};
			unless ( $class->VERSION ) {
				eval "require $class;";
				die("Failed to load $class: $@") if $@;
			}
			my $panel = $class->new($self);
			Wx::Event::EVT_HTML_LINK_CLICKED(
				$self, $panel,
				\&OnLinkClicked,
			);
			$self->notebook->AddPage( $panel, $title, 1 );
			$panel;
		} else {
			$self->debug("DocBrowser: no viewer for $mime");
		}
	};
	return $page;
}

sub padre2docbrowser {
	my ( $class, $padredoc ) = @_;
	my $doc = Padre::DocBrowser::document->new(
		mimetype => $padredoc->get_mimetype,
		title    => $padredoc->get_title,
		filename => $padredoc->filename,
	);

	# Erk - shouldn't this be ->get_text or something.
	$doc->body( Encode::encode( 'utf8', $padredoc->{original_content} ) );

	$doc->mimetype( $doc->guess_mimetype ) unless $doc->mimetype;

	return $doc;
}

sub not_found {

	# trying a dialog rather than the open tab.
	my ( $self, $query, $hints ) = @_;

	# we got this far, make the cursor not busy
	$self->{_busyCursor} = undef;

	$query ||= $hints->{referrer};
	use Wx qw(wxOK wxCENTRE wxICON_INFORMATION);
	my $notFound = Wx::MessageDialog->new(
		$self,
		"Searched for '$query' and failed...",
		'Help not found.',
		wxOK | wxCENTRE | wxICON_INFORMATION
	);

	$notFound->ShowModal;
	$notFound->Destroy;

	# set focus back to the entry.
	$self->{_searchEntry}->SetFocus();

}

# Private methods

# There are some things only the instance knows , like desired locale
#  or how to derive a title from a documentation section
sub _hints {
	return (
		  ( Padre::Locale::iso639() eq Padre::Locale::system_iso639() )
		? ()
		: ( lang => Padre::Locale::iso639() ),

		title_from_section => Wx::gettext('NAME'),
	);
}

sub _close {
	my ($self) = @_;

	print "Going to close the docbrowser\n";

	# in case we have a busy cursor still:
	$self->{_busyCursor} = undef;

	$self->Close();
}

sub _close_tab {
	my ( $self, $event ) = @_;

	# When we get an Wx::AuiNotebookEvent from it will try to close
	# the notebook no matter what. For the other events we have to
	# close the tab manually which we do in the close() function
	# Hence here we don't allow the automatic closing of the window.
	if ( $event and $event->isa('Wx::AuiNotebookEvent') ) {
		$event->Veto;
	}

	my $notebook = $self->notebook;
	my $id       = $notebook->GetSelection;
	return if $id == -1;

	$self->notebook->DeletePage($id);

	return 1;

}

sub _open_doc {
	my $self     = shift;
	my $filename = Wx::Perl::Dialog::Simple::file_selector();
	if ( defined $filename ) {
		my $doc = Padre::DocBrowser::document->load($filename);
		$self->help( $doc, $filename );
	}
}

sub viewer_for {
	my ( $self, $mimetype ) = @_;
	return unless defined $mimetype;
	if ( exists $VIEW{$mimetype} ) {
		return $VIEW{$mimetype};
	}
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


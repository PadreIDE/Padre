package Padre::Wx::Browser;

=pod

=head1 NAME

Padre::Wx::Browser - Wx front-end for C<Padre::Browser>

=head1 Welcome to Padre C<Browser>

C<Padre::Wx::Browser> ( C<Wx::Frame> )

=head1 DESCRIPTION

User interface for C<Padre::Browser>.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use URI                   ();
use Encode                ();
use Scalar::Util          ();
use Params::Util          ();
use Padre::Util           ('_T');
use Padre::Browser        ();
use Padre::Task::Browser  ();
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();
use Padre::Wx::Icon       ();
use Padre::Wx::AuiManager ();
use Padre::Role::Task     ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Role::Task
	Wx::Dialog
};

our %VIEW = (
	'text/html'   => 'Padre::Wx::HtmlWindow',
	'text/xhtml'  => 'Padre::Wx::HtmlWindow',
	'text/x-html' => 'Padre::Wx::HtmlWindow',
);

=pod

=head2 new

Constructor , see L<Wx::Frame>

=cut

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(
		undef,
		-1,
		Wx::gettext('Help'),
		Wx::DefaultPosition,
		[ 750, 700 ],
		Wx::DEFAULT_FRAME_STYLE,
	);

	$self->{provider} = Padre::Browser->new;

	# Until we get a real icon use the same one as the others
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	my $top_s = Wx::BoxSizer->new(Wx::VERTICAL);
	my $but_s = Wx::BoxSizer->new(Wx::HORIZONTAL);

	$self->{notebook} = Wx::AuiNotebook->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::AUI_NB_DEFAULT_STYLE
	);

	$self->{search} = Wx::TextCtrl->new(
		$self, -1,
		'',
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_PROCESS_ENTER
	);
	$self->{search}->SetToolTip( Wx::ToolTip->new( Wx::gettext('Search for perldoc - e.g. Padre::Task, Net::LDAP') ) );

	Wx::Event::EVT_TEXT_ENTER(
		$self,
		$self->{search},
		sub {
			$self->on_search_text_enter( $self->{search} );
		}
	);

	my $label = Wx::StaticText->new(
		$self, -1, Wx::gettext('Search:'),
		Wx::DefaultPosition, [ 50, -1 ],
		Wx::ALIGN_RIGHT
	);
	$label->SetToolTip( Wx::ToolTip->new( Wx::gettext('Search for perldoc - e.g. Padre::Task, Net::LDAP') ) );

	my $close_button = Wx::Button->new( $self, Wx::ID_CANCEL, Wx::gettext('&Close') );

	$but_s->Add( $label,          0, Wx::ALIGN_CENTER_VERTICAL );
	$but_s->Add( $self->{search}, 1, Wx::ALIGN_LEFT | Wx::ALIGN_CENTER_VERTICAL );
	$but_s->AddStretchSpacer(2);
	$but_s->Add( $close_button, 0, Wx::ALIGN_RIGHT | Wx::ALIGN_CENTER_VERTICAL );

	$top_s->Add( $but_s,            0, Wx::EXPAND );
	$top_s->Add( $self->{notebook}, 1, Wx::GROW );
	$self->SetSizer($top_s);

	#$self->_setup_welcome;

	# not sure about this but we want to throw the close X event ot on_close so it gets
	# rid of a busy cursor if it's busy..
	# bind the close event to our close method

	# This doesn't work... !!!   :(  It should do though!
	# http://www.nntp.perl.org/group/perl.wxperl.users/2007/06/msg3154.html
	# http://www.gigi.co.uk/wxperl/pdk/perltrayexample.txt
	# use a similar syntax.... for some reason this doesn't call on_close()

	# TO DO: Figure out what needs to be done to check and shutdown a
	# long running thread
	# To trigger this, search for perltoc in the search text entry.

	Wx::Event::EVT_CLOSE(
		$self,
		sub {
			$_[0]->on_close;
		}
	);

	$self->SetAutoLayout(1);

	return $self;
}





######################################################################
# Event Handlers

sub on_close {
	my $self = shift;
	TRACE("Closing the docbrowser") if DEBUG;

	# In case we have a busy cursor still:
	$self->{busy} = undef;

	$self->Destroy;
}

sub on_search_text_enter {
	my $self  = shift;
	my $event = shift;
	my $text  = $event->GetValue;

	# need to see where to put the busy cursor
	# we want to see a busy cursor
	# cheating a bit here:
	$self->{busy} = Wx::BusyCursor->new;

	$self->resolve($text);
}

sub on_html_link_clicked {
	my $self = shift;
	my $uri  = URI->new( $_[0]->GetLinkInfo->GetHref );
	if ( $self->{provider}->accept( $uri->scheme ) ) {
		$self->resolve($uri);
	} else {
		Padre::Wx::launch_browser($uri);
	}
}





######################################################################
# General Methods

=pod

=head2 help

Accepts a string, L<URI> or L<Padre::Document> and attempts to render
documentation for such in a new C<AuiNoteBook> tab. Links matching a scheme
accepted by L<Padre::Browser> will (when clicked) be resolved and
displayed in a new tab.

=cut

sub help {
	my $self     = shift;
	my $document = shift;
	my $hint     = shift;

	if ( Params::Util::_INSTANCE( $document, 'Padre::Document' ) ) {
		$document = $self->padre2docbrowser($document);
	}

	my %hints = (
		$self->_hints,
		Params::Util::_HASH($hint) ? %$hint : (),
	);

	if ( Params::Util::_INVOCANT($document) and $document->isa('Padre::Browser::Document') ) {
		if ( $self->viewer_for( $document->guess_mimetype ) ) {
			return $self->display($document);
		}

		my $render   = $self->{provider}->viewer_for( $document->mimetype );
		my $generate = $self->{provider}->provider_for( $document->mimetype );

		if ($generate) {
			$self->task_request(
				task     => 'Padre::Task::Browser',
				document => $document,
				method   => 'docs',
				args     => \%hints,
				then     => 'display',
			);
			return 1;
		}
		if ($render) {
			$self->task_request(
				task     => 'Padre::Task::Browser',
				document => $document,
				method   => 'browse',
				args     => \%hints,
				then     => 'display',
			);
			return 1;
		}
		$self->not_found( $document, \%hints );
		return;
	} elsif ( defined $document ) {
		$self->task_request(
			task     => 'Padre::Task::Browser',
			document => $document,
			method   => 'resolve',
			args     => \%hints,
			then     => 'help',
		);
		return 1;
	} else {
		$self->not_found( $hints{referrer} );
	}
}

sub resolve {
	my $self     = shift;
	my $document = shift;
	$self->task_request(
		task     => 'Padre::Task::Browser',
		document => $document,
		method   => 'resolve',
		args     => { $self->_hints },
		then     => 'display',
	);
}

# FIX ME , add our own output panel
sub debug {
	Padre->ide->wx->main->output->AppendText( $_[1] . $/ );
}

=pod

=head2 display

Accepts a L<Padre::Document> or work-alike

=cut

sub display {
	my $self  = shift;
	my $docs  = shift;
	my $query = shift;

	if ( Params::Util::_INSTANCE( $docs, 'Padre::Browser::Document' ) ) {

		# if doc is html just display it
		# TO DO, a means to register other wx display windows such as ?!
		if ( $self->viewer_for( $docs->mimetype ) ) {
			return $self->show_page( $docs, $query );
		}

		$self->task_request(
			task     => 'Padre::Task::Browser',
			method   => 'browse',
			document => $docs,
			then     => 'display',
		);

		return 1;
	} else {
		$self->not_found( $docs, $query );

	}
}

sub task_finish {
	my $self     = shift;
	my $task     = shift;
	my $then     = $task->{then};
	my $document = $task->{document};
	my $result   = $task->{result};
	if ( $then eq 'display' ) {
		return $self->not_found($document) unless $result;
		return $self->display( $result, $document );
	}
	if ( $then eq 'help' ) {
		return $self->help( $result, { referrer => $document } );
	}
	return 1;
}

sub show_page {
	my $self  = shift;
	my $docs  = shift;
	my $query = shift;

	unless ( Params::Util::_INSTANCE( $docs, 'Padre::Browser::Document' ) ) {
		return $self->not_found($query);
	}

	my $title = Wx::gettext('Untitled');
	my $mime  = 'text/xhtml';

	# Best effort to title the tab ANYTHING more useful
	# than 'Untitled'
	if ( Params::Util::_INSTANCE( $query, 'Padre::Browser::Document' ) ) {
		$title = $query->title;
	} elsif ( $docs->title ) {
		$title = $docs->title;
	} elsif ( Params::Util::_STRING($query) ) {
		$title = $query;
	}

	# Bashing on Indicies in the attempt to replace an open
	# tab with the same title.
	my $found = $self->{notebook}->GetPageCount;
	my @opened;
	my $i = 0;
	while ( $i < $found ) {
		my $page = $self->{notebook}->GetPage($i);
		if ( $self->{notebook}->GetPageText($i) eq $title ) {
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
		$self->{notebook}->SetSelection( $last->{index} );
	} else {
		my $page = $self->new_page( $docs->mimetype, $title );
		$page->SetPage( $docs->body );
	}

	# and turn off the busy cursor
	$self->{busy} = undef;

	# not sure if I can do this:
	# yep seems I can!
	$self->{search}->SetFocus;

}

sub new_page {
	my $self  = shift;
	my $mime  = shift;
	my $title = shift;
	my $page  = eval {
		if ( exists $VIEW{$mime} )
		{
			my $class = $VIEW{$mime};
			unless ( $class->VERSION ) {
				eval "require $class;";
				die "Failed to load $class: $@" if $@;
			}
			my $panel = $class->new($self);
			Wx::Event::EVT_HTML_LINK_CLICKED(
				$self, $panel,
				sub {
					shift->on_html_link_clicked(@_);
				},
			);
			$self->{notebook}->AddPage( $panel, $title, 1 );
			$panel;
		} else {
			$self->debug( sprintf( Wx::gettext('Browser: no viewer for %s'), $mime ) );
		}
	};
	return $page;
}

sub padre2docbrowser {
	my $class    = shift;
	my $padredoc = shift;
	my $doc      = Padre::Browser::Document->new(
		mimetype => $padredoc->mimetype,
		title    => $padredoc->get_title,
		filename => $padredoc->filename,
	);

	$doc->body( Encode::encode( 'utf8', $padredoc->text_get ) );

	$doc->mimetype( $doc->guess_mimetype ) unless $doc->mimetype;

	return $doc;
}

# trying a dialog rather than the open tab.
sub not_found {
	my $self  = shift;
	my $query = shift;
	my $hints = shift;

	# We got this far, make the cursor not busy
	$self->{busy} = undef;

	$query ||= $hints->{referrer};
	my $dialog = Wx::MessageDialog->new(
		$self,
		sprintf( Wx::gettext("Searched for '%s' and failed..."), $query ),
		Wx::gettext('Help not found.'),
		Wx::OK | Wx::CENTRE | Wx::ICON_INFORMATION
	);

	$dialog->ShowModal;
	$dialog->Destroy;

	# Set focus back to the entry.
	$self->{search}->SetFocus;
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

sub viewer_for {
	my $self = shift;
	my $mimetype = shift or return;
	if ( exists $VIEW{$mimetype} ) {
		return $VIEW{$mimetype};
	}
	return;
}

1;

__END__

=pod

=head1 SEE ALSO

L<Padre::Browser> L<Padre::Task::Browser>

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


package Padre::Wx::DocBrowser;

use 5.008;
use strict;
use warnings;
use URI            ();
use Scalar::Util   ();
use Class::Autouse ();

use Padre::Wx ();

use base 'Wx::Frame';
use Padre::Wx::HtmlWindow;
use Scalar::Util qw( blessed );
use Params::Util qw( _INSTANCE );
use Padre::Wx::AuiManager ();
use Padre::Task::DocBrowser;

our $VERSION = '0.24';

use Class::XSAccessor 
	accessors => {
		notebook => 'notebook',
		provider => 'provider',
	};

our %VIEW = (
	'text/xhtml'   => 'Padre::Wx::HtmlWindow',
	'text/html'    => 'Padre::Wx::HtmlWindow',
	'text/x-html'  => 'Padre::Wx::HtmlWindow',
);

=pod

=head1 Welcome to Padre DocBrowser

=head1 NAME

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

=head2 show

TO BE COMPLETED


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
		[750, 700],
	);

	$self->{provider} = Padre::DocBrowser->new;

	my $top_s = Wx::BoxSizer->new( Wx::wxVERTICAL );
	my $but_s = Wx::BoxSizer->new( Wx::wxHORIZONTAL );

	my $notebook = Wx::AuiNotebook->new(
		$self,
		Wx::wxID_ANY,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_DEFAULT_STYLE
	);
	$self->notebook($notebook);

	my $entry = Wx::TextCtrl->new( 
		$self , -1 , 
		'search terms..' ,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);

	Wx::Event::EVT_TEXT_ENTER( $self, $entry, 
		sub {
			$self->on_search_text_enter( $entry );
		}
	);


	my $label = Wx::StaticText->new( $self, -1 , 'Search'  ,
		Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxALIGN_RIGHT
	);
 	$but_s->Add( $label, 2, Wx::wxALIGN_RIGHT |  Wx::wxALIGN_CENTER_VERTICAL   );
	$but_s->Add( $entry, 1, Wx::wxALIGN_RIGHT |  Wx::wxALIGN_CENTER_VERTICAL );

	$top_s->Add( $but_s,    0, Wx::wxEXPAND );
 	$top_s->Add( $notebook, 1, Wx::wxGROW   );
	$self->SetSizer( $top_s );
	$self->SetAutoLayout(1);
	$self->_setup_welcome;

	return $self;
}

# Bad - this looks like a virtual, really a eventhandler
sub OnLinkClicked {
	my ($self,$event) = @_;
	my $htmlinfo = $event->GetLinkInfo;
	my $href = $htmlinfo->GetHref;

	my $uri = URI->new( $href );
	my $scheme = $uri->scheme;
	$self->debug( "Link clicked is $uri" );
	if ( $self->provider->accept( $scheme ) ) {
		$self->help( $uri );
	}
	else {
		Wx::LaunchDefaultBrowser( $uri );
	}

}


sub on_search_text_enter {
	my ($self,$event) = @_;
	$self->debug( "SEARCH $self - $event " );
	my $text = $event->GetValue;
	$self->help($text);

}

# Compat with old PodFrame help ?
sub show {
	shift->help( @_ );
}

sub help {
	my ($self,$query,%hints) = @_;
	my $type;
	if ( Scalar::Util::blessed($query) && $query->can( 'get_mimetype' ) ) {
		$self->debug( "Help from mimetype, " . $query->get_mimetype );
		my $task = Padre::Task::DocBrowser->new(
			document => $query , type=>'docs' ,
			main_thread_only => sub { $self->display($_[0],$query) },
		);
		$task->schedule;
	return 1;
	}
	elsif ( defined $query ) {
		$self->debug( "resolve '$query'" );
		my $task = Padre::Task::DocBrowser->new(
			document => $query , type=>'resolve', 
			main_thread_only => sub { $self->help($_[0],referrer=>$query) }
		);
		$task->schedule;
		return 1;
	}
	else {
		$self->not_found( $hints{referrer} );
	}
}

sub ResolveRef {
	my ($self,$ref) = @_;
	warn "Resolve ref '$ref'";
	my $task = Padre::Task::DocBrowser->new(
		document => $ref , type=>'resolve' ,
		main_thread_only => sub { $self->display($_[0],$ref) }
	);
	$task->schedule;
	
}

# FIXME , add our own output panel
sub debug {
	my ($self,$string) = @_;
	Padre->ide->wx->
		main_window->{gui}{output_panel}->AppendText( $string . $/ );

}

sub display {
	my ($self,$docs,$query) = @_;
	if ( _INSTANCE( $docs, 'Padre::Document' ) ) {
		$self->debug( 
			sprintf("Display %s results of query %s" , 
				$docs->get_mimetype , $query
			)
		);
		my $task = Padre::Task::DocBrowser->new(
			document=>$docs, type=>'browse', 
			main_thread_only => 
				sub { $self->ShowPage( shift, $query ) }
		);
		$task->schedule;
	}
	elsif ( _INSTANCE( $query ,'Padre::Document')  ) {
		#warn "TRY 2 render the query instead";
		my $task = Padre::Task::DocBrowser->new(
			document=>$query, type=>'browse', 
			main_thread_only =>
				sub { $self->ShowPage( shift || $query, $query )  }
		);
	$task->schedule;
	}
	
}

sub ShowPage {
	my ($self,$docs,$query) = @_;

	unless ( _INSTANCE( $docs, 'Padre::Document' ) ) {
		return $self->not_found( $query );
	}

	my $title = 'Untitled';
	my $mime = 'text/xhtml';

	if ( Scalar::Util::blessed($query) and $query->isa("Padre::Document") ) {
		$title = $query->get_title;
	}
	else { $title = $docs->get_title };

	my $page = $self->NewPage( $docs->get_mimetype, $title );
	$self->debug( 
		sprintf( "Showpage '%s' from query %s", $title, $query )
	); 

	$page->SetPage( $docs->{original_content}  );

}

sub NewPage {
	my ($self,$mime,$title) = @_;
	my $page = eval {
		if ( exists $VIEW{$mime} ) {
			Class::Autouse->autouse( $VIEW{$mime} );
			my $panel = $VIEW{$mime}->new( $self );
			Wx::Event::EVT_HTML_LINK_CLICKED($self, $panel, \&OnLinkClicked );
			$self->notebook->AddPage( $panel, $title , 1 );
			$panel;
		}
		else { $self->debug( "NO VIEWER FOR $mime" ) }
	};

	$self->debug( $@ ) if $@;
	return $page;

}

sub not_found { 
	my ($self,$query) = @_;
	my $html = qq|
<html><body>
<h1>Not Found</h1>
<p>Could not find documentation for
<pre>$query</pre>
</p>
</body>
</html>
|;
	my $frame = Padre::Wx::HtmlWindow->new( $self );
	$self->notebook->AddPage( $frame , 'Not Found' , 1 );
	$frame->SetPage( $html );

}

sub _setup_welcome {
	my $self = shift;
	$self->help( URI->new( 'perldoc:Padre::Wx::DocBrowser' ) );
return;
	my $window = Padre::Wx::HtmlWindow->new( $self );
	$window->SetPage(
qq|
<html><body>
<h1>Welcome to Padre DocBrowser</h1>
</body></html>
|
	);
	$self->{notebook}->AddPage(
		$window,
		'Padre DocBrowser',
		1
	);
}

1;


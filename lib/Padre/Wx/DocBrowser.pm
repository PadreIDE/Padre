package Padre::Wx::DocBrowser;
use strict;
use warnings;
use Padre::Wx ();

use base 'Wx::Frame';
use Scalar::Util qw( blessed );
use Padre::Wx::AuiManager ();
use URI qw();
use Padre::DocBrowser;
use Class::Autouse;
use Class::XSAccessor 
    accessors => { notebook => 'notebook' , provider=>'provider' };
    
our $VERSION = '0.22';

our %VIEW = (
  'text/xhtml' => 'Padre::Wx::HtmlWindow',
);

our %PROVIDER = (
  'Pod' => 'Padre::Wx::DocBrowser::POD',
  
);


=pod

=head1 Welcome to Padre DocBrowser

=head1 NAME

Padre::Wx::DocBrowser ( Wx::Frame )

=head1 DESCRIPTION

User interface for Padre::DocBrowser

=head1 METHODS

=head2 new

Constructor , see L<Wx::Frame>

=head2 help

Accepts a string, L<URI> or L<Padre::Document> and attempts to render 
documentation for such in a new AuiNoteBook tab. 

=head1 BUGS

Window destruction not handled. Closing the DocBrowser and reopening it, 
ala via Help menu - crashes.

=head1 SEE ALSO

L<Padre::DocBrowser>



=cut

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new( undef,
	                             -1,
	                             'DocBrowser',
	                             Wx::wxDefaultPosition,
	                             [750, 700],
	                             );
	$self->{provider} = Padre::DocBrowser->new;

	my $top_s   = Wx::BoxSizer->new( Wx::wxVERTICAL );
	my $but_s   = Wx::BoxSizer->new( Wx::wxHORIZONTAL );

	my $nb = Wx::AuiNotebook->new(
		$self,
	        Wx::wxID_ANY,
                Wx::wxDefaultPosition,
                Wx::wxDefaultSize,
		Wx::wxAUI_NB_DEFAULT_STYLE
	);
        $self->notebook($nb);




	my $entry = Wx::TextCtrl->new( $self , -1 , 
		'search terms..' ,
	   Wx::wxDefaultPosition,
	   Wx::wxDefaultSize ,
	 , Wx::wxTE_PROCESS_ENTER
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
 	$but_s->Add( $label, 1, Wx::wxALIGN_RIGHT   );
	$but_s->Add( $entry );

	$top_s->Add( $but_s , 0 , Wx::wxEXPAND  );
 	$top_s->Add( $nb , 1,  Wx::wxGROW  );
	$self->SetSizer( $top_s );
	$self->SetAutoLayout( 1 );
	#$self->_setup_providers;
	#$self->_setup_notebook;
	$self->_setup_welcome;
	
	#$self->_setup_viewers();
	#$self->_create_menu_bar;
	return $self;
}

use Data::Dumper;


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
	

}


sub on_search_text_enter {
	my ($self,$event) = @_;
	$self->debug( "SEARCH $self - $event " );
	my $text = $event->GetValue;
	$self->help($text);

}

sub help {
  my ($self,$query,%hints) = @_;
  my $type;
  if (blessed $query && $query->can( 'get_mimetype' ) ) {
    $self->debug( "Help from mimetype doc" );
    my $docs = $self->{provider}->docs( $query );
    $self->display( $docs, $query );
    return;
  }
  elsif ( my $ref = $self->{provider}->resolve( $query ) ) {
    $self->debug(  "Help from '$query' resolved as $ref" );
    my $docs = $self->{provider}->docs( $ref );
    $self->debug( "Help from '$query rendered as $docs" );
     
    $self->display( $docs, $ref );	  	  
  }
  else {
	  $self->debug( "no help today" );
  }
}

sub debug {
    my ($self,$string) = @_;
    Padre->ide->wx->main_window
	->{gui}{output_panel}->AppendText( $string . $/ );
	
}

sub display {
  my ($self,$docs,$query) = @_;
  $self->debug( "Display $docs" );
  
  my $show = $self->{provider}->browse( $docs );

  my $title = 'Untitled';
  if ( blessed $query and $query->isa("Padre::Document") ) {	
	    $title = $query->get_title;
  }
eval {
  if ( exists $VIEW{$show->get_mimetype} ) {
	  Class::Autouse->autouse( $VIEW{$show->get_mimetype} );
	  my $panel = $VIEW{$show->get_mimetype}->new( 
	    $self,
	  );
	  Wx::Event::EVT_HTML_LINK_CLICKED( $self, $panel, \&OnLinkClicked );

	    $self->notebook->AddPage( 
		$panel, $title , 1
	    );
	    $panel->SetPage( $show->{original_content} );
  }
 
};

$self->debug( $@ ) if $@;
  
}

sub _setup_welcome {
	my $self = shift;
$self->help( URI->new( 'perldoc:Padre::Wx::DocBrowser' ) );
return;
	my $window = Padre::Wx::HtmlWindow->new( $self );
	$window->SetPage(qq|
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


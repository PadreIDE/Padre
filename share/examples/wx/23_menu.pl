#!/usr/bin/perl 
use strict;
use warnings;


#############################################################################
## Copyright:   (c) The Padre development team
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

# see package main at the bottom of the file


#####################
package Demo::Menu;
use strict;
use warnings FATAL => 'all';

use base 'Wx::App';

sub OnInit {
	my $frame = Demo::Frame->new;
	$frame->Show(1);
}

#####################
package Demo::Frame;
use strict;
use warnings FATAL => 'all';


use Wx ':everything';
use Wx::Event ':everything';

use base 'Wx::Frame';

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'Editor ',
		[ -1,  -1 ],
		[ 750, 700 ],
	);
	my $nb = Wx::Notebook->new(
		$self, -1, wxDefaultPosition, wxDefaultSize,
		wxNO_FULL_REPAINT_ON_RESIZE | wxCLIP_CHILDREN
	);

	$self->_create_menu_bar;

	return $self;
}

sub _create_menu_bar {
	my ($self) = @_;

	my $bar  = Wx::MenuBar->new;
	my $file = Wx::Menu->new;
	$file->Append( wxID_EXIT, "E&xit" );
	$file->Append( 998,       "&Open Browser to PerlMonks" );
	$bar->Append( $file, "&File" );

	$self->SetMenuBar($bar);

	EVT_CLOSE( $self, \&on_close_window );
	EVT_MENU( $self, 998, sub { Wx::LaunchDefaultBrowser('http://perlmonks.org/'); } );
	EVT_MENU( $self, wxID_EXIT, \&on_exit );

	return;
}

sub on_exit {
	my ($self) = @_;
	$self->Close;
}


sub on_close_window {
	my ( $self, $event ) = @_;
	$event->Skip;
}



#####################
package main;

my $app = Demo::Menu->new;
$app->MainLoop;


#!/usr/bin/perl

package main;

use 5.008;
use strict;
use warnings;

$| = 1;

my $app = Demo::App->new;
$app->MainLoop;

package Demo::App;

use strict;
use warnings;
use base 'Wx::App';

our $frame;

sub OnInit {
	$frame = Demo::App::Frame->new;
	$frame->Show(1);
}

package Demo::App::Frame;

use strict;
use warnings;
use Wx qw(:everything);
use base 'Wx::Frame';

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef, -1,
		'Demo::App',
		wxDefaultPosition, wxDefaultSize,
	);

	my $button = Wx::Button->new( $self, -1, "What is this smell?" );
	Wx::Event::EVT_BUTTON(
		$self, $button,
		sub {
			my ( $self, $event ) = @_;
			print "printing to STDOUT\n";
			print STDERR "printing to STDERR\n";
			Wx::MessageBox( "This is the smell of an Onion", "Title", wxOK | wxCENTRE, $self );
		}
	);
	$self->SetSize( $button->GetSizeWH );

	Wx::Event::EVT_CLOSE(
		$self,
		sub {
			my ( $self, $event ) = @_;
			$event->Skip;
		}
	);
	return $self;
}

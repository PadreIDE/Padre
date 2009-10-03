#!/usr/bin/perl

package main;

use 5.008;
use strict;
use warnings;

$| = 1;

# create the WxApplication
my $app = Demo::App->new;
$app->MainLoop;

package Demo::App;
use strict;
use warnings;
use base 'Wx::App';

sub OnInit {
	my $frame = Demo::App::Frame->new;
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

	my $text = Wx::StaticText->new( $self, -1, "Hello world" );

	#$self->SetSize($text->GetSizeWH);

	return $self;
}


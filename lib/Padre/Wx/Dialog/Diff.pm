package Padre::Wx::Dialog::Diff;

use 5.008;
use strict;
use warnings;
use Padre::Wx ();

our $VERSION = '0.91';
our @ISA     = 'Wx::PlPopupTransientWindow';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	my $panel = Wx::Panel->new( $self, -1 );
	$panel->SetBackgroundColour(Wx::WHITE);
	$self->SetBackgroundColour(Wx::WHITE);
	$self->{st} =  Wx::TextCtrl->new(
		$panel, -1,
		'',
		, [ -1, -1 ], [ -1, -1 ]
	);
	my $sz = $self->{st}->GetBestSize;

	#$self->SetSize( ( $sz->GetWidth + 20, $sz->GetHeight + 20 ) );
	$self->SetSize( $panel->GetSize );

	return $self;
}

sub show {

	my $self    = shift;
	my $message = shift;

	$self->{st}->SetValue($message);	$self->Show(1);
}

sub ProcessLeftDown {
	my ( $self, $event ) = @_;
	print "Process Left $event\n";

	#$event->Skip;
	return 0;
}

sub OnDismiss {
	my ( $self, $event ) = @_;
	print "OnDismiss\n";

	#$event->Skip;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Dialog::Text;

use 5.008;
use strict;
use warnings;

use Padre::Wx;
use Padre::Wx::Dialog;
use Wx::Locale qw(:default);

our $VERSION = '0.43';

sub get_layout {
	my ($text) = @_;

	my $width     = 300;
	my $multiline = 1;
	my @layout    = (
		[ [ 'Wx::TextCtrl', 'display', $text, 300, $multiline ] ],
		[   [ 'Wx::Button', 'ok', Wx::wxID_OK ],
		],
	);

	return \@layout;
}

sub dialog {
	my ( $class, $main, $title, $text ) = @_;

	my $layout = get_layout($text);
	my $dialog = Padre::Wx::Dialog->new(
		parent => $main,
		title  => $title,
		layout => $layout,
		width  => [ 300, 50 ],
	);

	#	if ($dialog->{_widgets_}->{display}) {
	#		$dialog->{_widgets_}->{display}->SetSize(10 * length $text, -1);
	#	}
	#

	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{ok}, sub { $dialog->EndModal(Wx::wxID_OK) } );
	$dialog->{_widgets_}->{ok}->SetDefault;

	$dialog->{_widgets_}->{ok}->SetFocus;

	return $dialog;
}

sub show {
	my ( $class, $main, $title, $text ) = @_;

	my $dialog = $class->dialog( $main, $title, $text );
	$dialog->show_modal;
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

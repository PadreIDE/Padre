package Padre::Wx::Dialog::Encode;

use 5.008;
use strict;
use warnings;
use Padre::Wx         ();
use Padre::Wx::Dialog ();

our $VERSION = '0.49';

# Encode document to System Default
# Encode document to utf-8
# Encode document to ...
sub _encode {
	my ( $window, $encoding ) = @_;

	my $doc = $window->current->document;
	$doc->{encoding} = $encoding;
	$doc->save_file if $doc->filename;
	$window->refresh;

	$window->message( Wx::gettext( sprintf( 'Document encoded to (%s)', $doc->{encoding} ) ) );
	return;
}

sub encode_document_to_system_default {
	my ( $window, $event ) = @_;
	_encode( $window, Padre::Locale::encoding_system_default() || 'utf-8' );
	return;
}

sub encode_document_to_utf8 {
	my ( $window, $event ) = @_;
	_encode( $window, 'utf-8' );
	return;
}

sub encode_document_to {
	my ( $window, $event ) = @_;

	#	my @ENCODINGS = qw(
	#		cp932
	#		cp949
	#		euc-jp
	#		euc-kr
	#		shift-jis
	#		utf-8
	#	);
	require Encode;
	my @ENCODINGS = Encode->encodings(":all");

	my @layout = (
		[   [ 'Wx::StaticText', undef, Wx::gettext('Encode to:') ],
			[ 'Wx::ComboBox', '_encoding_', $ENCODINGS[0], \@ENCODINGS, Wx::wxCB_READONLY ],
		],
		[   [ 'Wx::Button', '_ok_',     Wx::wxID_OK ],
			[ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ],
		],
	);

	my $dialog = Padre::Wx::Dialog->new(
		parent => $window,
		title  => Wx::gettext("Encode document to..."),
		layout => \@layout,
		width  => [ 100, 200 ],
		bottom => 20,
	);
	$dialog->{_widgets_}{_ok_}->SetDefault;
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_ok_},     \&encode_ok_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{_cancel_}, \&encode_cancel_clicked );

	$dialog->{_widgets_}{_encoding_}->SetFocus;
	$dialog->Show(1);

	return 1;
}

sub encode_cancel_clicked {
	my ( $dialog, $event ) = @_;

	$dialog->Destroy;
}

sub encode_ok_clicked {
	my ( $dialog, $event ) = @_;

	my $window = $dialog->GetParent;
	my $data   = $dialog->get_data;
	$dialog->Destroy;

	_encode( $window, $data->{_encoding_} );
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

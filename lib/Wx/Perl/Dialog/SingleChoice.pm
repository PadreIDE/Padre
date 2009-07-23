package Wx::Perl::Dialog::SingleChoice;

use strict;
use warnings;

use Wx::Perl::Dialog;

our $VERSION = '0.41';

$| = 1;

=head1 NAME

Wx::Perl::Dialog::SingleChoice - a single choice dialog

=head1 SYNOPSIS

  use Wx::Perl::Dialog::SingleChoice;
  print Wx::Perl::Dialog::SingleChoice::dialog( title => 'Select one', values => ['a'..'d'] ), "\n";

=cut

sub dialog {
	my (%args) = @_;
	$args{title}  ||= '';
	$args{values} ||= [];

	return if not @{ $args{values} };

	my $box  = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $row1 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $row2 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$box->Add($row1);
	$box->Add($row2);

	my $dialog = Wx::Dialog->new(undef);
	$dialog->SetTitle( $args{title} );
	my $height = @{ $args{values} } * 25; # should be height of font
	my $width  = 25;                      # should be widest string?

	my $tb = Wx::Treebook->new( $dialog, -1, [ -1, -1 ], [ $width, $height ] );
	foreach my $name ( @{ $args{values} } ) {
		my $count = $tb->GetPageCount;
		my $page  = Wx::Panel->new($tb);
		$tb->AddPage( $page, $name, 0, $count );
	}
	$tb->SetFocus;

	my $ok = Wx::Button->new( $dialog, Wx::wxID_OK, '' );
	Wx::Event::EVT_BUTTON( $dialog, $ok, sub { $dialog->EndModal(Wx::wxID_OK) } );
	$ok->SetDefault;

	my $cancel = Wx::Button->new( $dialog, Wx::wxID_CANCEL, '', [ -1, -1 ], $ok->GetSize );
	Wx::Event::EVT_BUTTON( $dialog, $cancel, sub { $dialog->EndModal(Wx::wxID_CANCEL) } );

	$row1->Add($tb);
	$row2->Add($ok);
	$row2->Add($cancel);
	$dialog->SetSizer($box);
	my ( $bw, $bh ) = $ok->GetSizeWH;

	my $dialog_width = $width > 2 * $bw ? $width : 2 * $bw;
	$dialog->SetSize( -1, -1, $dialog_width, $height + $bh );

	my $ret = $dialog->ShowModal;
	if ( $ret eq Wx::wxID_CANCEL ) {
		$dialog->Destroy;
		return;
	}
	my $value = $args{values}[ $tb->GetSelection ];
	$dialog->Destroy;

	return $value;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

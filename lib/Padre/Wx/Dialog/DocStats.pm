package Padre::Wx::Dialog::DocStats;

use 5.008;
use strict;
use warnings;
use File::Basename;
use Padre::Wx                  ();
use Padre::Wx::Role::MainChild ();

our $VERSION = '0.58';
our @ISA     = qw{
	Padre::Wx::Role::MainChild
	Wx::Dialog
};

# TODO:
#  proper alignment (right) of numbers
#  proper margins
#  exit on escape

=pod

=head1 NAME

Padre::Wx::Dialog::DocStats - document statistics dialog

=cut

sub new {
	my ($class, $main) = @_;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Document Statistics'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION
		| Wx::wxCLOSE_BOX
		| Wx::wxSYSTEM_MENU
	);

	$self->{main} = $main;

	$self->{filename}   = $self->label( Wx::gettext('Filename') );
	$self->{selection}  = $self->label( Wx::gettext('Selection') );

	$self->{lines_1}    = $self->label('0');
	$self->{lines_2}    = $self->label('0');
	$self->{words_1}    = $self->label('0');
	$self->{words_2}    = $self->label('0');
	$self->{chars_1}    = $self->label('0');
	$self->{chars_2}    = $self->label('0');
	$self->{nwcs_1}     = $self->label('0');
	$self->{nwcs_2}     = $self->label('0');
	
	$self->{kbytes}     = $self->label('0');
	$self->{kibytes}    = $self->label('0');

	$self->{newline_type} = $self->label(' ');
	$self->{encoding}     = $self->label(' ');
	$self->{doc_type}     = $self->label(' ' x 15);

	my $close_button  = Wx::Button->new( $self, Wx::wxID_CLOSE, Wx::gettext('Close') );
	Wx::Event::EVT_BUTTON(
		$self,
		$close_button,
		sub {
			$_[0]->Close;
		}
	);	
	my $update_button = Wx::Button->new( $self, -1,	Wx::gettext('Update') );
	   $update_button->SetDefault;
	Wx::Event::EVT_BUTTON(
		$self,
		$update_button,
		sub {
			$_[0]->update_selection;
			$_[0]->update_document;
		}
	);	
	
	$self->{filename}->SetFont(Wx::Font->new(9,  # TODO: size should depend on theme
						 Wx::wxDEFAULT,
						 Wx::wxNORMAL,
						 Wx::wxBOLD,
						 0,
						 ''
						)
			           );

	$self->update_selection;
	$self->update_document;
	
	my $border_margin          = 5;
	my $vertical_grid_margin   = 4;
	my $horizontal_grid_margin = 10;
			           
	my $grid_sizer_data = Wx::FlexGridSizer->new(21, 3, $vertical_grid_margin, $horizontal_grid_margin);
	   $grid_sizer_data->AddGrowableCol(1);
	   $grid_sizer_data->AddGrowableCol(2);
	
	$grid_sizer_data->Add($self->label(' '), 0, Wx::wxEXPAND, 0);
	$grid_sizer_data->Add($self->label( Wx::gettext('Document') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{selection}, 0, 0, 0);
	
	$grid_sizer_data->Add($self->label( Wx::gettext('Lines') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{lines_1}, 0, Wx::wxALIGN_RIGHT, 0);
	$grid_sizer_data->Add($self->{lines_2}, 0, Wx::wxALIGN_RIGHT, 0);
	
	$grid_sizer_data->Add($self->label( Wx::gettext('Words') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{words_1}, 0, Wx::wxALIGN_RIGHT, 0);
	$grid_sizer_data->Add($self->{words_2}, 0, Wx::wxALIGN_RIGHT, 0);
	
	$grid_sizer_data->Add($self->label( Wx::gettext('Characters (including whitespace)') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{chars_1}, 0, Wx::wxALIGN_RIGHT, 0);
	$grid_sizer_data->Add($self->{chars_2}, 0, Wx::wxALIGN_RIGHT, 0);
	
	$grid_sizer_data->Add($self->label( Wx::gettext('Non-whitespace characters') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{nwcs_1}, 0, Wx::wxALIGN_RIGHT, 0);
	$grid_sizer_data->Add($self->{nwcs_2}, 0, Wx::wxALIGN_RIGHT, 0);
	
	$grid_sizer_data->Add($self->label( Wx::gettext('Kilobytes (kB)') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{kbytes},   0, Wx::wxALIGN_RIGHT, 0);
	$grid_sizer_data->Add($self->label(' '), 0, Wx::wxEXPAND, 0);

	$grid_sizer_data->Add($self->label( Wx::gettext('Kibibytes (kiB)') ), 0, 0, 0);
	$grid_sizer_data->Add($self->{kibytes},  0, Wx::wxALIGN_RIGHT, 0);
	$grid_sizer_data->Add($self->label(' '), 0, Wx::wxEXPAND, 0);
	
	my $grid_sizer_main = Wx::FlexGridSizer->new(5, 1, $vertical_grid_margin * 2, 0);
	   $grid_sizer_main->AddGrowableCol(0);
	
	   $grid_sizer_main->Add($self->{filename}, 0, 0, $border_margin);
	   $grid_sizer_main->Add($grid_sizer_data,  1, Wx::wxEXPAND, $border_margin);
	
	my $grid_sizer_type = Wx::FlexGridSizer->new(6, 2, $vertical_grid_margin, $horizontal_grid_margin);
  	   $grid_sizer_type->Add($self->label( Wx::gettext('Line break mode') ), 0, 0, 0);
	   $grid_sizer_type->Add($self->{newline_type}, 0, 0, 0);
	   $grid_sizer_type->Add($self->label( Wx::gettext('Encoding') ), 0, 0, 0);
	   $grid_sizer_type->Add($self->{encoding}, 0, 0, 0);
	   $grid_sizer_type->Add($self->label( Wx::gettext('Document type') ), 0, 0, 0);
	   $grid_sizer_type->Add($self->{doc_type}, 0, 0, 0);
	$grid_sizer_main->Add($grid_sizer_type, 1, Wx::wxEXPAND, 0);

	$grid_sizer_main->Add($self->horizontal_line, 1, Wx::wxEXPAND, 0);

	my $buttons = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	   $buttons->Add($close_button,  0, Wx::wxGROW | Wx::wxRIGHT,      $border_margin);
	   $buttons->Add($update_button, 0, Wx::wxGROW | Wx::wxLEFT,       $border_margin);
	$grid_sizer_main->Add($buttons,  0, Wx::wxALIGN_RIGHT | Wx::wxALL, $border_margin);
	
	$self->SetSizer($grid_sizer_main);
	$grid_sizer_main->Fit($self);

	return $self;
}

sub horizontal_line {
	my ($self) = @_;
	return Wx::StaticLine->new( $self, -1, Wx::wxDefaultPosition, Wx::wxDefaultSize );
}

sub label {
	my ($self, $caption) = @_;
	return Wx::StaticText->new( $self, -1, $caption, Wx::wxDefaultPosition, Wx::wxDefaultSize );
}

sub update_document {
	my ($self) = @_;

	my $doc = $self->{main}->current->document;
	if (!defined $doc) {
		warn "Document not defined.\n";
		return;
	}
	
	my $file_id = defined($doc->file) ? $doc->{file}->filename : $doc->get_title;
	return 0 if exists $self->{file_id} and $self->{file_id} eq $file_id;
	$self->{file_id} = $file_id;

	my ( $lines, $chars_with_space, $chars_without_space, $words,
	     $newline_type, $encoding ) = $doc->stats;

	my $file     = $doc->{file};
	my $disksize = defined $file ? $file->size : 0;
	my $doc_type = defined ref($doc) ? ref($doc) : Wx::gettext('none');

	$self->{filename}    ->SetLabel( $doc->get_title );
	$self->{lines_1}     ->SetLabel( $lines );
	$self->{words_1}     ->SetLabel( $words );
	$self->{chars_1}     ->SetLabel( $chars_with_space );
	$self->{nwcs_1}      ->SetLabel( $chars_without_space );
	$self->{kbytes}      ->SetLabel( int(($disksize / 1000) + 0.5) );
	$self->{kibytes}     ->SetLabel( int(($disksize / 1024) + 0.5) );
	$self->{newline_type}->SetLabel( $newline_type );
	$self->{encoding}    ->SetLabel( $encoding );
	$self->{doc_type}    ->SetLabel( $doc_type );
}

sub update_selection {
	my ($self) = @_;

	my $doc = $self->{main}->current->document;
	return if !defined $doc;
	
	my ($lines, $chars_with_space, $chars_without_space, $words) = $doc->selection_stats;

	$self->{lines_2}->SetLabel( $lines );
	$self->{words_2}->SetLabel( $words );
	$self->{chars_2}->SetLabel( $chars_with_space );
	$self->{nwcs_2} ->SetLabel( $chars_without_space );
	
	if ($chars_with_space > 0) {
		$self->ungrey_selection_data;
	}
	else {
		$self->grey_selection_data;
		$self->{lines_2}->SetLabel( 0 );
	}
}

sub ungrey_selection_data {
	my ($self) = @_;
	
	if (exists $self->{text_colour}) {
		$self->{lines_2}  ->SetForegroundColour( $self->{text_colour} );
		$self->{words_2}  ->SetForegroundColour( $self->{text_colour} );
		$self->{chars_2}  ->SetForegroundColour( $self->{text_colour} );
		$self->{nwcs_2}   ->SetForegroundColour( $self->{text_colour} );
		$self->{selection}->SetForegroundColour( $self->{text_colour} );
	}
}

sub grey_selection_data {
	my ($self) = @_;
	
	if (!exists $self->{text_colour}) {
		$self->{text_colour} = $self->{lines_2}->GetForegroundColour;
	}

	my $grey = Wx::Colour->new(128, 128, 128); # TODO: can we get this from a theme engine ...
	$self->{lines_2}  ->SetForegroundColour( $grey );
	$self->{words_2}  ->SetForegroundColour( $grey );
	$self->{chars_2}  ->SetForegroundColour( $grey );
	$self->{nwcs_2}   ->SetForegroundColour( $grey );
	$self->{selection}->SetForegroundColour( $grey );
}

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008, 2009, 2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008, 2009, 2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

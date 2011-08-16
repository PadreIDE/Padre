package Padre::Wx::CPAN;

use 5.008;
use strict;
use warnings;
use URI ();
use Scalar::Util qw( blessed );
use Params::Util qw( _INSTANCE );
use Padre::Wx                 ();
use Padre::Wx::CPAN::Listview ();

our $VERSION = '0.90';
our @ISA     = 'Wx::Frame';

use Class::XSAccessor {
	accessors => {
		listview => 'listview',
		entry    => 'entry',
		cpan     => 'cpan',
		main     => 'main',
	},
};

=pod

=head1 NAME

Padre::Wx::CPAN - Wx front-end for L<CPAN>


=head1 DESCRIPTION

User interface for L<CPAN>.

=head1 METHODS

=head2 new

Constructor, see L<Wx::Frame>

=head1 SEE ALSO

L<Padre::CPAN>

=cut

sub new {
	my ( $class, $cpan, $main ) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'CPAN',
		Wx::wxDefaultPosition,
		[ 750, 700 ],
	);
	$self->{cpan} = $cpan;
	$self->{main} = $main;

	my $top_s = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $but_s = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	my $entry = Wx::TextCtrl->new(
		$self, -1,
		'',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);
	$self->{entry} = $entry;
	Wx::Event::EVT_TEXT( $self, $entry, \&on_key_pressed );

	#	Wx::Event::EVT_TEXT_ENTER( $self, $entry,
	#		sub {
	#			$self->on_search_text_enter( $entry );
	#		}
	#	);
	#

	my $label = Wx::StaticText->new(
		$self,                 -1, 'Filter',
		Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxALIGN_RIGHT
	);
	$but_s->Add( $label, 2, Wx::wxALIGN_RIGHT | Wx::wxALIGN_CENTER_VERTICAL );
	$but_s->Add( $entry, 1, Wx::wxALIGN_RIGHT | Wx::wxALIGN_CENTER_VERTICAL );

	my $listview = Padre::Wx::CPAN::Listview->new($self);
	$self->{listview} = $listview;
	$top_s->Add( $but_s,    0, Wx::wxEXPAND );
	$top_s->Add( $listview, 1, Wx::wxGROW );

	$self->SetSizer($top_s);
	$self->SetAutoLayout(1);

	#$self->_setup_welcome;

	$self->listview->show_rows;

	return $self;
}

sub on_search_text_enter {
	my ( $self, $event ) = @_;
	my $text = $event->GetValue;
	print STDERR "$text\n";

	#$self->help($text);
}

sub show {
	shift->Show;
}

sub on_key_pressed {
	my ( $self, $text_ctrl, $event ) = @_;

	$self->listview->show_rows( $self->{entry}->GetValue );

	return;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

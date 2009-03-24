package Padre::Wx::CPAN;

use 5.008;
use strict;
use warnings;
use URI            ();
use Scalar::Util   ();
use Class::Autouse ();

use Padre::Wx ();

use base 'Wx::Frame';
use Scalar::Util qw( blessed );
use Params::Util qw( _INSTANCE );

use CPAN;

our $VERSION = '0.29';

use Class::XSAccessor 
	accessors => {
		listview => 'listview',
		entry    => 'entry',
	};


=pod

=head1 NAME

Padre::Wx::CPAN - Wx front-end for CPAN.pm


=head1 DESCRIPTION

User interface for CPAN.

=head1 METHODS

=head2 new

Constructor , see L<Wx::Frame>

=head1 SEE ALSO

L<CPAN>

=cut

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'CPAN',
		Wx::wxDefaultPosition,
		[750, 700],
	);

	my $top_s = Wx::BoxSizer->new( Wx::wxVERTICAL );
	my $but_s = Wx::BoxSizer->new( Wx::wxHORIZONTAL );

	my $entry = Wx::TextCtrl->new( 
		$self , -1 , 
		'' ,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);
	$self->{entry} = $entry;
	Wx::Event::EVT_TEXT( $self, $entry, \&on_key_pressed);

#	Wx::Event::EVT_TEXT_ENTER( $self, $entry, 
#		sub {
#			$self->on_search_text_enter( $entry );
#		}
#	);
#

	my $label = Wx::StaticText->new( $self, -1 , 'Search'  ,
		Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxALIGN_RIGHT
	);
 	$but_s->Add( $label, 2, Wx::wxALIGN_RIGHT |  Wx::wxALIGN_CENTER_VERTICAL   );
	$but_s->Add( $entry, 1, Wx::wxALIGN_RIGHT |  Wx::wxALIGN_CENTER_VERTICAL );

	use Padre::Wx::CPAN::Listview;
	my $listview = Padre::Wx::CPAN::Listview->new($self);
	$self->{listview} = $listview;
	$top_s->Add( $but_s,    0, Wx::wxEXPAND );
 	$top_s->Add( $listview, 1, Wx::wxGROW   );
 	
	$self->SetSizer( $top_s );
	$self->SetAutoLayout(1);
	#$self->_setup_welcome;
	
	CPAN::HandleConfig->load(
		be_silent => 1,
	);

	$self->show_rows;
	
	return $self;
}

sub on_search_text_enter {
	my ($self,$event) = @_;
	my $text = $event->GetValue;
	print  STDERR "$text\n";
	#$self->help($text);
}

sub show {
	shift->Show;
}


sub show_rows {
	my ($self, $regex) = @_;
	my $listview = $self->listview;
	$listview->clear;

	$regex ||= '^';
	my $MAX_DISPLAY = 10;
	my @modules = CPAN::Shell->expand('Module', "/$regex/");
	foreach my $i (0..$MAX_DISPLAY) {
		#my $name = $module->id;
		#print "$name\n";
		#last if $main::c++ > 10;
		#$name =~ s/::.*//;
		#$prefix{$name}++
		my $idx = $listview->InsertStringImageItem( 1, 1,  1 );
		$listview->SetItemData( $idx, 0 );
		$listview->SetItem( $idx, 1,  Wx::gettext('Warning')  );
		$listview->SetItem( $idx, 2, $modules[$i]->id );
	}
}

sub on_key_pressed {
	my ($self, $text_ctrl, $event) = @_;

	my $txt = $self->{entry}->GetValue;
	$txt = '' if not defined $txt; # just in case...

	#print STDERR "$txt\n";
	$txt =~ s/ //g;
	$self->show_rows($txt);	

	return;
}

1;
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


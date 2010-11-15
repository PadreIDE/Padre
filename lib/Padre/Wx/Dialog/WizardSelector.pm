package Padre::Wx::Dialog::WizardSelector;

use 5.008;
use strict;
use warnings;

use Padre::Wx             ();

our $VERSION = '0.75';
our @ISA     = qw{
	Wx::Dialog
};

# Creates the wizard dialog and returns the instance
sub new {
	my ( $class, $parent ) = @_;

	# Create the Wx wizard dialog
	my $self = $class->SUPER::new( $parent, -1, Wx::gettext('Wizard Selector (Experimental)') );

	# Minimum dialog size
	$self->SetMinSize( [ 360, 340 ] );

	# Create the controls and bind the events
	$self->_add_controls;
	$self->_add_events;

	return $self;
}

# Adds the dialog controls
sub _add_controls {
	my $self = shift;

	$self->{title} = Wx::StaticText->new($self, -1, 'Name');
	$self->{status} = Wx::StaticText->new($self, -1, 'Status');
	my $banner = Wx::StaticBitmap->new($self,-1,Padre::Wx::Icon::find("places/stock_folder"));

	my $title_font = $self->{title}->GetFont;
	$title_font->SetWeight(Wx::wxFONTWEIGHT_BOLD);
	$title_font->SetPointSize( $title_font->GetPointSize + 2 );
	$self->{title}->SetFont($title_font);

	my $header_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$header_sizer->Add( $self->{title}, 0, 0, 0 );
	$header_sizer->Add( $self->{status}, 0, 0, 0 );
	
	my $top_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$top_sizer->Add( $header_sizer, 1, Wx::wxALL | Wx::wxEXPAND, 0 );
	$top_sizer->Add( $banner, 0, Wx::wxALIGN_RIGHT, 0 );
	
	require Padre::Wx::Dialog::Wizard::SelectPage;
	$self->{select_page} = Padre::Wx::Dialog::Wizard::SelectPage->new($self);

	$self->{button_back} = Wx::Button->new($self, -1, Wx::gettext('&Back'));
	$self->{button_next} = Wx::Button->new($self, -1, Wx::gettext('&Next'));
	$self->{button_cancel} = Wx::Button->new($self, Wx::wxID_CANCEL, Wx::gettext('&Cancel'));

	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_back}, 0, 0, 0 );
	$button_sizer->Add( $self->{button_next}, 0, 0, 0 );
	$button_sizer->AddSpacer(10);
	$button_sizer->Add( $self->{button_cancel}, 0, 0, 0 );

	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer->Add( $top_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$sizer->Add( $self->{select_page}, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$sizer->AddSpacer(5);
	$sizer->Add( $button_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	
	$self->SetSizer($sizer);
	$self->Fit;

	return;
}

# Adds the dialog events
sub _add_events {
	my $self = shift;

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_back},
		sub {
			$_[0]->button_back;
		},
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_next},
		sub {
			$_[0]->button_next;
		},
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->button_cancel;
		},
	);

	return;
}

sub button_back {
	my $self = shift;
	
	# Workaround: BACK button does not receive focus automatically... (on win32)
	$self->{button_back}->SetFocus;
}

sub button_next {
	my $self = shift;

	# Workaround: NEXT button does not receive focus automatically... (on win32)
	$self->{button_next}->SetFocus;
}

sub button_cancel {
	$_[0]->Destroy;
}

# Shows the wizard dialog
sub show {
	my $self = shift;

	$self->{select_page}->show;

	$self->ShowModal;

	return;
}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::WizardSelector - a dialog to filter, select and open wizards

=head1 DESCRIPTION

This dialog lets the user search for a wizard and the open it if needed

=head1 PUBLIC API

=head2 C<new>

  my $wizard_selector = Padre::Wx::Dialog::WizardSelector->new($main);

Returns a new C<Padre::Wx::Dialog::WizardSelector> instance

=head2 C<show>

  $wizard_selector->show($main);

Shows the dialog. Returns C<undef>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

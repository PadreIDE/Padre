package Padre::Wx::Dialog::WizardSelector;

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Wx::Role::Main ();
use Padre::Logger;

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

# Generate faster accessors
use Class::XSAccessor {
	accessors => {
		current_page => 'current_page',
	},
};

=pod

=head1 NAME

Padre::Wx::Dialog::WizardSelector - a dialog to filter, select and open wizards

=head1 DESCRIPTION

This dialog lets the user search for a wizard and the open it if needed

=head1 PUBLIC API

=head2 METHODS

=head3 C<new>

  my $wizard_selector = Padre::Wx::Dialog::WizardSelector->new($main);

Returns a new C<Padre::Wx::Dialog::WizardSelector> instance

=cut

# Creates the wizard dialog and returns the instance
sub new {
	my $class  = shift;
	my $parent = shift;
	my $self   = $class->SUPER::new( $parent, -1, Wx::gettext('Wizard Selector') );

	# Dialog's icon as is the same as Padre
	$self->SetIcon(Padre::Wx::Icon::PADRE);

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

	$self->{title}  = Wx::StaticText->new( $self, -1, 'Name' );
	$self->{status} = Wx::StaticText->new( $self, -1, 'Status' );
	my $banner = Wx::StaticBitmap->new( $self, -1, Padre::Wx::Icon::find("places/stock_folder") );

	my $title_font = $self->{title}->GetFont;
	$title_font->SetWeight(Wx::wxFONTWEIGHT_BOLD);
	$title_font->SetPointSize( $title_font->GetPointSize + 2 );
	$self->{title}->SetFont($title_font);

	my $header_sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$header_sizer->Add( $self->{title},  0, 0, 0 );
	$header_sizer->Add( $self->{status}, 0, 0, 0 );

	my $top_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$top_sizer->Add( $header_sizer, 1, Wx::wxALL | Wx::wxEXPAND, 0 );
	$top_sizer->Add( $banner,       0, Wx::wxALIGN_RIGHT,        0 );

	require Padre::Wx::Dialog::Wizard::Select;
	$self->{select_page} = Padre::Wx::Dialog::Wizard::Select->new($self);

	$self->{button_back}   = Wx::Button->new( $self, -1,              Wx::gettext('&Back') );
	$self->{button_next}   = Wx::Button->new( $self, -1,              Wx::gettext('&Next') );
	$self->{button_cancel} = Wx::Button->new( $self, Wx::wxID_CANCEL, Wx::gettext('&Cancel') );

	my $button_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$button_sizer->Add( $self->{button_back}, 0, 0, 0 );
	$button_sizer->Add( $self->{button_next}, 0, 0, 0 );
	$button_sizer->AddSpacer(10);
	$button_sizer->Add( $self->{button_cancel}, 0, 0, 0 );

	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer->Add( $top_sizer,           0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$sizer->Add( $self->{select_page}, 1, Wx::wxALL | Wx::wxEXPAND, 2 );
	$sizer->AddSpacer(2);
	$sizer->Add( $button_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 2 );

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
			$_[0]->_on_button_back;
		},
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_next},
		sub {
			$_[0]->_on_button_next;
		},
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{button_cancel},
		sub {
			$_[0]->_on_button_cancel;
		},
	);

	return;
}

# Called when the back button is clicked
sub _on_button_back {
	my $self = shift;

	# Workaround: BACK button does not receive focus automatically... (on win32)
	$self->{button_back}->SetFocus;

	# Show the back wizard page if it is valid
	my $wizard = $self->{current_page}->back_wizard;
	if ($wizard) {
		$self->_try_to_show_page( $wizard->class );
	} else {
		$self->_show_page( $self->{select_page} );
	}
}

# Called when the next button is clicked
sub _on_button_next {
	my $self = shift;

	# Workaround: NEXT button does not receive focus automatically... (on win32)
	$self->{button_next}->SetFocus;

	# Show the next wizard page if it is valid
	my $wizard = $self->{current_page}->next_wizard or return;
	$self->_try_to_show_page( $wizard->class );
}

# Tries to show a wizard page
sub _try_to_show_page {
	my ( $self, $class ) = @_;

	eval "require $class";
	unless ($@) {
		if ( $class->can('new') ) {
			$self->_show_page( $class->new($self) );
		} else {
			$self->main->error( sprintf( Wx::gettext('%s has no constructor'), $class ) );
		}
	}
}

# Called when the cancel button is clicked
sub _on_button_cancel {
	$_[0]->Destroy;
}

# Shows a given page and make it is the currently displayed page
sub _show_page {
	my ( $self, $page ) = @_;

	# Hide the old one and then show the new one
	$self->current_page->Hide if $self->current_page;
	$self->current_page($page);
	$page->Show(1);

	$self->refresh;

	$page->show;
}

=pod

=head3 C<show>

  $wizard_selector->show($main);

Shows the wizard dialog. Returns C<undef>.

=cut

sub show {
	my $self = shift;

	$self->_show_page( $self->{select_page} );
	$self->ShowModal;

	return;
}

=pod

=head3 C<refresh>

	Refreshes the wizard selector dialog title's, status labels, and back/
	next button enabled status

=cut

sub refresh {
	my $self = shift;

	my $current_page = $self->current_page or return;
	$self->SetLabel( $current_page->title );
	$self->{title}->SetLabel( $current_page->name );
	$self->{status}->SetLabel( $current_page->status );
	$self->{button_back}->Enable( defined( $current_page->back_wizard ) ? 1 : 0 );
	$self->{button_next}->Enable( defined( $current_page->next_wizard ) ? 1 : 0 );
}

1;


__END__

=pod

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

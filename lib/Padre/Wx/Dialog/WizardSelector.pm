package Padre::Wx::Dialog::WizardSelector;

use 5.008;
use strict;
use warnings;
use Padre::Constant       ();
use Padre::Config         ();
use Padre::Wx             ();
use Padre::Wx::Role::Main ();
use Padre::Wx::TreeCtrl   ();

our $VERSION = '0.74';
our @ISA     = qw{
	Wx::Wizard
};

# Creates the wizard dialog and returns the instance
sub new {
	my ( $class, $parent ) = @_;

	# Create the Wx wizard dialog
	my $self = $class->SUPER::new( $parent, -1, Wx::gettext('Wizard Selector (WARNING: Experimental)') );

	# Minimum dialog size
	$self->SetMinSize( [ 360, 340 ] );

	# Create the controls
	$self->_create_controls;

	# Bind the control events
	$self->_bind_events;

	return $self;
}

# Create dialog controls
sub _create_controls {
	my $self = shift;

	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);

	# first page
	my $page1 = Wx::WizardPageSimple->new($self);
	$self->{page1} = $page1;

	# Filter label
	my $filter_label = Wx::StaticText->new( $page1, -1, Wx::gettext('&Filter:') );

	# Filter text field
	$self->{filter} = Wx::TextCtrl->new( $page1, -1, '' );

	# Filtered list
	$self->{tree} = Padre::Wx::TreeCtrl->new(
		$page1,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE |
			Wx::wxTR_FULL_ROW_HIGHLIGHT | Wx::wxTR_HAS_BUTTONS |
			Wx::wxTR_LINES_AT_ROOT | Wx::wxBORDER_NONE,
	);

	#
	#----- Dialog Layout -------
	#

	# Filter sizer
	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Main vertical sizer
	$sizer->Add( $filter_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$sizer->Add( $self->{tree}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );
	$sizer->AddSpacer(5);

	$page1->SetSizer($sizer);
	$page1->Fit;

	# Second dummy page
	my $page2 = Wx::WizardPageSimple->new($self);
	Wx::TextCtrl->new( $page2, -1, "Second page 2" );

	$self->{page1} = $page1;
	$self->{page2} = $page2;

	return;
}

# A Private method to binds events to controls
sub _bind_events {
	my $self = shift;

	# Set focus when Keypad Down or page down keys are pressed
	Wx::Event::EVT_CHAR(
		$self->{filter},
		sub {
			$self->_on_char( $_[1] );
		}
	);

	# Update filter search results on each text change
	Wx::Event::EVT_TEXT(
		$self,
		$self->{filter},
		sub {
			shift->_update_list;
		}
	);

	# Open a wizard when a wizard is selected
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self->{tree},
		sub {
			shift->_on_tree_item_activated(@_);
		}
	);

	return;
}

# Private method to handle on character pressed event
sub _on_char {
	my $self  = shift;
	my $event = shift;
	my $code  = $event->GetKeyCode;

	$self->{tree}->SetFocus
		if ( $code == Wx::WXK_DOWN )
		or ( $code == Wx::WXK_NUMPAD_PAGEDOWN )
		or ( $code == Wx::WXK_PAGEDOWN );

	$event->Skip(1);

	return;
}

# Private method to handle tree item activation (i.e. selection)
sub _on_tree_item_activated {
	my ( $self, $event ) = @_;

	print "_on_tree_item_activated\n";

	return;
}

# Private method to update the key bindings list view
sub _update_list {
	my $self   = shift;
	my $filter = quotemeta $self->{filter}->GetValue;

	# Clear list
	my $tree = $self->{tree};
	$tree->DeleteAllItems;

	#TODO no hard-coding
	my %wizard_data = (
		'Perl 5' => {
			'00Script' => sub { print 'Perl 5 Script'; },
			'01Test'   => sub { print 'Perl 5 Test'; },
			'02Module' => sub { print 'Perl 5 Module'; },
		},
		'Perl 6' => {
			'00Script'  => sub { print 'Perl 6 Script'; },
			'01Class'   => sub { print 'Perl 6 Class'; },
			'02Grammar' => sub { print 'Perl 6 Grammar'; },
			'03Package' => sub { print 'Perl 6 Package'; },
		},
	);

	# Add items to the wizard selection tree
	my $filter_not_empty = $filter ne '';
	my $root = $tree->AddRoot('Root');
	my $perl_5_category_item;
	for my $category ( sort keys %wizard_data ) {

		my $category_item;
		my $unmatched_category = $category !~ /$filter/i;
		for my $name ( sort keys %{ $wizard_data{$category} } ) {

			#Remove the first 2-digits sorting numbers from the name
			$name =~ s/^\d\d//;

			# Ignore adding the wizard if it has an unmatched category and
			# does not match the filter regex
			next if $unmatched_category and $name !~ /$filter/i;

			# Add a category if it doesnt exist and append the wizard to the end of it
			$category_item = $tree->AppendItem( $root, $category ) unless $category_item;
			$tree->AppendItem( $category_item, $name );
		}

		# Expand the defined category only if it the 'Perl 5' category
		# OR if it has children and the filter is not empty
		$tree->Expand($category_item)
			if defined($category_item)
				and ( $category eq 'Perl 5'
					or ( $filter_not_empty && $tree->ItemHasChildren($category_item) ) );
	}

	return;
}

# Shows the key binding dialog
sub show {
	my $self = shift;

	# Set focus on the filter text field
	$self->{filter}->SetFocus;

	# Update the preferences list
	$self->_update_list;

	Wx::WizardPageSimple::Chain( $self->{page1}, $self->{page2} );

	# Run the wizard selector now :)
	$self->RunWizard( $self->{page1} );

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

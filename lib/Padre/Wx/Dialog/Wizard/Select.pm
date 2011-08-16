package Padre::Wx::Dialog::Wizard::Select;

use 5.008;
use strict;
use warnings;
use Padre::Wx                     ();
use Padre::Wx::TreeCtrl           ();
use Padre::Wx::Dialog::WizardPage ();

our $VERSION = '0.90';
our @ISA     = qw(Padre::Wx::Dialog::WizardPage);

# Initialize the page
sub init {
	my $self = shift;

	$self->name( Wx::gettext("Select a Wizard") );
	$self->title( Wx::gettext("Wizard Selector") );
}

# Add controls to page
sub add_controls {
	my $self = shift;

	# Filter label
	my $filter_label = Wx::StaticText->new( $self, -1, Wx::gettext('&Filter:') );

	# Filter text field
	$self->{filter} = Wx::TextCtrl->new( $self, -1, '' );

	# Filtered list
	$self->{tree} = Padre::Wx::TreeCtrl->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_HIDE_ROOT | Wx::wxTR_SINGLE | Wx::wxTR_FULL_ROW_HIGHLIGHT | Wx::wxTR_HAS_BUTTONS
			| Wx::wxTR_LINES_AT_ROOT
	);

	# Filter sizer
	my $filter_sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$filter_sizer->Add( $filter_label,   0, Wx::wxALIGN_CENTER_VERTICAL, 5 );
	$filter_sizer->Add( $self->{filter}, 1, Wx::wxALIGN_CENTER_VERTICAL, 5 );

	# Main vertical sizer
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$sizer->Add( $filter_sizer, 0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$sizer->Add( $self->{tree}, 1, Wx::wxALL | Wx::wxEXPAND, 3 );

	$self->SetSizer($sizer);
	$self->Fit;
}

# Adds the events
sub add_events {
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
			shift->_update_tree;
		}
	);

	# Open a wizard when a wizard is activated (i.e. clicked)
	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self->{tree},
		sub {
			shift->_on_tree_item_activated(@_);
		}
	);

	# Update status text when a wizard is selected
	Wx::Event::EVT_TREE_SEL_CHANGED(
		$self,
		$self->{tree},
		sub {
			shift->_on_tree_selection_changed(@_);
		}
	);

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
}

# Private method to handle tree item activation (i.e. clicking)
sub _on_tree_item_activated {
	my ( $self, $event ) = @_;
}

# Private method to handle tree selection change
sub _on_tree_selection_changed {
	my ( $self, $event ) = @_;

	my $tree_item_id = $event->GetItem;
	my $wizard       = $self->{tree}->GetPlData($tree_item_id);
	if ($wizard) {
		my $class = $wizard->class;
		eval "require $class";
		if ($@) {
			$self->next_wizard(undef);
			$self->status( sprintf( Wx::gettext("Error while loading %s"), $class ) );
		} else {
			$self->next_wizard($wizard);
			$self->status( $wizard ? $wizard->comment : '' );
		}
	} else {
		$self->next_wizard(undef);
		$self->status('');
	}
	$self->refresh;
}

# Private method to update the tree by using the filter
sub _update_tree {
	my $self   = shift;
	my $filter = quotemeta $self->{filter}->GetValue;

	# Clear list
	my $tree = $self->{tree};
	$tree->DeleteAllItems;

	# Collect available wizard categories
	my $wizards_by_category = {};
	for my $wizard ( values %{ $self->ide->wizards } ) {
		my $category = $wizard->category;

		# Add the wizard the list of wizards in that category
		my $wizards = $wizards_by_category->{$category} || [];
		push @$wizards, $wizard;
		$wizards_by_category->{$category} = $wizards;
	}

	# Add items to the wizard selection tree
	my $filter_not_empty = $filter ne '';
	my $root = $tree->AddRoot('Root');
	my $perl_5_category_item;
	for my $category ( sort keys %$wizards_by_category ) {
		my $category_item;
		my $unmatched_category = $category !~ /$filter/i;
		for my $wizard ( @{ $wizards_by_category->{$category} } ) {
			my $label = $wizard->label;

			#Remove the first 2-digits sorting numbers from the name
			$label =~ s/^\d\d//;

			# Ignore adding the wizard if it has an unmatched category and
			# does not match the filter regex
			next if $unmatched_category and $label !~ /$filter/i;

			# Add a category if it doesnt exist and append the wizard to the end of it
			$category_item = $tree->AppendItem( $root, $category ) unless $category_item;
			my $item = $tree->AppendItem( $category_item, $label );
			$tree->SetPlData( $item, $wizard );
		}

		# Expand the defined category only if it the 'Perl 5' category
		# OR if it has children and the filter is not empty
		$tree->Expand($category_item)
			if defined($category_item)
				and ( $category eq 'Perl 5'
					or ( $filter_not_empty && $tree->ItemHasChildren($category_item) ) );
	}
}

# Shows the page
sub show {
	my $self = shift;

	# Set focus on the filter text field
	$self->{filter}->SetFocus;

	# Update the tree
	$self->_update_tree;
}

1;


__END__

=pod

=head1 NAME

Padre::Wx::Dialog::Wizard::Select - the wizard selection page

=head1 DESCRIPTION

This prepares the required page UI that the wizard will include in its UI and 
has the page flow information for the next and previous pages.

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

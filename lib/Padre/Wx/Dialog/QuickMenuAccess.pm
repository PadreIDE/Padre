package Padre::Wx::Dialog::QuickMenuAccess;

use warnings;
use strict;

# package exports and version
our $VERSION   = '0.42';
our @ISA       = 'Wx::Dialog';

# module imports
use Padre::DB ();
use Padre::Wx ();
use Padre::Wx::Icon ();

# accessors
use Class::XSAccessor accessors => {
	_main         => '_main',         # Padre main window
	_sizer        => '_sizer',        # window sizer
	_search_text  => '_search_text',  # search text control
	_matches_list => '_matches_list', # matches list
	_status_text  => '_status_text',  # status label
};

# -- constructor
sub new {
	my ( $class, $main ) = @_;

	# create object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Quick Menu Access'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE | Wx::wxTAB_TRAVERSAL,
	);

	$self->_main($main);

	# Dialog's icon as is the same as Padre
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# create dialog
	$self->_create;

	return $self;
}


# -- event handler

#
# handler called when the ok button has been clicked.
#
sub _on_ok_button_clicked {
	my ($self) = @_;

	my $main = $self->_main;

	# Open the selected menu item if the user pressed OK
	my $selection   = $self->_matches_list->GetSelection;
	my $menu_action = $self->_matches_list->GetClientData($selection);
	$self->Destroy;
	if ($menu_action) {
		my $event = $menu_action->menu_event;
		if ( $event && ref($event) eq 'CODE' ) {

			eval {

				# # Keep the last 20 recently opened resources available
				# # and save it to plugin's configuration object
				# my $config = $self->_plugin->config_read;
				# my @recent = split /\|/, $config->{quick_menu_history};
				# if ( scalar @recent >= 20 ) {
					# shift @recent;
				# }
				# push @recent, $menu_action->name;
				# my %unique = map { $_, 1 } @recent;
				# @recent = keys %unique;
				# @recent = sort { $a cmp $b } @recent;
				# $config->{quick_menu_history} = join '|', @recent;
				# $self->_plugin->config_write($config);

				&$event($main);
			};
			if ($@) {
				Wx::MessageBox(
					Wx::gettext('Error while trying to perform Padre action'),
					Wx::gettext('Error'),
					Wx::wxOK,
					$main,
				);
			}
		}
	}
}


# -- private methods

#
# create the dialog itself.
#
sub _create {
	my ($self) = @_;

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::wxVERTICAL);
	$self->_sizer($sizer);

	# create the controls
	$self->_create_controls;
	$self->_create_buttons;

	# wrap everything in a vbox to add some padding
	$self->SetSizerAndFit($sizer);
	$sizer->SetSizeHints($self);

	# center the dialog
	$self->Centre;
}

#
# create the buttons pane.
#
sub _create_buttons {
	my ($self) = @_;
	my $sizer = $self->_sizer;

	my $butsizer = $self->CreateStdDialogButtonSizer( Wx::wxOK | Wx::wxCANCEL );
	$sizer->Add( $butsizer, 0, Wx::wxALL | Wx::wxEXPAND | Wx::wxALIGN_CENTER, 5 );
	Wx::Event::EVT_BUTTON( $self, Wx::wxID_OK, \&_on_ok_button_clicked );
}

#
# create controls in the dialog
#
sub _create_controls {
	my ($self) = @_;

	# search textbox
	my $search_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('&Type a menu item name to access:')
	);
	$self->_search_text( Wx::TextCtrl->new( $self, -1, '' ) );

	# matches result list
	my $matches_label = Wx::StaticText->new(
		$self, -1,
		Wx::gettext('&Matching Menu Items:')
	);
	$self->_matches_list(
		Wx::ListBox->new(
			$self, -1, [ -1, -1 ], [ 400, 300 ], [],
			Wx::wxLB_SINGLE
		)
	);

	# Shows how many items are selected and information about what is selected
	$self->_status_text( Wx::StaticText->new( $self, -1, '' ) );

	$self->_sizer->AddSpacer(10);
	$self->_sizer->Add( $search_label,        0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_search_text,  0, Wx::wxALL | Wx::wxEXPAND, 5 );
	$self->_sizer->Add( $matches_label,       0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_matches_list, 0, Wx::wxALL | Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_status_text,  0, Wx::wxALL | Wx::wxEXPAND, 10 );

	$self->_setup_events;

	return;
}

#
# Adds various events
#
sub _setup_events {
	my $self = shift;

	Wx::Event::EVT_CHAR(
		$self->_search_text,
		sub {
			my $this  = shift;
			my $event = shift;
			my $code  = $event->GetKeyCode;

			if ( $code == Wx::WXK_DOWN ) {
				$self->_matches_list->SetFocus;
			}

			$event->Skip(1);
		}
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->_search_text,
		sub {

			$self->_update_matches_list_box;

			return;
		}
	);

	Wx::Event::EVT_LISTBOX(
		$self,
		$self->_matches_list,
		sub {

			my $selection = $self->_matches_list->GetSelection;
			if ( $selection != Wx::wxNOT_FOUND ) {
				$self->_status_text->SetLabel( $self->_matches_list->GetString($selection) );
			}

			return;
		}
	);

	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->_matches_list,
		sub {
			$self->_on_ok_button_clicked();
			$self->EndModal(0);
		}
	);

	Wx::Event::EVT_IDLE(
		$self,
		sub {

			# update matches list
			$self->_update_matches_list_box;

			# focus on the search text box
			$self->_search_text->SetFocus;

			# unregister from idle event
			Wx::Event::EVT_IDLE( $self, undef );
		}
	);

}

#
# Update matches list box from matched files list
#
sub _update_matches_list_box {
	my $self = shift;

	my $search_expr = $self->_search_text->GetValue;

	#quote the search string to make it safer
	$search_expr = quotemeta $search_expr;

	#Populate the list box now
	$self->_matches_list->Clear;
	my $pos = 0;

	my @menu_actions = ();
	foreach my $menu_action ( values %{ Padre::ide->actions } ) {
		push @menu_actions, $menu_action;
	}
	@menu_actions = sort { $a->label_text cmp $b->label_text } @menu_actions;
	foreach my $menu_action (@menu_actions) {
		my $label = $menu_action->label_text;
		if ( $label =~ /$search_expr/i ) {
			$self->_matches_list->Insert( $label, $pos, $menu_action );
			$pos++;
		}
	}
	if ( $pos > 0 ) {
		$self->_matches_list->Select(0);
		$self->_status_text->SetLabel( "" . ( $pos + 1 ) . Wx::gettext(' item(s) found') );
	} else {
		$self->_status_text->SetLabel( Wx::gettext('No items found') );
	}

	return;
}


1;

__END__

=head1 NAME

Padre::Wx::Dialog::QuickMenuAccess - Ecliptic's Quick Menu Access dialog

=head1 DESCRIPTION

=head2 Quick Menu Access (Shortcut: Ctrl + 3)

This opens a dialog where you can search for menu labels. When you hit the OK 
button, the menu item will be selected.

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
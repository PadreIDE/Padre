package Padre::Wx::Dialog::QuickMenuAccess;

use 5.008;
use strict;
use warnings;
use Padre::Util           ();
use Padre::DB             ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Wx::HtmlWindow ();
use Padre::Wx::Role::Main ();
use Padre::Logger;

# package exports and version
our $VERSION = '0.94';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

# accessors
use Class::XSAccessor {
	accessors => {
		_sizer           => '_sizer',           # window sizer
		_search_text     => '_search_text',     # search text control
		_list            => '_list',            # matching items list
		_status_text     => '_status_text',     # status label
		_matched_results => '_matched_results', # matched results
	}
};

# -- constructor
sub new {
	my $class = shift;
	my $main  = shift;

	# Create object
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Quick Menu Access'),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_FRAME_STYLE | Wx::TAB_TRAVERSAL,
	);

	# Dialog's icon as is the same as Padre
	$self->SetIcon(Padre::Wx::Icon::PADRE);

	# Create dialog
	$self->_create;

	return $self;
}


# -- event handler

#
# handler called when the ok button has been clicked.
#
sub _on_ok_button_clicked {
	my $self = shift;
	my $main = $self->main;

	# Open the selected menu item if the user pressed OK
	my $selection = $self->_list->GetSelection;
	return if $selection == Wx::NOT_FOUND;
	my $action    = $self->_list->GetClientData($selection);
	$self->Hide;
	my %actions     = %{ Padre::ide->actions };
	my $menu_action = $actions{ $action->{name} };
	if ($menu_action) {
		my $event = $menu_action->menu_event;
		if ( $event && ref($event) eq 'CODE' ) {

			# Fetch the recently used actions from the database
			require Padre::DB::RecentlyUsed;
			my $recently_used = Padre::DB::RecentlyUsed->select( 'where type = ?', 'ACTION' ) || [];
			my $found = 0;
			foreach my $e (@$recently_used) {
				if ( $action->{name} eq $e->name ) {
					$found = 1;
				}
			}

			eval { &$event($main); };
			if ($@) {
				$main->error(sprintf( Wx::gettext('Error while trying to perform Padre action: %s'), $@ ));
				TRACE("Error while trying to perform Padre action: $@") if DEBUG;
			} else {

				# And insert a recently used tuple if it is not found
				# and the action is successful.
				if ( not $found ) {
					Padre::DB::RecentlyUsed->create(
						name      => $action->{name},
						value     => $action->{name},
						type      => 'ACTION',
						last_used => time(),
					);
				} else {
					Padre::DB->do(
						"update recently_used set last_used = ? where name = ? and type = ?",
						{}, time(), $action->{name}, 'ACTION',
					);
				}
			}
		}
	}
}


# -- private methods

#
# create the dialog itself.
#
sub _create {
	my $self = shift;

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$self->_sizer($sizer);

	# create the controls
	$self->_create_controls;
	$self->_create_buttons;

	# wrap everything in a vbox to add some padding
	$self->SetMinSize( [ 360, 340 ] );
	$self->SetSizer($sizer);

	# center/fit the dialog
	$self->Fit;
	$self->CentreOnParent;
}

#
# create the buttons pane.
#
sub _create_buttons {
	my $self  = shift;
	my $sizer = $self->_sizer;

	$self->{ok_button} = Wx::Button->new(
		$self, Wx::ID_OK, Wx::gettext('&OK'),
	);
	$self->{ok_button}->SetDefault;
	$self->{cancel_button} = Wx::Button->new(
		$self, Wx::ID_CANCEL, Wx::gettext('&Cancel'),
	);

	my $buttons = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$buttons->AddStretchSpacer;
	$buttons->Add( $self->{ok_button},     0, Wx::ALL | Wx::EXPAND, 5 );
	$buttons->Add( $self->{cancel_button}, 0, Wx::ALL | Wx::EXPAND, 5 );
	$sizer->Add( $buttons, 0, Wx::ALL | Wx::EXPAND | Wx::ALIGN_CENTER, 5 );

	Wx::Event::EVT_BUTTON( $self, Wx::ID_OK, \&_on_ok_button_clicked );
}

#
# create controls in the dialog
#
sub _create_controls {
	my $self = shift;

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
	$self->_list(
		Wx::ListBox->new(
			$self, -1, Wx::DefaultPosition, Wx::DefaultSize, [],
			Wx::LB_SINGLE
		)
	);

	# Shows how many items are selected and information about what is selected
	$self->_status_text(
		Padre::Wx::HtmlWindow->new(
			$self,
			-1,
			Wx::DefaultPosition,
			[ -1, 70 ],
			Wx::BORDER_STATIC
		)
	);

	$self->_sizer->AddSpacer(10);
	$self->_sizer->Add( $search_label,       0, Wx::ALL | Wx::EXPAND, 2 );
	$self->_sizer->Add( $self->_search_text, 0, Wx::ALL | Wx::EXPAND, 2 );
	$self->_sizer->Add( $matches_label,      0, Wx::ALL | Wx::EXPAND, 2 );
	$self->_sizer->Add( $self->_list,        1, Wx::ALL | Wx::EXPAND, 2 );
	$self->_sizer->Add( $self->_status_text, 0, Wx::ALL | Wx::EXPAND, 2 );

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

			$self->_list->SetFocus
				if ( $code == Wx::K_DOWN )
				or ( $code == Wx::K_UP )
				or ( $code == Wx::K_NUMPAD_PAGEDOWN )
				or ( $code == Wx::K_PAGEDOWN );

			$event->Skip(1);
		}
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->_search_text,
		sub {

			if ( not $self->_matched_results ) {
				$self->_search;
			}
			$self->_update_list_box;

			return;
		}
	);

	Wx::Event::EVT_LISTBOX(
		$self,
		$self->_list,
		sub {
			my $selection = $self->_list->GetSelection;
			if ( $selection != Wx::NOT_FOUND ) {
				my $action = $self->_list->GetClientData($selection);
				$self->_status_text->SetPage( $self->_label( $action->{value}, $action->{name} ) );
			}
		}
	);

	Wx::Event::EVT_LISTBOX_DCLICK(
		$self,
		$self->_list,
		sub {
			$self->_on_ok_button_clicked;
			$self->EndModal(0);
		}
	);

	Wx::Event::EVT_IDLE(
		$self,
		sub {

			# update matches list
			$self->_update_list_box;

			# focus on the search text box
			$self->_search_text->SetFocus;

			# unregister from idle event
			Wx::Event::EVT_IDLE( $self, undef );
		}
	);

	$self->_show_recent_while_idle;

}

#
# Shows recently opened stuff while idle
#
sub _show_recent_while_idle {
	my $self = shift;

	Wx::Event::EVT_IDLE(
		$self,
		sub {
			$self->_show_recently_opened_actions;

			# focus on the search text box
			$self->_search_text->SetFocus;

			# unregister from idle event
			Wx::Event::EVT_IDLE( $self, undef );
		}
	);
}

#
# Shows the recently opened menu actions
#
sub _show_recently_opened_actions {
	my $self = shift;

	# Fetch them from Padre's RecentlyUsed database table
	require Padre::DB::RecentlyUsed;
	my $recently_used  = Padre::DB::RecentlyUsed->select( "where type = ? order by last_used desc", 'ACTION' ) || [];
	my @recent_actions = ();
	my %actions        = %{ Padre::ide->actions };
	foreach my $e (@$recently_used) {
		my $action_name = $e->name;
		my $action      = $actions{$action_name};
		if ($action) {
			push @recent_actions,
				{
				name  => $action_name,
				value => $action->label_text,
				};
		} else {
			TRACE("action '$action_name' is not defined anymore!") if DEBUG;
		}
	}
	$self->_matched_results( \@recent_actions );

	# Show results in matching items list
	$self->_update_list_box;

	# No need to store them anymore
	$self->_matched_results(undef);
}

#
# Search for files and cache result
#
sub _search {
	my $self = shift;

	$self->_status_text->SetPage( Wx::gettext('Reading items. Please wait...') );
	my @menu_actions = ();
	my %actions      = %{ Padre::ide->actions };
	foreach my $action_name ( keys %actions ) {
		my $action = $actions{$action_name};
		push @menu_actions,
			{
			name  => $action_name,
			value => $action->label_text,
			};
	}
	@menu_actions = sort { $a->{value} cmp $b->{value} } @menu_actions;
	$self->_matched_results( \@menu_actions );

	return;
}

#
# Update matching items list box from matched files list
#
sub _update_list_box {
	my $self = shift;

	return if not $self->_matched_results;

	my $search_expr = $self->_search_text->GetValue;

	#quote the search string to make it safer
	$search_expr = quotemeta $search_expr;

	#Populate the list box now
	$self->_list->Clear;
	my $pos = 0;

	#TODO: think how to make actions and menus relate to each other
	my %menu_name_by_prefix = (
		file     => Wx::gettext('File'),
		edit     => Wx::gettext('Edit'),
		search   => Wx::gettext('Search'),
		view     => Wx::gettext('View'),
		perl     => Wx::gettext('Perl'),
		refactor => Wx::gettext('Refactor'),
		run      => Wx::gettext('Run'),
		debug    => Wx::gettext('Debug'),
		plugins  => Wx::gettext('Plugins'),
		window   => Wx::gettext('Window'),
		help     => Wx::gettext('Help'),
	);

	my $first_label = undef;
	foreach my $action ( @{ $self->_matched_results } ) {
		my $label = $action->{value};
		if ( $label =~ /$search_expr/i ) {
			my $action_name = $action->{name};
			if ( not $first_label ) {
				$first_label = $self->_label( $label, $action_name );
			}
			my $label_suffix = '';
			my $prefix       = $action_name;
			$prefix =~ s/^(\w+)\.\w+/$1/s;
			my $menu_name = $menu_name_by_prefix{$prefix};
			$label_suffix = "  ($menu_name)" if $menu_name;
			$self->_list->Insert( $label . $label_suffix, $pos, $action );
			$pos++;
		}
	}
	if ( $pos > 0 ) {
		$self->_list->Select(0);
		$self->_status_text->SetPage($first_label);
		$self->_list->Enable(1);
		$self->_status_text->Enable(1);
		$self->{ok_button}->Enable(1);
	} else {
		$self->_status_text->SetPage('');
		$self->_list->Enable(0);
		$self->_status_text->Enable(0);
		$self->{ok_button}->Enable(0);
	}

	return;
}

#
# Returns a formatted html string of the action label, name and comment
#
sub _label {
	my ( $self, $action_label, $action_name ) = @_;

	my %actions     = %{ Padre::ide->actions };
	my $menu_action = $actions{$action_name};
	my $comment     = ( $menu_action and defined $menu_action->comment ) ? $menu_action->comment : '';

	return '<b>' . $action_label . '</b> <i>' . $action_name . '</i><br>' . $comment;
}


1;

__END__

=head1 NAME

Padre::Wx::Dialog::QuickMenuAccess - Quick Menu Access dialog

=head1 DESCRIPTION

=head2 Quick Menu Access (Shortcut: C<Ctrl+3>)

This opens a dialog where you can search for menu labels. When you hit the OK
button, the menu item will be selected.

=head1 AUTHOR

Ahmad M. Zawawi C<< <ahmad.zawawi at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

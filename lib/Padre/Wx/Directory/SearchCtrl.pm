package Padre::Wx::Directory::SearchCtrl;

use 5.008;
use strict;
use warnings;
use Padre::Current        ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();

our $VERSION = '0.64';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::SearchCtrl
};





######################################################################
# Constructor

sub new {
	my $class = shift;
	my $panel = shift;
	my $self  = $class->SUPER::new(
		$panel, -1, '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);

	# Text that is showed when the search field is empty
	$self->SetDescriptiveText( Wx::gettext('Search') );

	# Create the search box menu
	my $menu = Wx::Menu->new;
	Wx::Event::EVT_MENU(
		$self,
		$menu->Append( -1, Wx::gettext('Move to other panel') ),
		sub {
			shift->GetParent->move;
		}
	);
	$self->SetMenu( $menu );

	# Setups events related with the search field
	Wx::Event::EVT_TEXT(
		$self,
		$self,
		sub {
			shift->on_text(@_);
		},
	);

	Wx::Event::EVT_SEARCHCTRL_CANCEL_BTN(
		$self,
		$self,
		sub {
			$self->SetValue('');
		}
	);

	Wx::Event::EVT_SET_FOCUS(
		$self,
		sub {
			shift->GetParent->refresh;
		},
	);

	return $self;
}





######################################################################
# Event Handlers

# If it is a project, caches search field content while it is typed and
# searchs for files that matchs the type word.
sub on_text {
	my $self = shift;

	# Show or hide the cancel button
	$self->ShowCancelButton( $self->IsEmpty ? 0 : 1 );

	# The changed search state requires a rerender
	$self->GetParent->render;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

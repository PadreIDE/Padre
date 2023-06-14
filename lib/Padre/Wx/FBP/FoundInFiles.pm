package Padre::Wx::FBP::FoundInFiles;

## no critic

# This module was generated by Padre::Plugin::FormBuilder::Perl.
# To change this module edit the original .fbp file and regenerate.
# DO NOT MODIFY THIS FILE BY HAND!

use 5.008005;
use utf8;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Role::Main ();
use Padre::Wx::TreeCtrl ();
use File::ShareDir ();

our $VERSION = '1.02';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Panel
};

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::DefaultPosition,
		[ 500, 300 ],
		Wx::TAB_TRAVERSAL,
	);

	$self->{status} = Wx::StaticText->new(
		$self,
		-1,
		'',
	);

	$self->{repeat} = Wx::BitmapButton->new(
		$self,
		-1,
		Wx::Bitmap->new( File::ShareDir::dist_file( "Padre", "icons/gnome218/16x16/actions/view-refresh.png" ), Wx::BITMAP_TYPE_ANY ),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::BU_AUTODRAW,
	);
	$self->{repeat}->SetToolTip(
		Wx::gettext("Refresh Search")
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{repeat},
		sub {
			shift->repeat_clicked(@_);
		},
	);

	$self->{expand_all} = Wx::BitmapButton->new(
		$self,
		-1,
		Wx::Bitmap->new( File::ShareDir::dist_file( "Padre", "icons/gnome218/16x16/actions/zoom-in.png" ), Wx::BITMAP_TYPE_ANY ),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::BU_AUTODRAW,
	);
	$self->{expand_all}->SetToolTip(
		Wx::gettext("Expand All")
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{expand_all},
		sub {
			shift->expand_all_clicked(@_);
		},
	);

	$self->{collapse_all} = Wx::BitmapButton->new(
		$self,
		-1,
		Wx::Bitmap->new( File::ShareDir::dist_file( "Padre", "icons/gnome218/16x16/actions/zoom-out.png" ), Wx::BITMAP_TYPE_ANY ),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::BU_AUTODRAW,
	);
	$self->{collapse_all}->SetToolTip(
		Wx::gettext("Collapse All")
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{collapse_all},
		sub {
			shift->collapse_all_clicked(@_);
		},
	);

	$self->{stop} = Wx::BitmapButton->new(
		$self,
		-1,
		Wx::Bitmap->new( File::ShareDir::dist_file( "Padre", "icons/gnome218/16x16/actions/stop.png" ), Wx::BITMAP_TYPE_ANY ),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::BU_AUTODRAW,
	);
	$self->{stop}->SetToolTip(
		Wx::gettext("Stop Search")
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{stop},
		sub {
			shift->stop_clicked(@_);
		},
	);

	$self->{tree} = Padre::Wx::TreeCtrl->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TR_FULL_ROW_HIGHLIGHT | Wx::TR_HAS_BUTTONS | Wx::TR_HIDE_ROOT | Wx::TR_SINGLE | Wx::NO_BORDER,
	);

	my $top_sizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$top_sizer->Add( $self->{status}, 0, Wx::ALIGN_BOTTOM | Wx::ALL, 2 );
	$top_sizer->Add( 0, 0, 1, Wx::EXPAND, 5 );
	$top_sizer->Add( $self->{repeat}, 0, Wx::ALIGN_BOTTOM | Wx::BOTTOM | Wx::LEFT | Wx::TOP, 2 );
	$top_sizer->Add( $self->{expand_all}, 0, Wx::ALIGN_BOTTOM | Wx::BOTTOM | Wx::LEFT | Wx::TOP, 2 );
	$top_sizer->Add( $self->{collapse_all}, 0, Wx::ALIGN_BOTTOM | Wx::BOTTOM | Wx::LEFT | Wx::TOP, 2 );
	$top_sizer->Add( $self->{stop}, 0, Wx::ALIGN_BOTTOM | Wx::ALL, 2 );

	my $main_sizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$main_sizer->Add( $top_sizer, 0, Wx::ALIGN_RIGHT | Wx::ALL | Wx::EXPAND, 0 );
	$main_sizer->Add( $self->{tree}, 1, Wx::EXPAND, 0 );

	$self->SetSizer($main_sizer);
	$self->Layout;

	return $self;
}

sub repeat_clicked {
	$_[0]->main->error('Handler method repeat_clicked for event repeat.OnButtonClick not implemented');
}

sub expand_all_clicked {
	$_[0]->main->error('Handler method expand_all_clicked for event expand_all.OnButtonClick not implemented');
}

sub collapse_all_clicked {
	$_[0]->main->error('Handler method collapse_all_clicked for event collapse_all.OnButtonClick not implemented');
}

sub stop_clicked {
	$_[0]->main->error('Handler method stop_clicked for event stop.OnButtonClick not implemented');
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


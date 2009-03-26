package Padre::Wx::Dialog::PluginManager3;

# Third-generation plugin manager

use strict;
use warnings;

use Carp                    qw{ croak };

use URI::file               ();
use Params::Util            qw{_INSTANCE};
use Padre::Util             ();
use Padre::Wx               ();
use Padre::Wx::Dialog::HTML ();

our $VERSION = '0.29';
use base 'Wx::Frame';

sub new {
	my ($class, $parent, $manager) = @_;

	croak "Missing or invalid Padre::PluginManager object"
		unless $manager->isa('Padre::PluginManager');

	# create object
	my $self = $class->SUPER::new(
		$parent,
		-1,
	Wx::gettext('Plugin Manager'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE,
	);

	# create list
	my $list = Wx::ListView->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxLC_REPORT| Wx::wxLC_SINGLE_SEL
	);
	$list->InsertColumn( 0, Wx::gettext('Icon') );
	$list->InsertColumn( 1, Wx::gettext('Name') );
	$list->InsertColumn( 2, Wx::gettext('Version') );
	$list->InsertColumn( 3, Wx::gettext('Status') );
	$self->{list} = $list;

	$self->{manager} = $manager;

	return $self;
}


sub show {
	my $self = shift;
	$self->refresh;
	$self->Show;
}

sub refresh {
	my $self = shift;

	my $list    = $self->{list};
	my $manager = $self->{manager};
	my $plugins = $manager->plugins;
	
	$list->DeleteAllItems;
	foreach my $name ( reverse $manager->plugin_names ) {
		my $plugin  = $plugins->{$name};
		my $version = $plugin->version || '???';

		my $status = Wx::gettext('disabled');
		$status    = Wx::gettext('enabled')      if $plugin->enabled;
		$status    = Wx::gettext('incompatible') if $plugin->incompatible;
		$status    = Wx::gettext('crashed')      if $plugin->error;

		my $idx = $list->InsertStringImageItem( 0, '', 0 );
		$list->SetItem($idx, 1, $name);
		$list->SetItem($idx, 2, $version);
		$list->SetItem($idx, 3, $status);
		$list->SetItemData( $idx, 1 );
	}

	# auto-resize columns
	$list->SetColumnWidth($_, Wx::wxLIST_AUTOSIZE) for 0..3;
}


1;
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

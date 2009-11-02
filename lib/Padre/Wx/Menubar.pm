package Padre::Wx::Menubar;

use 5.008;
use strict;
use warnings;
use Params::Util qw{_INSTANCE};
use Padre::Current qw{_CURRENT};
use Padre::Util             ();
use Padre::Wx               ();
use Padre::Wx::Menu::File   ();
use Padre::Wx::Menu::Edit   ();
use Padre::Wx::Menu::Search ();
use Padre::Wx::Menu::View   ();
use Padre::Wx::Menu::Perl   ();
use Padre::Wx::Menu::Refactor();
use Padre::Wx::Menu::Run     ();
use Padre::Wx::Menu::Plugins ();
use Padre::Wx::Menu::Window  ();
use Padre::Wx::Menu::Help    ();

our $VERSION = '0.49';

#####################################################################
# Construction, Setup, and Accessors

use Class::XSAccessor getters => {
	wx   => 'wx',
	main => 'main',

	# Don't add accessors to here until they have been
	# upgraded to be fully encapsulated classes.
	file     => 'file',
	edit     => 'edit',
	search   => 'search',
	view     => 'view',
	perl     => 'perl',
	refactor => 'refactor',
	run      => 'run',
	plugins  => 'plugins',
	window   => 'window',
	help     => 'help',
};

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the basic object
	my $self = bless {

		# Link back to the main window
		main => $main,

		# The number of menus in the default set.
		# That is, EXCLUDING the special Perl menu.
		default => 8,
	}, $class;

	# Generate the individual menus
	$self->{main}     = $main;
	$self->{file}     = Padre::Wx::Menu::File->new($main);
	$self->{edit}     = Padre::Wx::Menu::Edit->new($main);
	$self->{search}   = Padre::Wx::Menu::Search->new($main);
	$self->{view}     = Padre::Wx::Menu::View->new($main);
	$self->{perl}     = Padre::Wx::Menu::Perl->new($main);
	$self->{refactor} = Padre::Wx::Menu::Refactor->new($main);
	$self->{run}      = Padre::Wx::Menu::Run->new($main);
	$self->{plugins}  = Padre::Wx::Menu::Plugins->new($main);
	$self->{window}   = Padre::Wx::Menu::Window->new($main);
	$self->{help}     = Padre::Wx::Menu::Help->new($main);

	# Generate the final menubar
	$self->{wx} = Wx::MenuBar->new;
	$self->wx->Append( $self->file->wx,    Wx::gettext("&File") );
	$self->wx->Append( $self->edit->wx,    Wx::gettext("&Edit") );
	$self->wx->Append( $self->search->wx,  Wx::gettext("&Search") );
	$self->wx->Append( $self->view->wx,    Wx::gettext("&View") );
	$self->wx->Append( $self->run->wx,     Wx::gettext("&Run") );
	$self->wx->Append( $self->plugins->wx, Wx::gettext("Pl&ugins") );
	$self->wx->Append( $self->window->wx,  Wx::gettext("&Window") );
	$self->wx->Append( $self->help->wx,    Wx::gettext("&Help") );

	my $config = $self->main->ide->config;

	Wx::Event::EVT_MENU_OPEN(
		$main,
		sub {
			$self->refresh;
		}
	);

	return $self;
}

#####################################################################
# Reflowing the Menu

sub refresh {
	my $self    = shift;
	my $plugins = shift;
	my $current = _CURRENT(@_);
	my $menu    = $self->wx->GetMenuCount ne $self->{default};
	my $perl    = !!(
		   _INSTANCE( $current->document, 'Padre::Document::Perl' )
		or _INSTANCE( $current->project, 'Padre::Project::Perl' )
	);

	# Add/Remove the Perl menu
	if ( $perl and not $menu ) {
		$self->wx->Insert( 4, $self->perl->wx,     Wx::gettext("&Perl") );
		$self->wx->Insert( 5, $self->refactor->wx, Wx::gettext("Ref&actor") );
	} elsif ( $menu and not $perl ) {
		$self->wx->Remove(5); # refactor
		$self->wx->Remove(4); # perl
	}

	# Refresh individual menus
	$self->file->refresh($current);
	$self->edit->refresh($current);
	$self->search->refresh($current);
	$self->view->refresh($current);
	$self->run->refresh($current);

	# Don't do to the effort of refreshing the Perl menu
	# unless we're actually showing it.
	if ($perl) {
		$self->perl->refresh($current);
		$self->refactor->refresh($current);
	}

	# plugin menu requires special flag as it was leaking memory
	# TODO eliminate the memory leak
	if ($plugins) {
		$self->plugins->refresh($current);
	}
	$self->window->refresh($current);
	$self->help->refresh($current);

	return 1;
}

sub refresh_top {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $menu    = $self->wx->GetMenuCount ne $self->{default};
	my $perl    = !!(
		   _INSTANCE( $current->document, 'Padre::Document::Perl' )
		or _INSTANCE( $current->project, 'Padre::Project::Perl' )
	);

	# Add/Remove the Perl menu
	if ( $perl and not $menu ) {
		$self->wx->Insert( 4, $self->perl->wx,     Wx::gettext("&Perl") );
		$self->wx->Insert( 5, $self->refactor->wx, Wx::gettext("Ref&actor") );
	} elsif ( $menu and not $perl ) {
		$self->wx->Remove(5); # refactor
		$self->wx->Remove(4); # perl
	}

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

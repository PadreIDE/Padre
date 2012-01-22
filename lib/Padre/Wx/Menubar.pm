package Padre::Wx::Menubar;

use 5.008;
use strict;
use warnings;
use Params::Util              ();
use Padre::Current            ();
use Padre::Feature            ();
use Padre::Util               ();
use Padre::Wx                 ();
use Padre::Wx::Menu::File     ();
use Padre::Wx::Menu::Edit     ();
use Padre::Wx::Menu::Search   ();
use Padre::Wx::Menu::View     ();
use Padre::Wx::Menu::Perl     ();
use Padre::Wx::Menu::Refactor ();
use Padre::Wx::Menu::Run      ();
use Padre::Wx::Menu::Tools    ();
use Padre::Wx::Menu::Window   ();
use Padre::Wx::Menu::Help     ();


our $VERSION = '0.94';





#####################################################################
# Construction, Setup, and Accessors

use Class::XSAccessor {
	getters => {
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
		debug    => 'debug',
		plugins  => 'plugins',
		window   => 'window',
		help     => 'help',
	}
};

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the basic object
	my $self = bless {
		main => $main,
		wx   => Wx::MenuBar->new,
	}, $class;

	# Create all child menus
	$self->{file}     = Padre::Wx::Menu::File->new($main);
	$self->{edit}     = Padre::Wx::Menu::Edit->new($main);
	$self->{search}   = Padre::Wx::Menu::Search->new($main);
	$self->{view}     = Padre::Wx::Menu::View->new($main);
	$self->{refactor} = Padre::Wx::Menu::Refactor->new($main);
	$self->{perl}     = Padre::Wx::Menu::Perl->new($main);
	$self->{run}      = Padre::Wx::Menu::Run->new($main);
	if (Padre::Feature::DEBUGGER) {
		require Padre::Wx::Menu::Debug;
		$self->{debug} = Padre::Wx::Menu::Debug->new($main);
	}
	$self->{plugins} = Padre::Wx::Menu::Tools->new($main);
	$self->{window}  = Padre::Wx::Menu::Window->new($main);
	$self->{help}    = Padre::Wx::Menu::Help->new($main);

	# Add the mimetype agnostic menus to the menu bar
	$self->append( $self->{file} );
	$self->append( $self->{edit} );
	$self->append( $self->{search} );
	$self->append( $self->{view} );
	$self->append( $self->{run} );
	$self->append( $self->{plugins} );
	$self->append( $self->{window} );
	$self->append( $self->{help} );

	# Save the default number of menus
	$self->{default} = $self->wx->GetMenuCount;

	return $self;
}

sub append {
	$_[0]->wx->Append( $_[1]->wx, $_[1]->title );
}

sub insert {
	$_[0]->wx->Insert( $_[1], $_[2]->wx, $_[2]->title );
}

sub remove {
	$_[0]->wx->Remove( $_[1] );
}





#####################################################################
# Reflowing the Menu

sub refresh {
	my $self    = shift;
	my $plugins = shift;
	my $current = Padre::Current::_CURRENT(@_);
	my $menu    = $self->wx->GetMenuCount ne $self->{default};
	my $perl    = !!(
		   Params::Util::_INSTANCE( $current->document, 'Padre::Document::Perl' )
		or Params::Util::_INSTANCE( $current->project, 'Padre::Project::Perl' )
	);

	# Add/Remove the Perl menu
	if ( $perl and not $menu ) {
		$self->insert( 4, $self->perl );
		$self->insert( 5, $self->refactor );
		if (Padre::Feature::DEBUGGER) {
			$self->insert( 7, $self->debug );
		}
	} elsif ( $menu and not $perl ) {
		if (Padre::Feature::DEBUGGER) {
			$self->remove(7); # debug
		}
		$self->remove(5);     # refactor
		$self->remove(4);     # perl
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
		if (Padre::Feature::DEBUGGER) {
			$self->debug->refresh($current);
		}
	}

	$self->plugins->refresh($current);
	$self->window->refresh($current);
	$self->help->refresh($current);

	return 1;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

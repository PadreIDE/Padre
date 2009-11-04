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

		items => [],

		hotkeys => {},

	}, $class;

	# Generate the individual menus
	$self->{main} = $main;

	#	$self->{file}     = Padre::Wx::Menu::File->new($main);
	#	$self->{edit}     = Padre::Wx::Menu::Edit->new($main);
	#	$self->{search}   = Padre::Wx::Menu::Search->new($main);
	#	$self->{view}     = Padre::Wx::Menu::View->new($main);
	#	$self->{perl}     = Padre::Wx::Menu::Perl->new($main);
	#	$self->{refactor} = Padre::Wx::Menu::Refactor->new($main);
	#	$self->{run}      = Padre::Wx::Menu::Run->new($main);
	#	$self->{plugins}  = Padre::Wx::Menu::Plugins->new($main);
	#	$self->{window}   = Padre::Wx::Menu::Window->new($main);
	#	$self->{help}     = Padre::Wx::Menu::Help->new($main);
	#
	#	# Generate the final menubar
	$self->{wx} = Wx::MenuBar->new;

	#	$self->wx->Append( $self->file->wx,    Wx::gettext("&File") );
	#	$self->wx->Append( $self->edit->wx,    Wx::gettext("&Edit") );
	#	$self->wx->Append( $self->search->wx,  Wx::gettext("&Search") );
	#	$self->wx->Append( $self->view->wx,    Wx::gettext("&View") );
	#	$self->wx->Append( $self->run->wx,     Wx::gettext("&Run") );
	#	$self->wx->Append( $self->plugins->wx, Wx::gettext("Pl&ugins") );
	#	$self->wx->Append( $self->window->wx,  Wx::gettext("&Window") );
	#	$self->wx->Append( $self->help->wx,    Wx::gettext("&Help") );

	my $config = $self->main->ide->config;

	Wx::Event::EVT_MENU_OPEN(
		$main,
		sub {
			$self->refresh;
		}
	);

	$self->refresh;

	return $self;
}

#####################################################################
# Reflowing the Menu

sub refresh {
	my $self    = shift;
	my $plugins = shift;

	my $main   = $self->main;
	my $config = $main->ide->config;

	# This is a version between fully configurable menus and the old fixed ones, it
	# isn't made to stay forever, but it's working for now

	my @items;

	for my $item ( split( /\;/, $config->main_menubar_items ) ) {
		if ( $item eq 'menu._document' ) {
			next unless defined( $main->current );
			next unless defined( $main->current->document );
			next unless $main->current->document->can('menu');
			next unless defined( $main->current->document->menu );
			$item = $main->current->document->menu;
		}

		if ( ref($item) eq 'ARRAY' ) {
			push @items, @{$item};
		} else {
			push @items, $item;
		}
	}

	my $count = -1;

	for my $item (@items) {

		if ( $item =~ /^menu\.(.+)$/ ) {
			my $menu = $1;

			next if $menu eq '';

			my $obj = lc($menu);

			# Menu number starting at 0
			++$count;

			# a fast skip if there is nothing to do
			# Note: $count (and Wx indices) start at 0, but the Count is a count
			next
				if $count < $self->wx->GetMenuCount
					and defined( $self->{items}->[$count] )
					and defined( $self->{$obj} )
					and ( $self->{items}->[$count] eq $self->{$obj} );

			# It seems that every submenu-object could be attached only once
			# even if it's removed lateron, so we need to create a new object

			# Everything custom/configurable/usable_by_plugins should be
			# crash-safe
			eval {
				my $module = 'Padre::Wx::Menu::' . $menu;
				eval 'use ' . $module . ';';
				die $@ if $@;
				$self->{$obj} = $module->new($main);
			};
			if ($@) {
				warn 'Error loading menu ' . $menu . ': ' . $@;
				next;
			}

			# Check for hotkey collisions
			my $title = $self->{$obj}->title;
			my $hotkey;
			if ($title =~ /\&(.)/) {
				my $char = $1;
				$hotkey = $char if ( ! defined( $self->{hotkeys}->{$char} ))
					or ( $self->{hotkeys}->{$char} eq ref( $self->{$obj} ) );
			}
			if (! defined($hotkey)) {
				# Dynamically set the hotkeys for menu items
				# only if there is no defined hotkey or there
				# is a collision
				$title =~ s/\&//g;
				for my $pos ( 0 .. ( length($title) - 1 ) ) {
					my $char = lc(substr( $title, $pos, 1 ));

					# Only use a-z for hotkeys
					next if $char !~ /\w/;

					# Skip if hotkey is already in use
					next
						if defined( $self->{hotkeys}->{$char} )
							and ( $self->{hotkeys}->{$char} ne ref( $self->{$obj} ) );
					$title =~ s/^(.{$pos})(.*)$/$1\&$2/;
					$hotkey = $char;
					last;
				}
			}
			if (defined($hotkey)) {
					$self->{hotkeys}->{$hotkey} = ref( $self->{$obj} );
			} else {
				warn 'No hotkey defined or assignable for '.$obj;
			}

			# Replace should be faster than remove/append
			if ( $count <= ( $self->wx->GetMenuCount - 1 ) ) {
				if ( defined( $self->{items}->[$count] ) and ( $self->{items}->[$count] ne $self->{$obj} ) ) {
					$self->wx->Replace( $count, $self->{$obj}->wx, $title );
				}
			} else {
				$self->wx->Append( $self->{$obj}->wx, $title );
			}
			$self->{items}->[$count] = $self->{$obj};
		}

	}

	# Remove items if there are more than we replaced
	if ( $count < ( $self->wx->GetMenuCount - 1 ) ) {
		for my $item_no ( ( $count + 1 ) .. $self->wx->GetMenuCount ) {
			pop @{ $self->{items} };
			$self->wx->Remove($item_no);
		}
	}

	#	my $current = _CURRENT(@_);
	#	my $menu    = $self->wx->GetMenuCount ne $self->{default};
	#	my $perl    = !!(
	#		   _INSTANCE( $current->document, 'Padre::Document::Perl' )
	#		or _INSTANCE( $current->project, 'Padre::Project::Perl' )
	#	);
	#
	#	# Add/Remove the Perl menu
	#	if ( $perl and not $menu ) {
	#		$self->wx->Insert( 4, $self->perl->wx,     Wx::gettext("&Perl") );
	#		$self->wx->Insert( 5, $self->refactor->wx, Wx::gettext("Ref&actor") );
	#	} elsif ( $menu and not $perl ) {
	#		$self->wx->Remove(5); # refactor
	#		$self->wx->Remove(4); # perl
	#	}
	#
	#	# Refresh individual menus
	#	$self->file->refresh($current);
	#	$self->edit->refresh($current);
	#	$self->search->refresh($current);
	#	$self->view->refresh($current);
	#	$self->run->refresh($current);
	#
	#	# Don't do to the effort of refreshing the Perl menu
	#	# unless we're actually showing it.
	#	if ($perl) {
	#		$self->perl->refresh($current);
	#		$self->refactor->refresh($current);
	#	}
	#
	#	# plugin menu requires special flag as it was leaking memory
	#	# TODO eliminate the memory leak
	#	if ($plugins) {
	#		$self->plugins->refresh($current);
	#	}
	#	$self->window->refresh($current);
	#	$self->help->refresh($current);
	#
	return 1;
}

sub refresh_top {
	my $self    = shift;
	my $current = _CURRENT(@_);
	my $menu    = $self->wx->GetMenuCount ne $self->{default};

	return 1; # This needs to be changed to match ->refresh, otherwise it breaks the menu

	my $perl = !!(
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

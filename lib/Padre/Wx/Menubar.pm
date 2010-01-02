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
use Padre::Wx::Menu::Debug   ();
use Padre::Wx::Menu::Plugins ();
use Padre::Wx::Menu::Window  ();
use Padre::Wx::Menu::Help    ();

our $VERSION = '0.53';

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

	#
	#	# Generate the final menubar
	$self->{wx} = Wx::MenuBar->new;

	my $config = $self->main->ide->config;

	# This event seems to be outdated and slow down Padre.
	# If there are any menu (refresh) problems, re-enable it and open a ticket for
	# deeper checking.
	#	Wx::Event::EVT_MENU_OPEN(
	#		$main,
	#		sub {
	#			print "Menubar\n";
	#			$self->refresh;
	#		}
	#	);

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

	my $current = _CURRENT(@_);

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
			if ( defined( $main->current->document->{menu} ) ) {
				$item = [$item] unless ref($item) eq 'ARRAY';
				if ( ref( $main->current->document->{menu} ) ne 'ARRAY' ) {
					push @{$item}, $main->current->document->{menu};
				} else {
					push @{$item}, @{ $main->current->document->{menu} };
				}
			}
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
			if (    $count < $self->wx->GetMenuCount
				and defined( $self->{items}->[$count] )
				and defined( $self->{$obj} )
				and ( $self->{items}->[$count] eq $self->{$obj} ) )
			{
				$self->{$obj}->refresh($current);
				next;
			}

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
			if ( $title =~ /\&(.)/ ) {
				my $char = lc($1);
				$hotkey = $char
					if ( !defined( $self->{hotkeys}->{$char} ) )
					or ( $self->{hotkeys}->{$char} eq ref( $self->{$obj} ) );
			}
			if ( !defined($hotkey) ) {

				# Dynamically set the hotkeys for menu items
				# only if there is no defined hotkey or there
				# is a collision
				$title =~ s/\&//g;
				for my $pos ( 0 .. ( length($title) - 1 ) ) {
					my $char = lc( substr( $title, $pos, 1 ) );

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
			if ( defined($hotkey) ) {
				$self->{hotkeys}->{ lc($hotkey) } = ref( $self->{$obj} );
			} else {
				warn 'No hotkey defined or assignable for ' . $obj;
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

			# Refresh the menu only if all requirements exist already
			if ( defined( $current->main ) and defined( $current->config ) ) {
				$self->{$obj}->refresh($current);
			}
		}

	}

	# Remove items if there are more than we replaced
	if ( $count < ( $self->wx->GetMenuCount - 1 ) ) {
		while ( $count < ( $self->wx->GetMenuCount - 1 ) ) {
			pop @{ $self->{items} };
			$self->wx->Remove( $self->wx->GetMenuCount - 1 );
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
	#	# TO DO eliminate the memory leak
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

	# Commented out temporarily to appease xt/critic.t
	#	my $perl = !!(
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
	#	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

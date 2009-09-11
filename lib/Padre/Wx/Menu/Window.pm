package Padre::Wx::Menu::Window;

# Fully encapsulated Window menu

use 5.008;
use strict;
use warnings;
use Padre::Wx       ();
use Padre::Wx::Menu ();
use Padre::Current qw{_CURRENT};

our $VERSION = '0.46';
our @ISA     = 'Padre::Wx::Menu';

#####################################################################
# Padre::Wx::Menu Methods

sub new {
	my $class = shift;
	my $main  = shift;

	# Create the empty menu as normal
	my $self = $class->SUPER::new(@_);

	# Add additional properties
	$self->{main} = $main;
	$self->{alt}  = [];

	# Split Window
	$self->{window_split_window} = $self->add_menu_item(
		$self,
		name       => 'window.split_window',
		label      => Wx::gettext('&Split window'),
		menu_event => sub {
			Padre::Wx::Main::on_split_window(@_);
		},
	);

	$self->AppendSeparator;

	# File Navigation
	$self->{window_next_file} = $self->add_menu_item(
		$self,
		name       => 'window.next_file',
		label      => Wx::gettext('Next File'),
		shortcut   => 'Ctrl-TAB',
		menu_event => sub {
			Padre::Wx::Main::on_next_pane(@_);
		},
	);

	$self->{window_previous_file} = $self->add_menu_item(
		$self,
		name       => 'window.previous_file',
		label      => Wx::gettext('Previous File'),
		shortcut   => 'Ctrl-Shift-TAB',
		menu_event => sub {
			Padre::Wx::Main::on_prev_pane(@_);
		},
	);

	$self->{window_last_visited_file} = $self->add_menu_item(
		$self,
		name       => 'window.last_visited_file',
		label      => Wx::gettext('Last Visited File'),
		shortcut   => 'Ctrl-Shift-P',
		menu_event => sub {
			Padre::Wx::Main::on_last_visited_pane(@_);
		},
	);

	$self->{window_right_click} = $self->add_menu_item(
		$self,
		name       => 'window.right_click',
		label      => Wx::gettext('Right Click'),
		shortcut   => 'Alt-/',
		menu_event => sub {
			my $editor = $_[0]->current->editor;
			if ($editor) {
				$editor->on_right_down( $_[1] );
			}
		},
	);

	$self->AppendSeparator;

	# Window Navigation
	$self->{window_goto_subs_window} = $self->add_menu_item(
		$self,
		name       => 'window.goto_subs_window',
		label      => Wx::gettext('GoTo Subs Window'),
		menu_event => sub {
			$_[0]->refresh_functions( $_[0]->current );
			$_[0]->show_functions(1);
			$_[0]->functions->SetFocus;
		},
	);

	$self->{window_goto_outline_window} = $self->add_menu_item(
		$self,
		name       => 'window.goto_outline_window',
		label      => Wx::gettext('GoTo Outline Window'),
		shortcut   => 'Alt-L',
		menu_event => sub {
			$_[0]->show_outline(1);
			$_[0]->outline->SetFocus;
		},
	);

	$self->{window_goto_outline_window} = $self->add_menu_item(
		$self,
		name       => 'window.goto_output_window',
		label      => Wx::gettext('GoTo Output Window'),
		shortcut   => 'Alt-O',
		menu_event => sub {
			$_[0]->show_output(1);
			$_[0]->output->SetFocus;
		},
	);

	$self->{window_goto_syntax_check_window} = $self->add_menu_item(
		$self,
		name       => 'window.goto_syntax_check_window',
		label      => Wx::gettext('GoTo Syntax Check Window'),
		shortcut   => 'Alt-C',
		menu_event => sub {
			$_[0]->show_syntax(1);
			$_[0]->syntax->SetFocus;
		},
	);

	$self->{window_goto_main_window} = $self->add_menu_item(
		$self,
		name       => 'window.goto_main_window',
		label      => Wx::gettext('GoTo Main Window'),
		shortcut   => 'Alt-M',
		menu_event => sub {
			my $editor = $_[0]->current->editor or return;
			$editor->SetFocus;
		},
	);

	# We'll need to know the number of menu items there are
	# by default so we can add and remove window menu items later.
	$self->{default} = $self->GetMenuItemCount;

	return $self;
}

sub refresh {
	my $self     = shift;
	my $current  = _CURRENT(@_);
	my $alt      = $self->{alt};
	my $default  = $self->{default};
	my $items    = $self->GetMenuItemCount;
	my $notebook = $current->notebook;
	my $pages    = $notebook->GetPageCount;

	# Add or remove menu entries as needed
	if ($pages) {
		if ( $items == $default ) {
			$self->{separator} = $self->AppendSeparator;
			$items++;
		}
		my $need = $pages - $items + $default + 1;
		my $main = $self->{main};
		if ( $need > 0 ) {
			foreach my $i ( 1 .. $need ) {

				# The temporary label 'tmp' is necessary (i.e. must be ne '')
				# in order not to get a wx assertion failure in debug mode
				my $menu_entry = $self->Append( -1, 'tmp' );
				push @$alt, $menu_entry;
				Wx::Event::EVT_MENU(
					$main, $menu_entry,
					sub { $main->on_nth_pane( $pages - $need + $i - 1 ) }
				);
			}
		} elsif ( $need < 0 ) {
			foreach ( 1 .. -$need ) {
				$self->Destroy( pop @$alt );
			}
		}
	} else {
		if ( $items > $default ) {
			$self->Destroy( pop @$alt ) while @$alt;
			$self->Destroy( delete $self->{separator} );
		}
	}
	$self->{window_split_window}->Enable($pages);
	$self->{window_next_file}->Enable($pages);
	$self->{window_previous_file}->Enable($pages);
	$self->{window_last_visited_file}->Enable($pages);
	$self->{window_right_click}->Enable($pages);

	# Update the labels to match the notebooks
	my $config_shorten_path = 1; # TODO should be configurable ?
	my $prefix_length       = 0;
	if ($config_shorten_path) {
		$prefix_length = length get_common_prefix( $#$alt, $notebook );
	}
	foreach my $i ( 0 .. $#$alt ) {
		my $doc = $notebook->GetPage($i)->{Document} or return;
		my $label = $doc->filename || $notebook->GetPageText($i);
		$label =~ s/^\s+//;
		if ( $prefix_length < length $label ) {
			$label = substr( $label, $prefix_length );
		}
		$alt->[$i]->SetText($label);
	}

	return 1;
}

sub get_common_prefix {
	my ( $count, $notebook ) = @_;
	my @prefix = ();
	foreach my $i ( 0 .. $count ) {
		my $doc = $notebook->GetPage($i)->{Document} or return;
		my $label = $doc->filename || $notebook->GetPageText($i);
		my @label = File::Spec->splitdir($label);

		if ( not @prefix ) {
			@prefix = @label;
			next;
		}

		my $i = 0;
		while ( $i < @prefix ) {
			last if $prefix[$i] ne $label[$i];
			$i++;
		}
		splice @prefix, $i;
	}
	return File::Spec->catdir(@prefix);
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

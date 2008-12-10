package Padre::Wx::Menu;

use 5.008;
use strict;
use warnings;
use Params::Util             qw{_INSTANCE};
use Padre::Util              ();
use Padre::Wx                ();
use Padre::Wx::Menu::File    ();
use Padre::Wx::Menu::Edit    ();
use Padre::Wx::Menu::View    ();
use Padre::Wx::Menu::Perl    ();
use Padre::Wx::Menu::Run     ();
use Padre::Wx::Menu::Plugins ();
use Padre::Wx::Menu::Help    ();
use Padre::Documents         ();

our $VERSION = '0.20';





#####################################################################
# Construction, Setup, and Accessors

use Class::XSAccessor
	getters => {
		win          => 'win',
		wx           => 'wx',

		# Don't add accessors to here until they have been
		# upgraded to be fully encapsulated classes.
		file         => 'file',
		edit         => 'edit',
		view         => 'view',
		perl         => 'perl',
		run          => 'run',
		plugins      => 'plugins',
		help         => 'help',
		experimental => 'experimental',
	};

sub new {
	my $class  = shift;
	my $main   = shift;
	my $self   = bless {}, $class;

	# Generate the individual menus
	$self->{win}     = $main;
	$self->{file}    = Padre::Wx::Menu::File->new($main);
	$self->{edit}    = Padre::Wx::Menu::Edit->new($main);
	$self->{view}    = Padre::Wx::Menu::View->new($main);
	$self->{perl}    = Padre::Wx::Menu::Perl->new($main);
	$self->{run}     = Padre::Wx::Menu::Run->new($main);
	$self->{plugins} = Padre::Wx::Menu::Plugins->new($main);
	$self->{window}  = $self->menu_window( $main );
	$self->{help}    = Padre::Wx::Menu::Help->new($main);

	# Generate the final menubar
	$self->{wx} = Wx::MenuBar->new;
	$self->wx->Append( $self->file->wx,    Wx::gettext("&File")    );
	$self->wx->Append( $self->edit->wx,    Wx::gettext("&Edit")    );
	$self->wx->Append( $self->view->wx,    Wx::gettext("&View")    );
	$self->wx->Append( $self->run->wx,     Wx::gettext("&Run")     );
	$self->wx->Append( $self->plugins->wx, Wx::gettext("Pl&ugins") );
	$self->wx->Append( $self->{window},    Wx::gettext("&Window")  );
	$self->wx->Append( $self->help->wx,    Wx::gettext("&Help")    );

	my $config = Padre->ide->config;
	if ( $config->{experimental} ) {
		# Create the Experimental menu
		# All the crap that doesn't work, have a home,
		# or should never be seen be real users goes here.
		require Padre::Wx::Menu::Experimental;
		$self->{experimental} = Padre::Wx::Menu::Experimental->new($main);
		$self->wx->Append( $self->experimental->wx, Wx::gettext("E&xperimental") );
	}

	return $self;
}

sub add_alt_n_menu {
	my ($self, $file, $n) = @_;
	#return if $n > 9;

	$self->{alt}->[$n] = $self->{window}->Append(-1, "");
	Wx::Event::EVT_MENU( $self->win, $self->{alt}->[$n], sub { $_[0]->on_nth_pane($n) } );
	$self->update_alt_n_menu($file, $n);

	return;
}

sub update_alt_n_menu {
	my ($self, $file, $n) = @_;
	my $v = $n + 1;

	# TODO: fix the occassional crash here:
	if (not defined $self->{alt}->[$n]) {
		warn "alt-n $n problem ?";
		return;
	}

	#$self->{alt}->[$n]->SetText("$file\tAlt-$v");
	$self->{alt}->[$n]->SetText($file);

	return;
}

sub remove_alt_n_menu {
	my $self = shift;
	$self->{window}->Remove( pop @{ $self->{alt} } );
	return;
}





#####################################################################
# Reflowing the Menu

sub refresh {
	my $self     = shift;
	my $menu     = $self->wx->GetMenuLabel(3) eq '&Perl';
	my $document = !! _INSTANCE(
		Padre::Documents->current,
		'Padre::Document::Perl'
	);

	# Add/Remove the Perl menu
	if ( $document and not $menu ) {
		$self->wx->Insert( 3, $self->perl->wx, '&Perl' );
	} elsif ( $menu and not $document ) {
		$self->wx->Remove( 3 );
	}

	# Refresh individual menus
	$self->file->refresh;
	$self->edit->refresh;
	$self->view->refresh;
	$self->run->refresh;
	$self->perl->refresh;
	$self->plugins->refresh;
	$self->help->refresh;

	if ( $self->experimental ) {
		$self->experimental->refresh;
	}

	return 1;
}

sub menu_window {
	my ( $self, $main ) = @_;
	
	# Create the window menu
	my $menu = Wx::Menu->new;
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("&Split window") ),
		\&Padre::Wx::MainWindow::on_split_window,
	);
	$menu->AppendSeparator;
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Next File\tCtrl-TAB")),
		\&Padre::Wx::MainWindow::on_next_pane,
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Previous File\tCtrl-Shift-TAB")),
		\&Padre::Wx::MainWindow::on_prev_pane,
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Last Visited File\tCtrl-6")),
		\&Padre::Wx::MainWindow::on_last_visited_pane,
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append(-1, Wx::gettext("Right Click\tAlt-/")),
		sub {
			my $editor = $_[0]->selected_editor;
			if ($editor) {
				$editor->on_right_down($_[1]);
			}
		},
	);
	$menu->AppendSeparator;


	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("GoTo Subs Window\tAlt-S") ),
		sub {
			$_[0]->{subs_panel_was_closed} = ! Padre->ide->config->{main_subs_panel};
			$_[0]->show_functions(1); 
			$_[0]->{gui}->{subs_panel}->SetFocus;
		},
	); 
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("GoTo Output Window\tAlt-O") ),
		sub {
			$_[0]->show_output(1);
			$_[0]->{gui}->{output_panel}->SetFocus;
		},
	);
	$self->{window_goto_syntax_check} = $menu->Append( -1, Wx::gettext("GoTo Syntax Check Window\tAlt-C") );
	Wx::Event::EVT_MENU( $main,
		$self->{window_goto_syntax_check},
		sub {
			$_[0]->show_syntaxbar(1);
			$_[0]->{gui}->{syntaxcheck_panel}->SetFocus;
		},
	);
	Wx::Event::EVT_MENU( $main,
		$menu->Append( -1, Wx::gettext("GoTo Main Window\tAlt-M") ),
		sub {
			$_[0]->selected_editor->SetFocus;
		},
	); 
	$menu->AppendSeparator;
	
	return $menu;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Pod::Frame;

use 5.008;
use strict;
use warnings;
use Data::Dumper qw{Dumper};
use Padre::DB    ();
use Padre::Wx    ();
use Padre::Pod::Viewer ();
use base 'Wx::Frame';

our $VERSION = '0.22';

my $search_term = '';
my $choice;
my $choices;

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new( undef,
	                             -1,
	                             'PodViewer ',
	                             Wx::wxDefaultPosition,
	                             [750, 700],
	                             );
	$self->_setup_podviewer();
	$self->_create_menu_bar;
	return $self;
}


sub _setup_podviewer {
	my ($self) = @_;

	my $panel = Wx::Panel->new( $self, -1,);

	my $html    = Padre::Pod::Viewer->new( $panel, -1 );
	my $top_s   = Wx::BoxSizer->new( Wx::wxVERTICAL );
	my $but_s   = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $forward = Wx::Button->new( $panel, -1, "Forward" );
	my $back    = Wx::Button->new( $panel, -1, "Back" );
	$but_s->Add( $back );
	$but_s->Add( $forward );

	# TODO: update list when a file is opened
	$choice = Wx::Choice->new( $panel, Wx::wxID_ANY, [ 0, 0 ], Wx::wxDefaultSize, scalar(Padre::DB->get_recent_pod), [ Padre::DB->get_recent_pod ] );
	$but_s->Add($choice);
	Wx::Event::EVT_CHOICE( $panel, $choice, \&on_selection );

	$choices = Padre::DB->find_modules;
	my @ch = @{$choices}[0..10];
	my $combobox = Wx::ComboBox->new($panel, -1, '', [375, 5], [-1, 32], []); #, $self->style);
	Wx::Event::EVT_COMBOBOX(   $panel, $combobox, \&on_combobox);
	Wx::Event::EVT_TEXT(       $panel, $combobox, sub { on_combobox_text_changed($combobox, @_) } );
	Wx::Event::EVT_TEXT_ENTER( $panel, $combobox, \&on_combobox_text_enter);

	$top_s->Add( $but_s, 0, Wx::wxALL, 5 );
	$top_s->Add( $html,  1, Wx::wxGROW|Wx::wxALL, 5 );

	$panel->SetSizer( $top_s );
	$panel->SetAutoLayout( 1 );

	Wx::Event::EVT_BUTTON( $panel, $back,    sub { on_back($self, @_)    } );
	Wx::Event::EVT_BUTTON( $panel, $forward, sub { on_forward($self, @_) } );

	$self->{html} = $html;

	return;
}


sub on_combobox_text_changed {
	my ( $combobox, $self ) = @_;
	my $text              = $combobox->GetValue;
	my $choices           = Padre::DB->find_modules($text);
	my $pod_maxlist = Padre->ide->config->{pod_maxlist};
	my $pod_minlist = Padre->ide->config->{pod_minlist};
	if ( $pod_minlist < @$choices and @$choices < $pod_maxlist ) {
		$combobox->Clear;
		foreach my $name (@$choices) {
			$combobox->Append($name);
		}
	} elsif ($pod_maxlist < @$choices) {
		$combobox->Clear;
	}
	return;
}

sub on_combobox_text_enter {
	my ($self, $event) = @_;
	on_selection($self, $event);
}

sub on_combobox {
	my ($self, $event) = @_;
	on_selection($self, $event);
}

sub on_selection {
	my ($self, $event) = @_;
	my $current = $choice->GetCurrentSelection;
	my $module  = (Padre::DB->get_recent_pod)[$current];
	if ( $module ) {
		# apparently there are cases where self isn't the window but a
		# subordinate panel
		# I still don't really understand who calls what so lets play save...
		if ( defined $self->{html} ) {
			$self->{html}->display($module);
		}
		else {
			my $win = $self;
			while ( $win = $win->GetParent ) {
				if ( defined $win->{html} ) {
					$win->{html}->display($module);
					last;
				}
			}
			# TODO error message?
		}
	} # TODO else error message?
	return;
}

sub _create_menu_bar {
	my ($self) = @_;

	my $bar  = Wx::MenuBar->new;
	my $file = Wx::Menu->new;
	my $edit = Wx::Menu->new;
	$bar->Append( $file, "&File" );
	$bar->Append( $edit, "&Edit" );
	$self->SetMenuBar( $bar );

	Wx::Event::EVT_MENU(  $self, $file->Append( Wx::wxID_OPEN, ''),  \&on_open);
	Wx::Event::EVT_MENU(  $self, $file->Append( Wx::wxID_EXIT, ''),  sub { $self->Close } );
	Wx::Event::EVT_MENU(  $self, $edit->Append( Wx::wxID_FIND, ''),  \&on_find);

	Wx::Event::EVT_CLOSE( $self,             \&on_close);

	return;
}


sub on_find {
	my ( $self ) = @_;

	my $dialog = Wx::TextEntryDialog->new( $self, "", "Type in search term", $search_term );
	if ($dialog->ShowModal == Wx::wxID_CANCEL) {
		return;
	}
	$search_term = $dialog->GetValue;
	$dialog->Destroy;
	return if not defined $search_term or $search_term eq '';

	my $text = $self->{html}->ToText();
	#use Wx::Point;
	#$self->{html}->SelectLine(Wx::Point->new(0,0));
	#$self->{html}->SelectLine(1);
	#my $point = $self->{html}->Point();
	#$self->{html}->SelectAll();
	print "$search_term\n";
	return;
}

sub on_open {
	my( $self ) = @_;

	my $dialog = Wx::TextEntryDialog->new( $self, "", "Type in module name", '' );
	if ($dialog->ShowModal == Wx::wxID_CANCEL) {
		return;
	}
	my $module = $dialog->GetValue;
	$dialog->Destroy;
	return if not $module;

	my $path = $self->{html}->module_to_path($module);
	if (not $path) {
		Wx::MessageBox( "Could not find module $module", "Invalid module name", Wx::wxOK|Wx::wxCENTRE|Wx::wxICON_EXCLAMATION, $self );
		return;
	}

	Padre::DB->add_recent_pod( $module);
	$self->{html}->display($module);

	return;
}

sub show {
	my ($self, $text) = @_;
	if (not $text) {
		# should not happen
		return;
	}
	# for now assume it is a module
	# later look it up in the indexed list of perl/module functions
	Padre::DB->add_recent_pod( $text);
	$self->{html}->display($text);

	return;
}


sub on_forward {
	my ( $self ) = @_;
	my $module = Padre->ide->next_module;
	if ( $module ) {
		$self->{html}->display($module);
	}
	return;
}

sub on_back {
	my ( $self ) = @_;
	my $module = Padre->ide->prev_module;
	if ( $module ) {
		$self->{html}->display($module);
	}
	return;
}

sub on_close {
	my ( $self, $event ) = @_;
	$self->Hide();
	#$event->Skip;
}

# returns the name of the previous module
sub prev_module {
	my ($self) = @_;

	# Temporarily breaking the next and back buttons
	# my $current = $self->get_current_index('pod');
	# return if not defined $current;
	#
	# return if not $current;
	# $self->set_current_index('pod', $current - 1);

	return Padre::DB->get_last_pod;
}

# returns the name of the next module
sub next_module {
	my ($self) = @_;

	# Temporarily breaking the next and back buttons
	# my $current = $self->get_current_index('pod');
	# return if not defined $current;
	#
	# my @current = Padre::DB->get_recent_pod;
	# return if $current == $#current;
	# $self->set_current_index('pod', $current + 1);

	return Padre::DB->get_last_pod;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.


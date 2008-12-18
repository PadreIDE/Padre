package Padre::Wx::ErrorList;

use strict;
use warnings;

our $VERSION = '0.20';

require Padre;
use Padre::Wx;
use Parse::ErrorString::Perl;

use base qw(Wx::TreeCtrl);

use Class::XSAccessor
	getters => {
		mw       => 'mw',
		root     => 'root',
		data     => 'data',
		enabled  => 'enabled',
		index    => 'index',
		parser   => 'parser',
		config   => 'config',
	};

sub new {
	my $class = shift;
	my $mw    = shift;
	my $config = Padre->ide->config;

	my $self = $class->SUPER::new(
	    $mw, 
	    -1, 
	    Wx::wxDefaultPosition, 
	    Wx::wxDefaultSize, 
	    Wx::wxTR_HAS_BUTTONS|Wx::wxTR_HIDE_ROOT|Wx::wxTR_LINES_AT_ROOT
	);

	$self->Hide;

	my $root = $self->AddRoot( 'Root', -1, -1, Wx::TreeItemData->new( 'Data' ) );
	$self->{root} = $root;	
	
	$self->{mw} = $mw;
	$self->{config} = $config;
	
	return $self;
}

sub DESTROY {
	my $self = shift;
	delete $self->{mw};
}

sub enable {
    my $self = shift;
    my $index = $self->{mw}->{gui}->{bottompane}->GetPageCount;
    $self->{mw}->{gui}->{bottompane}->InsertPage( $index, $self, Wx::gettext("Error List"), 0 );
    $self->Show;
	$self->{mw}->{gui}->{bottompane}->SetSelection($index);
	my $lang = $self->config->{diagnostics_lang};
	if ($lang) {
		$lang =~ s/^\s*//;
		$lang =~ s/\s*$//;
		$self->{parser} = Parse::ErrorString::Perl->new(lang => $lang);
	} else {
		$self->{parser} = Parse::ErrorString::Perl->new;
	}
    $self->{enabled} = 1;
}

sub disable {
    my $self = shift;
	my $index = $self->{mw}->{gui}->{bottompane}->GetPageIndex($self);
	$self->Hide;
    $self->{mw}->{gui}->{bottompane}->RemovePage($index);
    $self->{enabled} = 0;
}

sub populate {
	my $self = shift;
	return unless $self->enabled;
	my $root = $self->root;
	
	my $data = $self->data;
	my $parser = $self->parser;
	my @errors = $parser->parse_string($data);
	$self->{data} = "";
	Wx::Event::EVT_TREE_KEY_DOWN($self, $self, \&on_f1);
	
	foreach my $err (@errors) {
		my $message = $err->message . " at " . $err->file_msgpath . " line " . $err->line;
	    my $err_tree_item = $self->AppendItem( $root, $message, -1, -1, Wx::TreeItemData->new( $err ) );
	    
	    Wx::Event::EVT_TREE_ITEM_ACTIVATED($self, $self, \&on_activate);
	}
}

sub on_f1 {
	my ($self, $event) = @_;
	$event->Skip(0);
	my $key_code = $event->GetKeyCode;
	if ($key_code == Wx::WXK_F1) {
		#my $item = $event->GetItem;
	    my $item = $self->GetSelection;
    	my $err = $self->GetPlData($item);
		my $diagnostics = "No diagnostics available for this error!";
		if ($err->diagnostics) {
			$diagnostics = $err->diagnostics;
			$diagnostics =~ s/[A-Z]<(.*?)>/$1/sg;
		}
		my $dialog = Wx::MessageDialog->new($self->mw, $diagnostics, "Diagnostics", Wx::wxOK);
		$dialog->ShowModal;
	}
}

sub on_activate {
    my $self = shift;
    my $event = shift;
    my $item = $event->GetItem;
    my $err = $self->GetPlData($item);
    my $mw = $self->mw;
    $mw->setup_editor($err->file_abspath);
    my $editor = $mw->selected_editor;
    my $line_number = $err->line;
    $line_number--;
    $editor->GotoLine($line_number);
}

sub collect_data {
	my $self = shift;
	return unless $self->enabled;
	my $line = shift;
	#if (!$self->{data}) {
	#    my $root = $self->root;
	#    $self->DeleteChildren($root);
	#}
	$self->{data} .= $line;
	$self->{data} .= "\n";
}

sub clear {
	my $self = shift;
	my $root = $self->root;
    $self->DeleteChildren($root);
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::ErrorList;

use strict;
use warnings;

our $VERSION = '0.25';

require Padre;
use Padre::Wx;
use Padre::Task::ErrorParser;
use Parse::ErrorString::Perl;
use Wx::Locale qw(:default);
use Encode qw(encode);

use base qw(Wx::TreeCtrl);

use Class::XSAccessor
	getters => {
		mw       => 'mw',
		root     => 'root',
		data     => 'data',
		enabled  => 'enabled',
		index    => 'index',
		config   => 'config',
		lang     => 'lang',
		parser   => 'parser',
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

	Wx::Event::EVT_TREE_ITEM_ACTIVATED($self, $self, \&on_activate);
	#Wx::Event::EVT_TREE_KEY_DOWN($self, $self, \&on_f1);
	
	$self->{mw} = $mw;
	$self->{config} = $config;
	
	return $self;
}

sub DESTROY {
	delete $_[0]->{mw};
}

sub enable {
	my $self = shift;
	my $index = $self->{mw}->{gui}->{bottompane}->GetPageCount;
	$self->{mw}->{gui}->{bottompane}->InsertPage( $index, $self, Wx::gettext("Error List"), 0 );
	$self->Show;
	$self->{mw}->{gui}->{bottompane}->SetSelection($index);
	$self->mw->check_pane_needed('bottompane');
	$self->mw->aui->Update;
	$self->{enabled} = 1;
}

sub disable {
	my $self = shift;
	my $index = $self->{mw}->{gui}->{bottompane}->GetPageIndex($self);
	$self->Hide;
	$self->{mw}->{gui}->{bottompane}->RemovePage($index);
	$self->mw->check_pane_needed('bottompane');
	$self->mw->aui->Update;
	$self->{enabled} = 0;
}

sub populate {
	my $self = shift;
	return unless $self->enabled;
	
	my $cur_lang = $self->config->{diagnostics_lang};
	$cur_lang =~ s/^\s*//;
	$cur_lang =~ s/\s*$//;
	my $old_lang = $self->lang;
	$self->{lang} = $cur_lang;

	my $data = $self->data;
	$self->{data} = "";
	return unless $data;
	

	my $parser_task = Padre::Task::ErrorParser->new(
		parser    => $self->parser,
		cur_lang  => $cur_lang,
		old_lang  => $old_lang,
		data      => $data,
	);
	
	$parser_task->schedule;
}

sub on_f1 {
	my $self = shift;
	my $item = $self->GetSelection;
	return unless $item;
	my $err = $self->GetPlData($item);
	return if $err->isa('Parse::ErrorString::Perl::StackItem');
	my $diagnostics = gettext("No diagnostics available for this error!");
	if ($err->diagnostics) {
		$diagnostics = $err->diagnostics;
		$diagnostics =~ s/[A-Z]<(.*?)>/$1/sg;
	}
	$diagnostics = $^O eq 'MSWin32' ? $diagnostics : encode('utf8', $diagnostics);
	my $dialog_title = gettext("Diagnostics");
	if ($err->type_description) {
		$dialog_title .= (": " . gettext($err->type_description));
	}
	my $dialog = Wx::MessageDialog->new($self->mw, $diagnostics, $dialog_title, Wx::wxOK);
	$dialog->ShowModal;
}

sub on_activate {
	my $self  = shift;
	my $event = shift;
	my $item  = $event->GetItem or return;
	my $err   = $self->GetPlData($item);
	my $mw    = $self->mw;
	return if $err->file eq 'eval';
	$mw->setup_editor($err->file_abspath);
	my $editor = $mw->current->editor;
	my $line_number = $err->line;
	$line_number--;
	$editor->goto_line_centerize($line_number);
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


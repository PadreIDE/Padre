package Padre::Wx::ErrorList;

use strict;
use warnings;

our $VERSION = '0.22';

require Padre;
use Padre::Wx;
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
	Wx::Event::EVT_TREE_KEY_DOWN($self, $self, \&on_f1);
	
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
	my ($self, $event) = @_;
	$event->Skip(0);
	my $key_code = $event->GetKeyCode;
	if ($key_code == Wx::WXK_F1) {
		#my $item = $event->GetItem;
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
}

sub on_activate {
	my $self = shift;
	my $event = shift;
	my $item = $event->GetItem;
	return unless $item;
	my $err = $self->GetPlData($item);
	my $mw = $self->mw;
	return if $err->file eq 'eval';
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

package Padre::Task::ErrorParser;

use base 'Padre::Task';

use Class::XSAccessor
	getters => {
		parser       => 'parser',
		old_lang     => 'old_lang',
		cur_lang     => 'cur_lang',
		data         => 'data',
	};

sub run {
	my $self = shift;
	unless ($self->parser and ( (!$self->cur_lang and !$self->old_lang) or ($self->cur_lang eq $self->old_lang) )) {
		if ($self->cur_lang) {
			$self->{parser} = Parse::ErrorString::Perl->new(lang => $self->cur_lang);
		} else {
			$self->{parser} = Parse::ErrorString::Perl->new;
		}
	}
    return 1;
}

sub finish {
	my $self = shift;
    my $mw = shift;

	my $errorlist = $mw->errorlist;
	
	my $data = $self->data;
	my $parser = $self->parser;
	$errorlist->{parser} = $parser;

	my @errors = defined $data && $data ne '' ? $parser->parse_string($data) : ();
	
	foreach my $err (@errors) {
		my $message = $err->message . " at " . $err->file . " line " . $err->line;
		#$message = encode('utf8', $message);
		if ($err->near) {
			my $near = $err->near;
			# some day when we have unicode in wx ...
			#$near =~ s/\n/\x{c2b6}/g;
			$near =~ s/\n/\\n/g;
			$near =~ s/\r//g;
			$message .= ", near \"$near\"";
		} elsif ($err->at) {
			my $at = $err->at;
			$message .= ", at $at";
		}
		my $err_tree_item = $errorlist->AppendItem( $errorlist->root, $message, -1, -1, Wx::TreeItemData->new( $err ) );
		
		if ($err->stack) {
			foreach my $stack_item ($err->stack) {
				my $stack_message = $stack_item->sub . 
					" called at " . $stack_item->file . 
					" line " . $stack_item->line;
				$errorlist->AppendItem( $err_tree_item, $stack_message, -1, -1, Wx::TreeItemData->new( $stack_item ) );
			}
		}
	}
	
	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

#!/usr/bin/perl 
use strict;
use warnings;


#############################################################################
##
## Based on a very early version of Padre...
## The first version that could already save files.
##
## Copyright:   (c) The Padre development team
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

# see package main at the bottom of the file


#####################
package Demo::REPL;
use strict;
use warnings FATAL => 'all';

use base 'Wx::App';

sub OnInit {
	my $frame = Demo::Frame->new;
	$frame->Show(1);
}

#####################
package Demo::Frame;
use strict;
use warnings FATAL => 'all';

use Wx ':everything';
use Wx::Event ':everything';

use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);
use File::HomeDir;

use base 'Wx::Frame';

our $VERSION = '0.01';
my $default_dir = "";
our $nb;
my %nb;
my $search_term = '';

my @languages = ( "perl5", "perl6" );

sub new {
	my ($class) = @_;

	my ( $height, $width ) = ( 550, 500 );
	my $self = $class->SUPER::new(
		undef,
		-1,
		'REPL - Read Evaluate Print Loop ',
		[ -1,     -1 ],
		[ $width, $height ],
	);

	$self->_create_menu_bar;

	my $split = Wx::SplitterWindow->new(
		$self, -1, wxDefaultPosition, wxDefaultSize,
		wxNO_FULL_REPAINT_ON_RESIZE | wxCLIP_CHILDREN
	);

	my $output = Wx::TextCtrl->new(
		$split, -1, "", wxDefaultPosition, wxDefaultSize,
		wxTE_READONLY | wxTE_MULTILINE | wxNO_FULL_REPAINT_ON_RESIZE
	);

	my $input = Wx::TextCtrl->new(
		$split, -1, "", wxDefaultPosition, wxDefaultSize,
		wxNO_FULL_REPAINT_ON_RESIZE | wxTE_PROCESS_ENTER
	);

	EVT_TEXT_ENTER( $self, $input, \&text_entered );

	#	EVT_TEXT( $self, $input, sub { print "@_\n" } );

	EVT_KEY_UP( $input, sub { $self->key_up(@_) } );

	$split->SplitHorizontally( $output, $input, $height - 100 );
	$input->SetFocus;

	$self->{_input_}  = $input;
	$self->{_output_} = $output;

	foreach my $lang (@languages) {
		$self->{_history_}{$lang} = [];
		my $history_file = File::Spec->catdir( _confdir(), "repl_history_{$lang}.txt" );
		if ( -e $history_file ) {
			open my $fh, '<', $history_file or die;
			$self->{_history_}{$lang} = [<$fh>];
			chomp @{ $self->{_history_}{$lang} };
		}
	}
	return $self;
}

sub _confdir {
	return File::Spec->catdir(
		File::HomeDir->my_data,
		File::Spec->isa('File::Spec::Win32')
		? qw{ Perl Padre }
		: qw{ .padre }
	);
}

sub _get_language {
	my ($self) = @_;
	foreach my $lang (@languages) {
		return $lang if $self->{_language_}{$lang}->IsChecked;
	}
	return; # TODO die?
}

sub key_up {
	my ( $self, $input, $event ) = @_;

	#print $self;
	#print $event;
	my $mod = $event->GetModifiers || 0;
	my $code = $event->GetKeyCode;

	#$self->outn($mod);
	#$self->outn($code);
	my $lang = $self->_get_language;
	return if not @{ $self->{_history_}{$lang} };
	if ( $mod == 0 and $code == 317 ) { # Down
		$self->{_history_pointer_}{$lang}++;
		if ( $self->{_history_pointer_}{$lang} >= @{ $self->{_history_}{$lang} } ) {
			$self->{_history_pointer_}{$lang} = 0;
		}
	} elsif ( $mod == 0 and $code == 315 ) { # Up
		$self->{_history_pointer_}{$lang}--;
		if ( $self->{_history_pointer_}{$lang} < 0 ) {
			$self->{_history_pointer_}{$lang} = @{ $self->{_history_}{$lang} } - 1;
		}
	} else {
		return;
	}

	$self->{_input_}->Clear;
	$self->{_input_}->WriteText( $self->{_history_}{$lang}[ $self->{_history_pointer_}{$lang} ] );
}

sub text_entered {
	my ( $self, $event ) = @_;
	my $lang = $self->_get_language;
	my $text = $self->{_input_}->GetRange( 0, $self->{_input_}->GetLastPosition );
	push @{ $self->{_history_}{$lang} }, $text;
	$self->{_history_pointer_}{$lang} = @{ $self->{_history_}{$lang} } - 1;
	$self->{_input_}->Clear;
	$self->out(">> $text\n");

	# TODO catch stdout, stderr
	my $out   = eval $text;
	my $error = $@;
	if ( defined $out ) {
		$self->out("$out\n");
	}
	if ($error) {
		$self->out("$@\n");
	}

}


sub out {
	my ( $self, $text ) = @_;
	$self->{_output_}->WriteText($text);
}

sub outn {
	my ( $self, $text ) = @_;
	$self->{_output_}->WriteText("$text\n");
}

sub _create_menu_bar {
	my ($self) = @_;

	my $bar  = Wx::MenuBar->new;
	my $file = Wx::Menu->new;
	$file->Append( wxID_OPEN, "&Open" );
	$file->Append( wxID_SAVE, "&Save" );
	$self->{_language_}{perl5} = $file->AppendRadioItem( 1000, "Perl 5" );
	$self->{_language_}{perl6} = $file->AppendRadioItem( 1001, "Perl 6" );
	$file->Append( wxID_EXIT, "E&xit" );

	my $help = Wx::Menu->new;
	$help->Append( wxID_ABOUT, "&About..." );

	$bar->Append( $file, "&File" );
	$bar->Append( $help, "&Help" );

	$self->SetMenuBar($bar);

	EVT_CLOSE( $self, \&on_close_window );
	EVT_MENU( $self, wxID_OPEN, sub { on_open( $self, @_ ) } );
	EVT_MENU( $self, wxID_SAVE, sub { on_save( $self, @_ ) } );
	EVT_MENU( $self, wxID_EXIT, \&on_exit );
	EVT_MENU( $self, wxID_ABOUT, \&on_about );

	return;
}

sub on_exit {
	my ($self) = @_;

	$self->Close;
}


sub on_close_window {
	my ( $self, $event ) = @_;

	foreach my $lang (@languages) {
		my $history_file = File::Spec->catdir( _confdir(), "repl_history_{$lang}.txt" );
		open my $fh, '>', $history_file or die;
		print $fh map {"$_\n"} @{ $self->{_history_}{$lang} };
	}

	$event->Skip;
}


sub on_save_as {
	my ($self) = @_;

	my $id = $nb->GetSelection;
	while (1) {
		my $dialog = Wx::FileDialog->new( $self, "Save file as...", $default_dir, "", "*.*", wxFD_SAVE );
		if ( $dialog->ShowModal == wxID_CANCEL ) {

			#print "Cancel\n";
			return;
		}
		my $filename = $dialog->GetFilename;

		#print "OK $filename\n";
		$default_dir = $dialog->GetDirectory;

		my $path = catfile( $default_dir, $filename );
		if ( -e $path ) {
			my $res = Wx::MessageBox( "File already exists. Overwrite it?", 3, $self );
			if ( $res == 2 ) {
				$nb{$id}{filename} = $path;
				last;
			}
		} else {
			$nb{$id}{filename} = $path;
			last;
		}
	}
	$self->_save_buffer($id);
	return;
}

sub on_save {
	my ($self) = @_;
	my $id = $nb->GetSelection;
	return if not _buffer_changed($id);

	if ( $nb{$id}{filename} ) {
		$self->_save_buffer($id);
	} else {
		$self->on_save_as;
	}
	return;
}

sub _save_buffer {
	my ( $self, $id ) = @_;

	my $page    = $nb->GetPage($id);
	my $content = $page->GetText;
	if ( open my $out, '>', $nb{$id}{filename} ) {
		print $out $content;
	}
	$nb{$id}{content} = $content;

	return;
}

sub on_close {
	my ($self) = @_;

	my $id = $nb->GetSelection;
	if ( _buffer_changed($id) ) {
		Wx::MessageBox( "File changed.", wxOK | wxCENTRE, $self );
	}

	return;
}

sub _buffer_changed {
	my ($id) = @_;

	my $page    = $nb->GetPage($id);
	my $content = $page->GetText;
	return $content ne $nb{$id}{content};
}

sub on_setup {
	my ($self) = @_;
	Wx::MessageBox( "Not implemented yet.", wxOK | wxCENTRE, $self );
}


sub on_find {
	my ($self) = @_;

	my $dialog = Wx::TextEntryDialog->new( $self, "", "Type in search term", $search_term );
	if ( $dialog->ShowModal == wxID_CANCEL ) {
		return;
	}
	$search_term = $dialog->GetValue;
	$dialog->Destroy;
	return if not defined $search_term or $search_term eq '';

	print "$search_term\n";
	return;
}


sub on_about {
	my ($self) = @_;

	Wx::MessageBox(
		"wxPerl REPL, (c) 2010 Gabor Szabo\n" . "wxPerl edotr $VERSION, " . wxVERSION_STRING,
		"About wxPerl REPL", wxOK | wxCENTRE, $self
	);
}


#####################
package main;

my $app = Demo::REPL->new;
$app->MainLoop;


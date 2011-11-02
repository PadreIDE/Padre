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
package Demo::Editor;
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
use Wx::Scintilla ();

use File::Spec::Functions qw(catfile);
use File::Basename qw(basename);

use base 'Wx::Frame';

our $VERSION = '0.01';
my $default_dir = "";
my $editor;
our $nb;
my %nb;
my $search_term = '';


sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'Editor ',
		[ -1,  -1 ],
		[ 750, 700 ],
	);
	$nb = Wx::Notebook->new(
		$self, -1, wxDefaultPosition, wxDefaultSize,
		wxNO_FULL_REPAINT_ON_RESIZE | wxCLIP_CHILDREN
	);

	$self->_create_menu_bar;

	$self->setup_editor;
	return $self;
}

sub _create_menu_bar {
	my ($self) = @_;

	my $bar  = Wx::MenuBar->new;
	my $file = Wx::Menu->new;
	$file->Append( wxID_OPEN,   "&Open" );
	$file->Append( wxID_SAVE,   "&Save" );
	$file->Append( wxID_SAVEAS, "Save &As" );
	$file->Append( wxID_CLOSE,  "&Close" );
	$file->Append( wxID_EXIT,   "E&xit" );

	my $edit = Wx::Menu->new;
	$edit->Append( wxID_FIND, "&Find" );
	$edit->Append( 998,       "&Setup" );

	my $help = Wx::Menu->new;
	$help->Append( wxID_ABOUT, "&About..." );

	$bar->Append( $file, "&File" );
	$bar->Append( $edit, "&Edit" );
	$bar->Append( $help, "&Help" );

	$self->SetMenuBar($bar);

	EVT_CLOSE( $self, \&on_close_window );
	EVT_MENU( $self, wxID_OPEN, sub { on_open( $self, @_ ) } );
	EVT_MENU( $self, wxID_SAVE, sub { on_save( $self, @_ ) } );
	EVT_MENU( $self, wxID_SAVEAS, sub { on_save_as( $self, @_ ) } );
	EVT_MENU( $self, wxID_CLOSE, sub { on_close( $self, @_ ) } );
	EVT_MENU( $self, 998, sub { on_setup( $self, @_ ) } );
	EVT_MENU( $self, wxID_FIND, sub { on_find( $self, @_ ) } );
	EVT_MENU( $self, wxID_EXIT, \&on_exit );
	EVT_MENU( $self, wxID_ABOUT, \&on_about );

	return;
}

sub on_exit {
	my ($self) = @_;
	foreach my $id ( keys %nb ) {
		if ( _buffer_changed($id) ) {
			Wx::MessageBox( "One of the files is still not saved", "xx", wxOK | wxCENTRE, $self );
			return;
		}
	}

	$self->Close;
}

sub setup_editor {
	my ( $self, $file ) = @_;

	my $editor = Demo::Panel->new($nb);

	my $title   = "Unsaved Document 1";
	my $content = '';
	if ($file) {
		if ( open my $in, '<', $file ) {
			local $/ = undef;
			$content = <$in>;
		}
		$title = basename($file);
		$editor->SetText($content);
	}
	$nb->AddPage( $editor, $title, 1 );
	$nb{ $nb->GetSelection } = {
		filename => $file,
		content  => $content,
	};

	return;
}

sub on_close_window {
	my ( $self, $event ) = @_;
	$event->Skip;
}

sub on_open {
	my ($self) = @_;

	#Wx::MessageBox( "Not implemented yet. Should open a file selector", wxOK|wxCENTRE, $self );
	my $dialog = Wx::FileDialog->new( $self, "Open file", $default_dir, "", "*.*", wxFD_OPEN );
	if ( $dialog->ShowModal == wxID_CANCEL ) {

		#print "Cancel\n";
		return;
	}
	my $filename = $dialog->GetFilename;

	#print "OK $filename\n";
	$default_dir = $dialog->GetDirectory;

	my $file = catfile( $default_dir, $filename );

	$self->setup_editor($file);

	return;
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
		"wxPerl editor, (c) 2008 Gabor Szabo\n" . "wxPerl editor $VERSION, " . wxVERSION_STRING,
		"About wxPerl editor", wxOK | wxCENTRE, $self
	);
}

#####################

package Demo::Panel;

use strict;
use warnings FATAL => 'all';
use Wx::Scintilla;
use base 'Wx::Scintilla::TextCtrl';
use Wx ':everything';
use Wx::Event ':everything';

our $VERSION = '0.01';

sub new {
	my ( $class, $parent ) = @_;
	my $self = $class->SUPER::new( $parent, -1, [ -1, -1 ], [ 750, 700 ] ); # TODO get the numbers from the frame?

	my $font = Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL );

	$self->SetFont($font);

	$self->StyleSetFont( Wx::Scintilla::STYLE_DEFAULT, $font );
	$self->StyleClearAll;

	$self->StyleSetForeground( 0,  Wx::Colour->new( 0x00, 0x00, 0x7f ) );
	$self->StyleSetForeground( 1,  Wx::Colour->new( 0xff, 0x00, 0x00 ) );
	$self->StyleSetForeground( 2,  Wx::Colour->new( 0x00, 0x7f, 0x00 ) );
	$self->StyleSetForeground( 3,  Wx::Colour->new( 0x7f, 0x7f, 0x7f ) );
	$self->StyleSetForeground( 4,  Wx::Colour->new( 0x00, 0x7f, 0x7f ) );
	$self->StyleSetForeground( 5,  Wx::Colour->new( 0x00, 0x00, 0x7f ) );
	$self->StyleSetForeground( 6,  Wx::Colour->new( 0xff, 0x7f, 0x00 ) );
	$self->StyleSetForeground( 7,  Wx::Colour->new( 0x7f, 0x00, 0x7f ) );
	$self->StyleSetForeground( 8,  Wx::Colour->new( 0x00, 0x00, 0x00 ) );
	$self->StyleSetForeground( 9,  Wx::Colour->new( 0x7f, 0x7f, 0x7f ) );
	$self->StyleSetForeground( 10, Wx::Colour->new( 0x00, 0x00, 0x7f ) );
	$self->StyleSetForeground( 11, Wx::Colour->new( 0x00, 0x00, 0xff ) );
	$self->StyleSetForeground( 12, Wx::Colour->new( 0x7f, 0x00, 0x7f ) );
	$self->StyleSetForeground( 13, Wx::Colour->new( 0x40, 0x80, 0xff ) );
	$self->StyleSetForeground( 17, Wx::Colour->new( 0xff, 0x00, 0x7f ) );
	$self->StyleSetForeground( 18, Wx::Colour->new( 0x7f, 0x7f, 0x00 ) );
	$self->StyleSetBold( 12, 1 );
	$self->StyleSetSpec( Wx::Scintilla::SCE_H_TAG, "fore:#0000ff" );

	$self->SetLexer(Wx::Scintilla::SCLEX_PERL);

	$self->SetLayoutDirection(wxLayout_LeftToRight)
		if $self->can('SetLayoutDirection');

	return $self;
}

#####################
package main;

my $app = Demo::Editor->new;
$app->MainLoop;


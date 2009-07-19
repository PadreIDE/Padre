#!/usr/bin/perl 
use strict;
use warnings;

# based on a very early version of Padre...

# see package main at the bottom of the file

package Wx::Tutorial;
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

=head1 NAME

Wx::Tutorial - there is a Wx::Demo so this should be a pod viewer, for a start

=head1 SYNOPSIS

 perl wx_perl_tutorial.pl

=cut

use File::HomeDir         qw();
use File::Spec::Functions qw(catfile);
use DBI                   qw();
use Carp                  qw();
use YAML                  qw(LoadFile DumpFile);

use base 'Class::Accessor';

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(config));

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->{recent} = [];

    return $self;
}

sub run_editor {
    my $app = Wx::Tutorial::Editor->new;
    $app->MainLoop;
}

sub run {
    my $app = Wx::Tutorial::App->new;
    $app->MainLoop;
}

sub _config_dir {
    my $dir = catfile(
            File::HomeDir->my_data, 
            ($^O =~ /win32/i ? '_' : '.') . 'podviewer');
    if (not -e $dir) {
        mkdir $dir or die "Cannot create config dir '$dir' $!";
    }
    return $dir;
}

sub config_dbh {
    my ($self) = @_;

    my $dir = $self->_config_dir();
    my $path = catfile($dir, "config.db");
    my $new = not -e $path;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$path", "", "", {
        RaiseError       => 1,
        PrintError       => 1,
        AutoCommit       => 1,
        FetchHashKeyName => 'NAME_lc',
    });
    if ($new) {
       $self->create_config($dbh);
    }
    return $dbh;
}

sub config_yaml {
    my ($self) = @_;
    return catfile($self->_config_dir(), "config.yml");
}

sub set_defaults {
    my ($self) = @_;

    my $config = $self->get_config;
    $config->{DISPLAY_MAX_LIMIT} ||= 200;
    $config->{DISPLAY_MIN_LIMIT} ||= 2;
    $self->set_config($config);

    return;
}


sub add_to_recent {
    my ($self, $module) = @_;
    my @recent = $self->get_recent;
    if (not grep {$_ eq $module} @recent) {
        push @{ $self->{recent} }, $module;
        $self->{current} = @recent;
    }
    return;
}

sub get_recent {
    my ($self) = @_;
    return @{ $self->{recent} };
}
sub get_current {
    my ($self) = @_;

    return if not defined $self->{current};
    return $self->{recent}[ $self->{current} ];
}
sub set_current {
    my ($self, $module) = @_;
    foreach my $i (0.. @{ $self->{recent} } -1) {
        if ($self->{recent}[$i] eq $module) {
            $self->{current} = $i;
            last;
        }
    }
    return; 
}


package Wx::Tutorial::Editor;
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use base 'Wx::App';

sub OnInit {
    my $frame = Wx::Tutorial::EditorFrame->new;
    $frame->Show( 1 );
}


package Wx::Tutorial::EditorFrame;
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use Wx qw(:sizer);
use Wx qw(:textctrl :sizer :window :id);
use Wx qw(wxDefaultPosition wxDefaultSize 
          wxDEFAULT_FRAME_STYLE wxNO_FULL_REPAINT_ON_RESIZE wxCLIP_CHILDREN wxFD_OPEN wxFD_SAVE);
use Wx qw(wxOK wxCANCEL wxYES_NO  wxCENTRE wxVERSION_STRING  wxLB_MULTIPLE);
use Wx::Event qw(EVT_TREE_SEL_CHANGED EVT_MENU EVT_CLOSE EVT_LISTBOX EVT_LISTBOX_DCLICK);
use Wx::Event qw(EVT_BUTTON EVT_CHOICE);
use Wx::Event qw(EVT_COMBOBOX EVT_TEXT EVT_TEXT_ENTER
                EVT_NOTEBOOK_PAGE_CHANGED);

use File::Spec::Functions qw(catfile);
use File::Slurp     qw(read_file write_file);
use File::Basename  qw(basename);


use base 'Wx::Frame';


my $default_dir = "";
my $editor;
our $nb;
my %nb;

sub new {
    my ($class) = @_;

    my $self = $class->SUPER::new( undef,
                                 -1,
                                 'Editor ',
                                 [-1, -1],
                                 [750, 700],
                                 );
    $nb = Wx::Notebook->new
      ( $self, -1, wxDefaultPosition, wxDefaultSize,
        wxNO_FULL_REPAINT_ON_RESIZE|wxCLIP_CHILDREN );
    #EVT_NOTEBOOK_PAGE_CHANGED($nb, 1, sub {print " @_\n"});

    $self->_create_menu_bar;

    $self->setup_editor;
    return $self;
}

sub _create_menu_bar {
    my ($self) = @_;

    # create menu bar
    my $bar = Wx::MenuBar->new;
    my $file = Wx::Menu->new;
    $file->Append( wxID_OPEN, "&Open" );
    $file->Append( wxID_SAVE, "&Save" );
    $file->Append( wxID_SAVEAS, "Save &As" );
    $file->Append( wxID_CLOSE, "&Close" );
    $file->Append( wxID_EXIT, "E&xit" );

    my $edit = Wx::Menu->new;
    $edit->Append( wxID_FIND, "&Find" );
    $edit->Append( 998,       "&Setup" );

    my $help = Wx::Menu->new;
    $help->Append( wxID_ABOUT, "&About..." );

    $bar->Append( $file, "&File" );
    $bar->Append( $edit, "&Edit" );
    $bar->Append( $help, "&Help" );

    $self->SetMenuBar( $bar );

    EVT_CLOSE( $self,              \&on_close_window);
    EVT_MENU(  $self, wxID_OPEN,   sub { on_open($self, @_)  } );
    EVT_MENU(  $self, wxID_SAVE,   sub { on_save($self, @_)  } );
    EVT_MENU(  $self, wxID_SAVEAS, sub { on_save_as($self, @_)  } );
    EVT_MENU(  $self, wxID_CLOSE,  sub { on_close($self, @_)  } );
    EVT_MENU(  $self, 998,         sub { on_setup($self, @_) } );
    EVT_MENU(  $self, wxID_FIND,   sub { on_find($self, @_)  } );
    EVT_MENU(  $self, wxID_EXIT,   \&on_exit);
    EVT_MENU(  $self, wxID_ABOUT,  \&on_about );

    return;
}

sub on_exit {
    my ($self) = @_;
    foreach my $id (keys %nb) {
        if (_buffer_changed($id)) {
            Wx::MessageBox( "One of the files is still not saved", "xx", wxOK|wxCENTRE, $self );
            return;
        }
    }

    $self->Close
}

sub setup_editor {
    my ($self, $file) = @_;

    my $editor = Wx::Tutorial::EditorPanel->new($nb);

    my $title = "Unsaved Document 1";
    my $content = '';
    if ($file) {
        $content = read_file($file);
        $title   = basename($file);
        $editor->SetText( $content );
    }
    $nb->AddPage($editor, $title, 1); # TODO add closing x
    $nb{$nb->GetSelection} = {
        filename => $file,
        content  => $content,
    };
    #print $nb->GetPageText(0), "\n";
    #my $id = $nb->GetCurrentPage;
    #print "$id\n";
    #$nb{$id} = {
    #        file    => $file,
    #        changed => 0,
    #};
    #$editor->SetFocus;


#    my $top_s   = Wx::BoxSizer->new( wxVERTICAL );
#    my $but_s   = Wx::BoxSizer->new( wxHORIZONTAL );
#
#    my $forward = Wx::Button->new( $panel, -1, "Forward" );
#    my $back = Wx::Button->new( $panel, -1, "Back" );
#    $but_s->Add( $forward );
#    #$but_s->Add( $back );
#
#    $top_s->Add( $but_s, 0, wxALL, 5 );
#    $top_s->Add( $editor,  1, wxGROW|wxALL, 5 );
#    $panel->SetSizer( $top_s );
#    $panel->SetAutoLayout( 1 );

    return;
}

sub on_close_window {
    my ( $self, $event ) = @_;
    $event->Skip;
}

sub on_open {
    my( $self ) = @_;
    #Wx::MessageBox( "Not implemented yet. Should open a file selector", wxOK|wxCENTRE, $self );
    my $dialog = Wx::FileDialog->new( $self, "Open file", $default_dir, "", "*.*", wxFD_OPEN);
    if ($dialog->ShowModal == wxID_CANCEL) {
        #print "Cancel\n";
        return;
    }
    my $filename = $dialog->GetFilename;
    #print "OK $filename\n";
    $default_dir = $dialog->GetDirectory;

    my $file = catfile($default_dir, $filename);

    # if the current buffer is empty then fill that with the content of the current file
    # otherwise open a new buffer and open the file there
    $self->setup_editor($file);

    return;
}
sub on_save_as {
    my ($self) = @_;

    my $id   = $nb->GetSelection;
    while (1) {
        my $dialog = Wx::FileDialog->new( $self, "Save file as...", $default_dir, "", "*.*", wxFD_SAVE);
        if ($dialog->ShowModal == wxID_CANCEL) {
            #print "Cancel\n";
            return;
        }
        my $filename = $dialog->GetFilename;
        #print "OK $filename\n";
        $default_dir = $dialog->GetDirectory;

        my $path = catfile($default_dir, $filename);
        if (-e $path) {
            my $res = Wx::MessageBox("File already exists. Overwrite it?", 3, $self);
            if ($res == 2) {
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
    my $id   = $nb->GetSelection;
    return if not _buffer_changed($id);

    if ($nb{$id}{filename}) {
        $self->_save_buffer($id);
    } else {
        $self->on_save_as();
    }
    return;
}

sub _save_buffer {
    my ($self, $id) = @_;

    my $page = $nb->GetPage($id);
    my $content = $page->GetText;
    eval {
        write_file($nb{$id}{filename}, $content);
    };
    $nb{$id}{content} = $content;

    return; 
}

sub on_close {
    my ($self) = @_;
    
    my $id   = $nb->GetSelection;
    if (_buffer_changed($id)) {
        Wx::MessageBox( "File changed.", wxOK|wxCENTRE, $self );
    }

    return;
}
sub _buffer_changed {
    my ($id) = @_;

    my $page = $nb->GetPage($id);
    #print "$page\n";
    #print $nb->GetPage($id), "\n";
    my $content = $page->GetText;
    return $content ne $nb{$id}{content};
}

sub on_setup {
    my( $self ) = @_;
    Wx::MessageBox( "Not implemented yet.", wxOK|wxCENTRE, $self );
}

my $search_term = '';

sub on_find {
    my ( $self ) = @_;

    my $dialog = Wx::TextEntryDialog->new( $self, "", "Type in search term", $search_term );
    if ($dialog->ShowModal == wxID_CANCEL) {
        return;
    }   
    $search_term = $dialog->GetValue;
    $dialog->Destroy;
    return if not defined $search_term or $search_term eq '';

    #print "$search_term\n";
    return;
}


sub on_about {
    my ( $self ) = @_;

    Wx::MessageBox( "wxPerl editor, (c) 2008 Gabor Szabo\n" .
                    "wxPerl edotr $VERSION, " . wxVERSION_STRING,
                    "About wxPerl editor", wxOK|wxCENTRE, $self );
}


package Wx::Tutorial::EditorPanel;
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';
use Wx::STC;
use base 'Wx::StyledTextCtrl';

use Wx;
use Wx qw(:stc :textctrl :font wxDefaultPosition wxDefaultSize :id
          wxNO_FULL_REPAINT_ON_RESIZE wxLayout_LeftToRight);
use Wx qw(wxDefaultPosition wxDefaultSize wxTheClipboard 
          wxDEFAULT_FRAME_STYLE wxNO_FULL_REPAINT_ON_RESIZE wxCLIP_CHILDREN);
use Wx::Event qw(EVT_TREE_SEL_CHANGED EVT_MENU EVT_CLOSE EVT_STC_CHANGE);

sub new {
    my( $class, $parent ) = @_;
    my $self = $class->SUPER::new( $parent, -1, [-1, -1], [750, 700]); # TODO get the numbers from the frame?

    my $font = Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL );

    $self->SetFont( $font );

    $self->StyleSetFont( wxSTC_STYLE_DEFAULT, $font );
    $self->StyleClearAll();

    $self->StyleSetForeground(0, Wx::Colour->new(0x00, 0x00, 0x7f));
    $self->StyleSetForeground(1,  Wx::Colour->new(0xff, 0x00, 0x00));
    $self->StyleSetForeground(2,  Wx::Colour->new(0x00, 0x7f, 0x00));
    $self->StyleSetForeground(3,  Wx::Colour->new(0x7f, 0x7f, 0x7f));
    $self->StyleSetForeground(4,  Wx::Colour->new(0x00, 0x7f, 0x7f));
    $self->StyleSetForeground(5,  Wx::Colour->new(0x00, 0x00, 0x7f));
    $self->StyleSetForeground(6,  Wx::Colour->new(0xff, 0x7f, 0x00));
    $self->StyleSetForeground(7,  Wx::Colour->new(0x7f, 0x00, 0x7f));
    $self->StyleSetForeground(8,  Wx::Colour->new(0x00, 0x00, 0x00));
    $self->StyleSetForeground(9,  Wx::Colour->new(0x7f, 0x7f, 0x7f));
    $self->StyleSetForeground(10, Wx::Colour->new(0x00, 0x00, 0x7f));
    $self->StyleSetForeground(11, Wx::Colour->new(0x00, 0x00, 0xff));
    $self->StyleSetForeground(12, Wx::Colour->new(0x7f, 0x00, 0x7f));
    $self->StyleSetForeground(13, Wx::Colour->new(0x40, 0x80, 0xff));
    $self->StyleSetForeground(17, Wx::Colour->new(0xff, 0x00, 0x7f));
    $self->StyleSetForeground(18, Wx::Colour->new(0x7f, 0x7f, 0x00));
    $self->StyleSetBold(12,  1);
    $self->StyleSetSpec( wxSTC_H_TAG, "fore:#0000ff" );

    $self->SetLexer( wxSTC_LEX_PERL );

    $self->SetLayoutDirection( wxLayout_LeftToRight )
      if $self->can( 'SetLayoutDirection' );

    ##print $self->GetModEventMask() & wxSTC_MOD_INSERTTEXT;
    ##print "\n";
    #$self->SetModEventMask( wxSTC_MOD_INSERTTEXT  | wxSTC_PERFORMED_USER );
    #EVT_STC_CHANGE($self, -1, \&on_change );
    return $self;
}

sub on_change {
    #print "@_\n";
    my $nb = $Wx::Tutorial::EditorFrame::nb;
    #print $nb->GetCurrentPage, "\n";
    print $nb->GetSelection, "\n";
    return;
}


package main;

our $app = Wx::Tutorial->new;
$app->run_editor;




package Padre::Document;

=pod

=head1 NAME

Padre::Document - Padre Document API

=head1 DESCRIPTION

The B<Padre::Document> class provides a base class, default implementation
and API documentation for document type support in L<Padre>.

As an API, it allows L<Padre> developers and plugin authors to implement
extended support for various document types in Padre, while ensuring that
a naive default document implementation exists that allows Padre to provide
basic support (syntax highlighting mainly) for many document types without
the need to install extra modules unless you need the extra functionality.

=head2 Document Type Registration

Padre uses MIME types as the fundamental identifier when working with
documents. Files are typed at load-time based on file extension (with a
simple heuristic fallback when opening files with no extension).

Many of the MIME types are unofficial X-style identifiers, but in cases
without an official type, Padre will try to use the most popular
identifier (based on research into the various language communities).

Each supported mime has a mapping to a Scintilla lexer (for syntax
highlighting), and an optional mapping to the class that provides enhanced
support for that document type.

Plugins that implement support for a document type provide a
C<registered_documents> method that the PluginManager will call as needed.

Plugin authors should B<not> load the document classes in advance, they
will be automatically loaded by Padre as needed.

Padre does B<not> currently support opening non-text files.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp           ();
use File::Spec     ();
use Class::Autouse ();
use Padre::Util    ();
use Padre::Wx      ();
use Padre          ();

our $VERSION = '0.29';

# NOTE: This is probably a bad place to store this
my $unsaved_number = 0;

#####################################################################
# Document Registration

# This is the list of binary files
# (which we don't support loading in fallback text mode)
our %EXT_BINARY = (aiff => 1, au => 1, avi => 1, bmp => 1, cache => 1, dat => 1, doc => 1, gif => 1, gz => 1, icns => 1,
                   jar => 1, jpeg => 1, jpg => 1, m4a => 1, mov => 1, mp3  => 1, mpg => 1, ogg => 1, pdf => 1, png => 1,
                   pnt => 1, ppt  => 1, qt  => 1, ra  => 1, svg => 1, svgz => 1, svn => 1, swf => 1, tar => 1, tgz => 1,
                   tif => 1, tiff => 1, wav => 1, xls => 1, xlw => 1, zip  => 1,
);

# This is the primary file extension to mime-type mapping
our %EXT_MIME = ( ada   => 'text/x-adasrc',
                  asm   => 'text/x-asm',
                  bat   => 'text/x-bat',
                  cpp   => 'text/x-c++src',
                  css   => 'text/css',
                  diff  => 'text/x-patch',
                  e     => 'text/x-eiffel',
                  f     => 'text/x-fortran',
                  htm   => 'text/html',
                  html  => 'text/html',
                  js    => 'application/javascript',
                  json  => 'application/json',
                  latex => 'application/x-latex',
                  lsp   => 'application/x-lisp',
                  lua   => 'text/x-lua',
                  mak   => 'text/x-makefile',
                  mat   => 'text/x-matlab',
                  pas   => 'text/x-pascal',
                  pod   => 'text/x-pod',
                  php   => 'application/x-php',
                  py    => 'text/x-python',
                  rb    => 'application/x-ruby',
                  sql   => 'text/x-sql',
                  tcl   => 'application/x-tcl',
                  vbs   => 'text/vbscript',
                  patch => 'text/x-patch',
                  pl    => 'application/x-perl',
                  plx   => 'application/x-perl',
                  pm    => 'application/x-perl',
                  pod   => 'application/x-perl',
                  t     => 'application/x-perl',
                  conf  => 'text/plain',
                  sh    => 'application/x-shellscript',
                  ksh   => 'application/x-shellscript',
                  txt   => 'text/plain',
                  xml   => 'text/xml',
                  yml   => 'text/x-yaml',
                  yaml  => 'text/x-yaml',
                  '4th' => 'text/x-forth',
                  pasm  => 'application/x-pasm',
                  pir   => 'application/x-pir',
                  p6    => 'application/x-perl6',
);

# This is the mime-type to Scintilla lexer mapping.
# Lines marked with CONFIRMED indicate that the mime-typehas been checked
# to confirm that the MIME type is either the official type, or the primary
# one in use by the relevant language community.
our %MIME_LEXER = (
    'text/x-adasrc' => Wx::wxSTC_LEX_ADA,    # CONFIRMED
    'text/x-asm'    => Wx::wxSTC_LEX_ASM,    # CONFIRMED

    # application/x-msdos-program includes .exe and .com, so don't use it
    'application/x-bat' => Wx::wxSTC_LEX_BATCH,    # CONFIRMED

    'text/x-c++src'             => Wx::wxSTC_LEX_CPP,          # CONFIRMED
    'text/css'                  => Wx::wxSTC_LEX_CSS,          # CONFIRMED
    'text/x-patch'              => Wx::wxSTC_LEX_DIFF,         # CONFIRMED
    'text/x-eiffel'             => Wx::wxSTC_LEX_EIFFEL,       # CONFIRMED
    'text/x-forth'              => Wx::wxSTC_LEX_FORTH,        # CONFIRMED
    'text/x-fortran'            => Wx::wxSTC_LEX_FORTRAN,      # CONFIRMED
    'text/html'                 => Wx::wxSTC_LEX_HTML,         # CONFIRMED
    'application/javascript'    => Wx::wxSTC_LEX_ESCRIPT,      # CONFIRMED
    'application/json'          => Wx::wxSTC_LEX_ESCRIPT,      # CONFIRMED
    'application/x-latex'       => Wx::wxSTC_LEX_LATEX,        # CONFIRMED
    'application/x-lisp'        => Wx::wxSTC_LEX_LISP,         # CONFIRMED
    'application/x-shellscript' => Wx::wxSTC_LEX_BASH,
    'text/x-lua'                => Wx::wxSTC_LEX_LUA,          # CONFIRMED
    'text/x-makefile'           => Wx::wxSTC_LEX_MAKEFILE,     # CONFIRMED
    'text/x-matlab'             => Wx::wxSTC_LEX_MATLAB,       # CONFIRMED
    'text/x-pascal'             => Wx::wxSTC_LEX_PASCAL,       # CONFIRMED
    'application/x-perl'        => Wx::wxSTC_LEX_PERL,         # CONFIRMED
    'text/x-python'             => Wx::wxSTC_LEX_PYTHON,       # CONFIRMED
    'application/x-php'         => Wx::wxSTC_LEX_PHPSCRIPT,    # CONFIRMED
    'application/x-ruby'        => Wx::wxSTC_LEX_RUBY,         # CONFIRMED
    'text/x-sql'                => Wx::wxSTC_LEX_SQL,          # CONFIRMED
    'application/x-tcl'         => Wx::wxSTC_LEX_TCL,          # CONFIRMED
    'text/vbscript'             => Wx::wxSTC_LEX_VBSCRIPT,     # CONFIRMED

    # text/xml specifically means "human-readable XML".
    # This is prefered to the more generic application/xml
    'text/xml' => Wx::wxSTC_LEX_XML,                           # CONFIRMED

    'text/x-yaml'         => Wx::wxSTC_LEX_YAML,               # CONFIRMED
    'application/x-pir'   => Wx::wxSTC_LEX_CONTAINER,          # CONFIRMED
    'application/x-pasm'  => Wx::wxSTC_LEX_CONTAINER,          # CONFIRMED
    'application/x-perl6' => Wx::wxSTC_LEX_CONTAINER,          # CONFIRMED
    'text/plain'          => Wx::wxSTC_LEX_NULL,               # CONFIRMED
);

# This is the mime-type to document class mapping
our %MIME_CLASS = ( 'application/x-perl' => 'Padre::Document::Perl', 'text/x-pod' => 'Padre::Document::POD', );

sub menu_view_mimes {
    '00Plain Text'     => 'text/plain',
        '01Perl'       => 'application/x-perl',
        '02Shell'      => 'application/x-shellscript',
        '03HTML'       => 'text/html',
        '05JavaScript' => 'application/javascript',
        '07CSS'        => 'text/css',
        '09Python'     => 'text/x-python',
        '11Ruby'       => 'application/x-ruby',
        '13PHP'        => 'application/x-php',
        '15YAML'       => 'text/x-yaml',
        '17VBScript'   => 'text/vbscript',
        '19SQL'        => 'text/x-sql',
        '21Perl6'      => 'application/x-perl6',
        ;
}

#####################################################################
# Constructor and Accessors

use Class::XSAccessor getters => { editor           => 'editor',
                                   filename         => 'filename',       # TODO is this read_only or what?
                                   get_mimetype     => 'mimetype',
                                   get_newline_type => 'newline_type',
                                   errstr           => 'errstr',
    },
    setters => { _set_filename    => 'filename',       # TODO temporary hack
                 set_newline_type => 'newline_type',
                 set_mimetype     => 'mimetype',
                 set_errstr       => 'errstr',
                 set_editor       => 'editor',
    };

=pod

=head2 new

  my $doc = Padre::Document->new(
      filename => $file,
  );

$file is optional and if given it will be loaded in the document

mime-type is defined by the guess_mimetype function

=cut

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;

    if ( $self->{filename} ) {
        $self->load_file;
    }
    else {
        $unsaved_number++;
        $self->{newline_type} = $self->_get_default_newline_type;
    }

    unless ( $self->get_mimetype ) {
        $self->set_mimetype( $self->guess_mimetype );
    }

    $self->rebless;

    return $self;
}

sub rebless {
    my ($self) = @_;

    # Rebless as either to a subclass if there is a mime-type or
    # to the the base class,
    # This isn't exactly the most elegant way to do this, but will
    # do for a first implementation.
    my $subclass = $MIME_CLASS{ $self->get_mimetype } || __PACKAGE__;
    if ($subclass) {
        Class::Autouse->autouse($subclass);
        bless $self, $subclass;
    }

    return;
}

sub last_sync {
    return $_[0]->{_timestamp};
}

#####################################################################
# Bad/Ugly/Broken Methods
# These don't really completely belong in this class, but there's
# currently nowhere better for them. Some break API boundaries...
# NOTE: This is NOT an excuse to invent somewhere new that's just as
# innappropriate just to get them out of here.

sub guess_mimetype {
    my $self     = shift;
    my $text     = $self->{original_content};
    my $filename = $self->filename || q{};

    # Default mime-type of new files, should be configurable in the GUI
    # TODO: Make it configurable in the GUI :)
    unless ($filename) {
        return 'application/x-perl';
    }

    # Perl 6:   use v6; class ..., module ...
    # maybe also grammar ...
    # but make sure that is real code and not just a comment or doc in some perl 5 code...

    # Try derive the mime type from the name
    if ( $filename and $filename =~ /\.([^.]+)$/ ) {
        my $ext = lc $1;
        if ( $EXT_MIME{$ext} ) {
            if ( $EXT_MIME{$ext} eq 'application/x-perl' ) {

                # Sometimes Perl 6 will look like Perl 5
                if ( is_perl6($text) ) {
                    return 'application/x-perl6';
                }
            }
            return $EXT_MIME{$ext};
        }
    }

    # Try derive the mime type from the basename
    my $basename = File::Basename::basename($filename);
    if ($basename) {
        return 'text/x-makefile' if $basename =~ /^Makefile\.?/i;
    }

    # Fall back on deriving the type from the content.
    # Hardcode this for now for the cases that we care about and
    # are obvious.
    # TODO: Add support for plugins being able to do something here.
    if ( $text and $text =~ /\A#!/m ) {

        # Found a hash bang line
        if ( $text =~ /\A#![^\n]*\bperl6?\b/m ) {
            return is_perl6($text) ? 'application/x-perl6' : 'application/x-perl';
        }
        if ( $text =~ /\A---/ ) {
            return 'text/x-yaml';
        }
    }

    # Fall back to a null value
    return '';
}

sub mime_type_by_extension {
	my ($self, $ext) = @_;
	return $EXT_MIME{$ext};
}

# For ts without a newline type
# TODO: get it from config
sub _get_default_newline_type {
    Padre::Util::NEWLINE;
}

# naive sub to decide if a piece of code is Perl 6 or Perl 5.
sub is_perl6 {
    my ($text) = @_;
    return if not $text;
    return 1 if $text =~ /^=begin\s+pod/msx;
    return   if $text =~ /^=head[12]/msx;

    return 1 if $text =~ /^\s*use\s+v6;/msx;
    return 1 if $text =~ /^\s*class\s+\w/msx;
    return;
}

# Where to convert (UNIX, WIN, MAC)
# or Ask (the user) or Keep (the garbage)
# mixed files
# TODO get from config
sub _mixed_newlines {
    Padre::Util::NEWLINE;
}

# What to do with files that have inconsistent line endings:
# 0 if keep as they are
# MAC|UNIX|WIN convert them to the appropriate type
sub _auto_convert {
    my ($self) = @_;

    # TODO get from config
    return 0;
}

#####################################################################
# Disk Interaction Methods
# These methods implement the interaction between the document and the
# filesystem.

sub is_new {
    return !!( not defined $_[0]->filename );
}

sub is_modified {
    return !!( $_[0]->editor->GetModify );
}

sub is_saved {
    return !!( defined $_[0]->filename and not $_[0]->is_modified );
}

# Returns true if this is a new document that is too insignificant to
# bother checking with the user before throwing it away.
# Usually this is because it's empty or just has a space or two in it.
sub is_unused {
    my $self = shift;
    return '' unless $self->is_new;
    return 1  unless $self->is_modified;
    return 1  unless $self->text_get =~ /[^ \t]/s;
    return '';
}

# Returns true if file has changed on the disk
# since load time or the last time we saved it.
# Check if the file on the disk has changed
# 1) when document gets the focus (gvim, notepad++)
# 2) when we try to save the file (gvim)
# 3) every time we type something ????
sub has_changed_on_disk {
    my ($self) = @_;
    return 0 if not defined $self->filename;
    return 0 if not defined $self->last_sync;
    return $self->last_sync < $self->time_on_file ? 1 : 0;
}

sub time_on_file {
    return 0 if not defined $_[0]->filename;
    return 0 if not -e $_[0]->filename;
    return ( stat( $_[0]->filename ) )[9];
}

=pod

=head2 load_file

 $doc->load_file;
 
Loads the current file.

Sets the B<Encoding> bit using L<Encode::Guess> and tries to figure
out what kind of newlines are in the file. Defaults to utf-8 if
could not figure out the encoding.

Currently it autoconverts files with mixed newlines. TODO we should stop autoconverting.

Returns true on success false on failure. Sets $doc->errstr;

=cut

sub load_file {
    my ($self) = @_;

    my $file = $self->{filename};

    # check if file exists
    if ( !-e $file ) {

        # file doesn't exist, try to create an empty one
        if ( not open my $fh, '>', $file ) {

            # oops, error creating file. abort operation
            print ">>$file $!\n";
            $self->set_errstr($!);
            return;
        }
    }

    # load file
    $self->set_errstr('');
    my $content;
    if ( open my $fh, '<', $file ) {
        binmode($fh);
        local $/ = undef;
        $content = <$fh>;
    }
    else {
        $self->set_errstr($!);
        return;
    }
    $self->{_timestamp} = $self->time_on_file;

    # if guess encoding fails then use 'utf-8'
    require Padre::Locale;
    $self->{encoding} = Padre::Locale::encoding_from_string($content);
    $content = Encode::decode( $self->{encoding}, $content );

    $self->{original_content} = $content;

    return 1;
}

sub newline_type {
    my ($self) = @_;

    my $file         = $self->{filename};
    my $newline_type = $self->_get_default_newline_type;
    my $convert_to;
    my $current_type = Padre::Util::newline_type( $self->{original_content} );
    if ( $current_type eq 'None' ) {

        # keep default
    }
    elsif ( $current_type eq 'Mixed' ) {
        my $mixed = $self->_mixed_newlines();
        if ( $mixed eq 'Ask' ) {
            warn "TODO ask the user what to do with $file";

            # $convert_to = $newline_type = ;
        }
        elsif ( $mixed eq 'Keep' ) {
            warn "TODO probably we should not allow keeping garbage ($file) \n";
        }
        else {

            #warn "TODO converting $file";
            $convert_to = $newline_type = $mixed;
        }
    }
    else {
        $convert_to = $self->_auto_convert;
        if ($convert_to) {

            #warn "TODO call converting on $file";
            $newline_type = $convert_to;
        }
        else {
            $newline_type = $current_type;
        }
    }
    return ( $newline_type, $convert_to );
}

sub save_file {
    my ($self) = @_;
    $self->set_errstr('');

    my $content  = $self->text_get;
    my $filename = $self->filename;

    # not set when first time to save
    require Padre::Locale;
    $self->{encoding} ||= Padre::Locale::encoding_from_string($content);

    my $encode = '';
    if ( defined $self->{encoding} ) {
        $encode = ":raw:encoding($self->{encoding})";
    }
    else {
        warn "encoding is not set, (couldn't get from contents) when saving file $filename\n";
    }

    if ( open my $fh, ">$encode", $filename ) {
        print {$fh} $content;
    }
    else {
        $self->set_errstr($!);
        return;
    }
    $self->{_timestamp} = $self->time_on_file;
    return 1;
}

=pod

=head2 reload

Reload the current file discarding changes in the editor.

Returns true on success false on failure. Error message will be in $doc->errstr;

TODO: In the future it should backup the changes in case the user regrets the action.

=cut

sub reload {
    my ($self) = @_;

    my $filename = $self->filename or return;
    return $self->load_file;
}

#####################################################################
# Basic Content Manipulation

sub text_get {
    $_[0]->editor->GetText;
}

sub text_set {
    $_[0]->editor->SetText( $_[1] );
}

sub text_like {
    my $self = shift;
    return !!( $self->text_get =~ /$_[0]/m );
}

# --

#
# $doc->store_cursor_position()
#
# store document's current cursor position in padre's db.
# no params, no return value.
#
sub store_cursor_position {
    my $self     = shift;
    my $filename = $self->filename;
    my $editor   = $self->editor;
    return unless $filename && $editor;
    my $pos = $editor->GetCurrentPos;
    Padre::DB::LastPositionInFile->set_last_pos( $filename, $pos );
}

#
# $doc->restore_cursor_position()
#
# restore document's cursor position from padre's db.
# no params, no return value.
#
sub restore_cursor_position {
    my $self     = shift;
    my $filename = $self->filename;
    my $editor   = $self->editor;
    return unless $filename && $editor;
    my $pos = Padre::DB::LastPositionInFile->get_last_pos($filename);
    return unless $pos;
    $editor->SetCurrentPos($pos);
    $editor->SetSelection( $pos, $pos );
}

#####################################################################
# GUI Integration Methods

# Determine the Scintilla lexer to use
sub lexer {
    my $self = shift;
    return Wx::wxSTC_LEX_AUTOMATIC unless $self->get_mimetype;
    return Wx::wxSTC_LEX_AUTOMATIC unless defined $MIME_LEXER{ $self->get_mimetype };

    # If mime type is not sufficient to figure out file type
    # than use suffix for lexer
    my $filename = $self->filename || q{};
    if ( $filename and $filename =~ /\.([^.]+)$/ ) {
        my $ext = lc $1;
        if ( $EXT_MIME{$ext} ) {
            if ( $EXT_MIME{$ext} eq 'text/plain' ) {
                return Wx::wxSTC_LEX_CONF if $ext eq 'conf';
            }
        }
    }

    return $MIME_LEXER{ $self->get_mimetype };
}

# What should be shown in the notebook tab
sub get_title {
    my $self = shift;
    if ( $self->{filename} ) {
        return File::Basename::basename( $self->{filename} );
    }
    else {
        my $str = sprintf( Wx::gettext("Unsaved %d"), $unsaved_number );

        # A bug in Wx requires a space at the front of the title
        # (For reasons I don't understand yet)
        return ' ' . $str;
    }
}

sub remove_color {
    my ($self) = @_;

    my $editor = $self->editor;

    # TODO this is strange, do we really need to do it with all?
    for my $i ( 0 .. 31 ) {
        $editor->StartStyling( 0, $i );
        $editor->SetStyling( $editor->GetLength, 0 );
    }

    return;
}

# TODO: experimental
sub get_indentation_style {
    my $self   = shift;
    my $config = Padre->ide->config;

    # TODO: (document >) project > config

    my $style;
    if ( $config->editor_indent_auto ) {

        # TODO: This should be cached? What's with newish documents then?
        $style = $self->guess_indentation_style;
    }
    else {
        $style = { use_tabs    => $config->editor_indent_tab,
                   tabwidth    => $config->editor_indent_tab_width,
                   indentwidth => $config->editor_indent_width,
        };
    }

    return $style;
}

=head2 set_indentation_style

Given a hash reference with the keys C<use_tabs>,
C<tabwidth>, and C<indentwidth>, set the document's editor's
indentation style.

Without an argument, falls back to what C<get_indentation_style>
returns.

=cut

sub set_indentation_style {
    my $self   = shift;
    my $style  = shift || $self->get_indentation_style;
    my $editor = $self->editor;

    # The display width of literal tab characters (ne "indentation width"!)
    $editor->SetTabWidth( $style->{tabwidth} );

    # The actual indentation width in COLUMNS!
    $editor->SetIndent( $style->{indentwidth} );

    # Use tabs for indentation where possible?
    $editor->SetUseTabs( $style->{use_tabs} );

    return ();
}

=head2 guess_indentation_style

Automatically infer the indentation style of the document using
L<Text::FindIndent>.

Returns a hash reference containing the keys C<use_tabs>,
C<tabwidth>, and C<indentwidth>. It is suitable for passing
to C<set_indendentation_style>.

=cut

sub guess_indentation_style {
    my $self = shift;

    require Text::FindIndent;
    my $indentation = Text::FindIndent->parse( $self->text_get );

    my $style;
    if ( $indentation =~ /^t\d+/ ) {    # we only do ONE tab
        $style = { use_tabs => 1, tabwidth => 8, indentwidth => 8, };
    }
    elsif ( $indentation =~ /^s(\d+)/ ) {
        $style = { use_tabs => 0, tabwidth => 8, indentwidth => $1, };
    }
    elsif ( $indentation =~ /^m(\d+)/ ) {
        $style = { use_tabs => 1, tabwidth => 8, indentwidth => $1, };
    }
    else {

        # fallback
        my $config = Padre->ide->config;
        $style = { use_tabs    => $config->editor_indent_tab,
                   tabwidth    => $config->editor_indent_tab_width,
                   indentwidth => $config->editor_indent_width,
        };
    }

    return $style;
}

=head2 event_on_char

NOT IMPLEMENTED IN THE BASE CLASS

This method - if implemented - is called after any addition of a character
to the current document. This enables document classes to aid the user
in the editing process in various ways, e.g. by auto-pairing of brackets
or by suggesting usable method names when method-call syntax is detected.

Parameters retrieved are the objects for the document, the editor, and the 
wxWidgets event.

Returns nothing.

Cf. C<Padre::Document::Perl> for an example.

=head2 event_on_right_down

NOT IMPLEMENTED IN THE BASE CLASS

This method - if implemented - is called when a user right-clicks in an 
editor to open a context menu and after the standard context menu was 
created and populated in the C<Padre::Wx::Editor> class.
By manipulating the menu document classes may provide the user with 
additional options.

Parameters retrieved are the objects for the document, the editor, the 
context menu (C<Wx::Menu>) and the event.

Returns nothing.

=cut

#####################################################################
# Project Integration Methods

sub project {
    my $self = shift;
    my $root = $self->project_dir;
    if ( defined $root ) {
        return Padre->ide->project($root);
    }
    else {
        return undef;
    }
}

sub project_dir {
    my $self = shift;
    $self->{project_dir}
        or $self->{project_dir} = $self->project_find;
}

sub project_find {
    my $self = shift;

    # Anonymous files don't have a project
    unless ( defined $self->filename ) {
        return;
    }

    # Search upwards from the file to find the project root
    my ( $v, $d, $f ) = File::Spec->splitpath( $self->filename );
    my @d = File::Spec->splitdir($d);
    pop @d if $d[-1] eq '';
    my $dirs = List::Util::first {
        -f File::Spec->catpath( $v, $_, 'Makefile.PL' )
            or -f File::Spec->catpath( $v, $_, 'Build.PL' )
            or -f File::Spec->catpath( $v, $_, 'padre.yml' );
    }
    map { File::Spec->catdir( @d[ 0 .. $_ ] ) } reverse( 0 .. $#d );

    unless ( defined $dirs ) {

        # This document is part of the null project
        return File::Spec->catpath( $v, $d, '' );
    }

    return File::Spec->catpath( $v, $dirs, '' );
}

#####################################################################
# Document Analysis Methods

# Abstract methods, each subclass should implement it
# TODO: Clearly this isn't ACTUALLY abstract (since they exist)

sub keywords {
    return {};
}

sub get_functions {
    return ();
}

sub get_function_regex {
    return '';
}

sub pre_process {
    return 1;
}

sub stats {
    my ($self) = @_;

    my ( $lines, $chars_with_space, $chars_without_space, $words, $is_readonly ) = (0) x 5;

    my $editor = $self->editor;
    my $src    = $editor->GetSelectedText;
    my $code;
    if ($src) {
        $code = $src;

        my $code2 = $code;    # it's ugly, need improvement
        $code2 =~ s/\r\n/\n/g;
        $lines = 1;           # by default
        $lines++ while ( $code2 =~ /[\r\n]/g );
        $chars_with_space = length($code);
    }
    else {
        $code = $self->text_get;

        # I trust editor more
        $lines            = $editor->GetLineCount();
        $chars_with_space = $editor->GetTextLength();
        $is_readonly      = $editor->GetReadOnly();
    }

    $words++               while ( $code =~ /\b\w+\b/g );
    $chars_without_space++ while ( $code =~ /\S/g );

    my $filename = $self->filename;

    # not set when first time to save
    require Padre::Locale;
    $self->{encoding} ||= Padre::Locale::encoding_from_string($src);

    return ( $lines, $chars_with_space, $chars_without_space, $words, $is_readonly, $filename, $self->{newline_type},
             $self->{encoding} );
}

=pod

=head2 check_syntax

NOT IMPLEMENTED IN THE BASE CLASS

See also: C<check_syntax_in_background>!

By default, this method will only check the syntax if
the document has changed since the last check. Specify
the C<force =E<gt> 1> parameter to override this.

An implementation in a derived class needs to return an arrayref of
syntax problems.

Each entry in the array has to be an anonymous hash with the 
following keys:

=over 4

=item * line

The line where the problem resides

=item * msg

A short description of the problem

=item * severity

A flag indicating the problem class: Either 'B<W>' (warning) or 'B<E>' (error)

=item * desc

A longer description with more information on the error (currently 
not used but intended to be)

=back

Returns an empty arrayref if no problems can be found.

Returns B<undef> if nothing has changed since the last invocation.

Must return the problem list even if nothing has changed when a 
param is present which evaluates to B<true>.

=head2 check_syntax_in_background

NOT IMPLEMENTED IN THE BASE CLASS

Checking the syntax of documents can take a long time.
Therefore, this method essentially works the same as
C<check_syntax>, but works its magic in a background task
instead. That means it cannot return the syntax-check
structure but instead optionally calls a callback
you pass in as the C<on_finish> parameter.

If you don't specify that parameter, the default
syntax-check-pane updating code will be run after finishing
the check. If you do specify a callback, the first parameter
will be the task object. You can
run the default updating code by executing the
C<update_gui()> method of the task object.

By default, this method will only check the syntax if
the document has changed since the last check. Specify
the C<force =E<gt> 1> parameter to override this.

=cut

#####################################################################
# Document Manipulation Methods

#
# $doc->comment_lines_str;
#
# this is of course dependant on the language, and thus it's actually
# done in the subclasses. however, we provide base empty methods in
# order for padre not to crash if user wants to un/comment lines with
# a document type that did not define those methods.
#
# TODO Remove this base method, and compensate by disabling the menu entries
# if the document class does not define this method.
sub comment_lines_str { }

#####################################################################
# Unknown Methods
# Dumped here because it's not clear which section they belong in

# should return ($length, @words)
# where $length is the length of the prefix to be replaced by one of the words
# or
# return ($error_message)
# in case of some error
sub autocomplete {
    my $self = shift;

    my $editor = $self->editor;
    my $pos    = $editor->GetCurrentPos;
    my $line   = $editor->LineFromPosition($pos);
    my $first  = $editor->PositionFromLine($line);

    # line from beginning to current position
    my $prefix = $editor->GetTextRange( $first, $pos );
    $prefix =~ s{^.*?(\w+)$}{$1};
    my $last      = $editor->GetLength();
    my $text      = $editor->GetTextRange( 0, $last );
    my $pre_text  = $editor->GetTextRange( 0, $first + length($prefix) );
    my $post_text = $editor->GetTextRange( $first, $last );

    my $regex;
    eval { $regex = qr{\b($prefix\w+)\b} };
    if ($@) {
        return ("Cannot build regex for '$prefix'");
    }

    my %seen;
    my @words;
    push @words, grep { !$seen{$_}++ } reverse( $pre_text =~ /$regex/g );
    push @words, grep { !$seen{$_}++ } ( $post_text =~ /$regex/g );

    if ( @words > 20 ) {
        @words = @words[ 0 .. 19 ];
    }

    return ( length($prefix), @words );
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

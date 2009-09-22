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

=head2 File to MIME-type mapping

Padre has a built-in hash mapping the file exetensions to mime-types.
In certain cases (.t, .pl, .pm) Padre also looks in the content of the
file to determine if the file is Perl 5 or Perl 6.

mime-types are mapped to lexers that provide the syntax highlighting.

mime-types are also mapped to modules that implement 
special features needed by that kind of a file type.

Plug-ins can add further mappings.

=head3 Plan

Padre has a built-in mapping of file extension to either 
a single mime-type or function name. In order to determine
the actual mime-type Padre checks this hash. If the key
is a subroutine it is called and it should return the 
mime-type of the file.

The user has a way in the GUI to add more file extensions 
and map them to existing mime-types or funtions. It is probably
better to have a commonly used name along with the mime-type
in that GUI instead of the mime-type only.

I wonder if we should allow the users (and or plugin authors) to
change the functions or to add new functions that will map
file content to mime-type or if we should just tell them to 
patch Padre. What if they need it for some internal project?

A plugin is able to add new supported mime-types. Padre should
either check for collisions if a plugin already wants to provide
an already suported mime-type or should allow multiple support
modules with a way to select the current one. (Again I think we
probably don't need this. People can just come and add the 
mime-types to Padre core.) (not yet implemented)

A plugin can register zero or more modules that implement 
special features needed by certain mime-types. Every mime-type
can have only one module that implements its features. Padre is
checking if a mime-type already has a registered module and
does not let to replace it.
(Special features such as commenting out a few lines at once,
autocompletion or refactoring tools).

Padre should check if the given mime-type is one that is
in the supported mime-type list. (TODO)


Each mime-type is mapped to one or more lexers that provide 
the syntax highlighting. Every mime-type has to be mapped to at least 
one lexer but it can be mapped to several lexers as well. 
The user is able to select the lexer for each mime-type.
(For this each lexer should have a reasonable name too.) (TODO)

Every plugin should be able to add a list of lexers to the existing 
mime-types regardless if the plugin also provides the class that 
implements the features of that mime-type. By default Padre
suppors the built-in syntax highlighting of Scintialla but. 
Perl 5 currently has two PPI based syntax highlighter,
Perl 6 can use the STD.pm or Rakudo/PGE for syntax highlighting but 
there are two plugins Parrot and Kate that can provide synax 
highlighting to a wide range of mime-types.

 provided_highlighters()  returns a lits of arrays like this:
    ['Module with a colorize function' => 'Human readable Name' => 'Long description']

 highlighting_mime_types() returns a hash where the keys are module
 names listed in the provided_highlighters the values are array references to mime-types
     'Module::A' => [ mime-type-1, mime-type-2]

    

The user can change the mime-type mapping of individual 
files and Padre should remember this choice and allow the
user to change it to another specific mime-type
or to set it to "Default by extension".

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp             ();
use File::Spec       ();
use Padre::Constant  ();
use Padre::Util      ();
use Padre::Wx        ();
use Padre            ();
use Padre::MimeTypes ();
use Padre::File      ();

our $VERSION = '0.46';





#####################################################################
# Document Registration

# NOTE: This is probably a bad place to store this
my $unsaved_number = 0;

# TODO generate this from the the MIME_TYPES in the Padre::MimeTypes class?
sub menu_view_mimes {
	return (
		'00Plain Text' => 'text/plain',
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
		'21Perl 6'     => 'application/x-perl6',
	);
}





#####################################################################
# Constructor and Accessors

use Class::XSAccessor getters => {
	editor           => 'editor',
	filename         => 'filename',    # TODO is this read_only or what?
	file             => 'file',        # Padre::File - object
	get_mimetype     => 'mimetype',
	get_newline_type => 'newline_type',
	errstr           => 'errstr',
	tempfile         => 'tempfile',
	get_highlighter  => 'highlighter',
	},
	setters => {
	set_newline_type => 'newline_type',
	set_mimetype     => 'mimetype',
	set_errstr       => 'errstr',
	set_editor       => 'editor',
	set_tempfile     => 'tempfile',
	set_highlighter  => 'highlighter',
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
		$self->{file} = Padre::File->new( $self->{filename} );

		# The Padre::File - module knows how to format the filename to the right
		# syntax to correct (for example) .//file.pl to ./file.pl)
		$self->{filename} = $self->{file}->{Filename};

		if ( $self->{file}->exists ) {

			# Test script must be able to pass an alternate config object:
			my $config = $self->{config} || Padre->ide->config;
			if ( defined( $self->{file}->size ) and ( $self->{file}->size > $config->editor_file_size_limit ) ) {
				$self->error(
					sprintf(
						Wx::gettext(
							"Cannot open %s as it is over the arbitrary file size limit of Padre which is currently %s"
						),
						$self->{filename},
						$config->editor_file_size_limit
					)
				);
				return;
			}
		}
		$self->load_file;
	} else {
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
	my $mime_type = $self->get_mimetype or return;
	my $class = Padre::MimeTypes->get_mime_class($mime_type) || __PACKAGE__;
	Padre::Util::debug("Reblessing to mimetype: '$class'");
	if ($class) {
		unless ( $class->VERSION ) {
			eval "require $class;";
			die("Failed to load $class: $@") if $@;
		}
		bless $self, $class;
	}

	my $module = Padre::MimeTypes->get_current_highlighter_of_mime_type($mime_type);
	my $filename = $self->filename || '';
	warn("No module  mime_type='$mime_type' filename='$filename'\n") unless $module;

	#warn("Module '$module' mime_type='$mime_type' filename='$filename'\n") if $module;
	$self->set_highlighter($module);

	return;
}





#####################################################################
# Padre::Document GUI Integration

sub colourize {
	my $self   = shift;
	my $lexer  = $self->lexer;
	my $editor = $self->editor;
	$editor->SetLexer($lexer);

	$self->remove_color;
	if ( $lexer == Wx::wxSTC_LEX_CONTAINER ) {
		$self->colorize;
	} else {
		$editor->Colourise( 0, $editor->GetLength );
	}
}

sub colorize {
	my $self = shift;

	Padre::Util::debug("colorize called");

	my $module = $self->get_highlighter;
	if ( $module eq 'stc' ) {

		#TODO sometime this happens when I open Padre with several file
		# I think this can be somehow related to the quick (or slow ?) switching of
		# what is the current document while the code is still running.
		# for now I hide the warnings as this would just frighten people and the
		# actual problem seems to be only the warning or maybe late highighting
		# of a single document - szabgab
		#Carp::cluck("highlighter is set to 'stc' while colorize() is called for " . ($self->filename || '') . "\n");
		#warn "Length: " . $self->editor->GetTextLength;
		return;
	}

	# allow virtual modules if they have a colorize method
	unless ( $module->can('colorize') ) {
		eval "use $module";
		if ($@) {
			Carp::cluck( "Could not load module '$module' for file '" . ( $self->filename || '' ) . "'\n" );
			return;
		}
	}
	if ( $module->can('colorize') ) {
		$module->colorize(@_);
	} else {
		warn("Module $module does not have a colorize method\n");
	}
	return;
}

sub last_sync {
	return $_[0]->{_timestamp};
}

sub basename {
	my $self = shift;
	return $self->{file}->basename if defined( $self->{file} );
	return $self->{filename};
}

sub dirname {
	my $self = shift;
	return $self->{file}->dirname if defined( $self->{file} );
	return;
}

# For ts without a newline type
# TODO: get it from config
sub _get_default_newline_type {

	# Very ugly hack to make the test script work
	if ( $0 =~ /t.70\-document\.t/ ) {
		Padre::Constant::NEWLINE;
	} else {
		Padre->ide->config->default_line_ending;
	}
}

=pod

=head3 error

    $document->error( $msg );

Open an error dialog box with C<$msg> as main text. There's only one OK
button. No return value.

=cut

# TODO: A globally used error/message box function may be better instead
#       of replicating the same function in many files:
sub error {
	Padre->ide->wx->main->message( $_[1], Wx::gettext('Error') );
}





#####################################################################
# Disk Interaction Methods
# These methods implement the interaction between the document and the
# filesystem.

sub is_new {
	return !!( not defined $_[0]->file );
}

sub is_modified {
	return !!( $_[0]->editor->GetModify );
}

sub is_saved {
	return !!( defined $_[0]->file and not $_[0]->is_modified );
}

# Returns true if this is a new document that is too insignificant to
# bother checking with the user before throwing it away.
# Usually this is because it's empty or just has a space or two in it.
sub is_unused {
	my $self = shift;
	return '' unless $self->is_new;
	return 1  unless $self->is_modified;
	return 1  unless $self->text_get =~ /\S/s;
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
	return 0 unless defined $self->file;
	return 0 unless defined $self->last_sync;

	# Caching the result for two lines saved one stat-I/O each time this sub is run
	my $time_on_file = $self->time_on_file;
	return 0 unless defined $time_on_file; # there may be no mtime on remote files

	# Return -1 if file has been deleted from disk
	return -1 unless $time_on_file;

	# Return 1 if the file has changed on disk, otherwise 0
	return $self->last_sync < $time_on_file ? 1 : 0;
}

sub time_on_file {
	my $self = shift;
	my $file = $self->file;
	return 0 unless defined $file;

	# It's important to return undef if there is no ->mtime for this filetype
	my $Time = $file->mtime;
	return $Time;
}

# Generate MD5-checksum for current file stored on disk
sub checksum_on_file {
	warn join( ',', caller ) . ' called Document::checksum_on_file which is out-of-service.';
	return 1;
	my $filename = $_[0]->filename;
	return undef unless defined $filename;

	require Digest::MD5;

	open my $FH, $filename or return;
	binmode($FH);
	return Digest::MD5->new->addfile(*$FH)->hexdigest;
}

=pod

=head2 load_file

 $doc->load_file;
 
Loads the current file.

Sets the B<Encoding> bit using L<Encode::Guess> and tries to figure
out what kind of newlines are in the file. Defaults to utf-8 if
could not figure out the encoding.

Returns true on success false on failure. Sets $doc->errstr;

=cut

sub load_file {
	my ($self) = @_;

	my $file = $self->file;

	Padre::Util::debug("Loading file '$file->{Filename}'");

	# check if file exists
	if ( !$file->exists ) {

		# file doesn't exist, try to create an empty one
		if ( !$file->write('') ) {

			# oops, error creating file. abort operation
			$self->set_errstr( $file->error );
			return;
		}
	}

	# load file
	$self->set_errstr('');
	my $content = $file->read;
	if ( !defined($content) ) {
		$self->set_errstr( $file->error );
		return;
	}
	$self->{_timestamp} = $self->time_on_file;

	# if guess encoding fails then use 'utf-8'
	require Padre::Locale;
	$self->{encoding} = Padre::Locale::encoding_from_string($content);

	#warn $self->{encoding};
	$content = Encode::decode( $self->{encoding}, $content );

	$self->{original_content} = $content;

	# Determine new line type using file content.
	$self->{newline_type} = Padre::Util::newline_type($content);

	return 1;
}

# New line type can be one of these values:
# WIN, MAC (for classic Mac) or UNIX (for Mac OS X and Linux/*BSD)
# Special cases:
# 'Mixed' for mixed end of lines,
# 'None' for one-liners (no EOL)
sub newline_type {
	my $self = shift;
	return $self->{newline_type} or $self->_get_default_newline_type;
}

# Get the newline char(s) for this document.
# TODO: This solution is really terrible - it should be {newline} or at least a caching of the value
#       because of speed issues:
sub newline {
	my $self = shift;
	if ( $self->get_newline_type eq 'WIN' ) {
		return "\r\n";
	} elsif ( $self->get_newline_type eq 'MAC' ) {
		return "\r";
	}
	return "\n";
}

sub _set_filename {
	my $self     = shift;
	my $filename = shift;

	if ( !defined($filename) ) {
		warn 'Request to set filename to undef from ' . join( ',', caller );
		return 0;
	}

	return 1 if defined( $self->{filename} ) and ( $self->{filename} eq $filename );

	undef $self->{file}; # close file object
	$self->{file} = Padre::File->new($filename);

	# Padre::File reformats filenames to the protocol/OS specific format, so use this:
	$self->{filename} = $self->{file}->{Filename};
}

sub save_file {
	my ($self) = @_;
	$self->set_errstr('');

	my $content = $self->text_get;
	my $file    = $self->file;
	if ( !defined($file) ) {
		$file = Padre::File->new( $self->filename );
		$self->{file} = $file;
	}

	# This is just temporary for security and should prevend data loss:
	if ( $self->{filename} ne $file->{Filename} ) {
		my $ret = Wx::MessageBox(
			sprintf(
				Wx::gettext('Visual filename %s does not match the internal filename %s, do you want to abort saving?'),
				$self->{filename},
				$file->{Filename}
			),
			Wx::gettext("Save Warning"),
			Wx::wxYES_NO | Wx::wxCENTRE,
			Padre->ide->wx->main,
		);

		return 0 if $ret == Wx::wxYES;
	}

	# not set when first time to save
	# allow the upgrade from ascii to utf-8 if there were unicode characters added
	require Padre::Locale;
	if ( not $self->{encoding} or $self->{encoding} eq 'ascii' ) {
		$self->{encoding} = Padre::Locale::encoding_from_string($content);
	}

	my $encode = '';
	if ( defined $self->{encoding} ) {
		$encode = ":raw:encoding($self->{encoding})";
	} else {
		warn "encoding is not set, (couldn't get from contents) when saving file $file->{Filename}\n";
	}

	if ( !$file->write( $content, $encode ) ) {
		$self->set_errstr( $file->error );
		return;
	}

	# File must be closed at this time, slow fs/userspace-fs may not return the correct result otherwise!
	$self->{_timestamp} = $self->time_on_file;

	# Determine new line type using file content.
	$self->{newline_type} = Padre::Util::newline_type($content);

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

	my $file = $self->file or return;
	return $self->load_file;
}

# Copies document content to a temporary file.
# Returns temporary file name.
sub store_in_tempfile {
	my $self = shift;

	$self->create_tempfile unless $self->tempfile;

	open FH, ">", $self->tempfile;
	print FH $self->text_get;
	close FH;

	return $self->tempfile;
}

sub create_tempfile {
	use File::Temp;

	my $tempfile = File::Temp->new( UNLINK => 0 );
	$_[0]->set_tempfile( $tempfile->filename );
	close $tempfile;

	return;
}

sub remove_tempfile {
	unlink $_[0]->tempfile;
	return;
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

sub text_with_one_nl {
	my $self   = shift;
	my $text   = $self->text_get;
	my $nlchar = "\n";
	if ( $self->get_newline_type eq 'WIN' ) {
		$nlchar = "\r\n";
	} elsif ( $self->get_newline_type eq 'MAC' ) {
		$nlchar = "\r";
	}
	$text =~ s/$nlchar/\n/g;
	return $text;
}

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

	# this should never happen as now we set mime-type on everything
	return Wx::wxSTC_LEX_AUTOMATIC unless $self->get_mimetype;

	my $highlighter = $self->get_highlighter;
	if ( not $highlighter ) {
		warn "no highlighter\n";
		$highlighter = 'stc';
	}
	return Wx::wxSTC_LEX_CONTAINER if $highlighter ne 'stc';
	return Wx::wxSTC_LEX_AUTOMATIC unless defined Padre::MimeTypes->get_lexer( $self->get_mimetype );

	Padre::Util::debug( 'STC Lexer will be based on mime type "' . $self->get_mimetype . '"' );
	return Padre::MimeTypes->get_lexer( $self->get_mimetype );
}

# What should be shown in the notebook tab
sub get_title {
	my $self = shift;
	if ( $self->filename ) {
		return $self->basename;
	} else {
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
	} else {
		$style = {
			use_tabs    => $config->editor_indent_tab,
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

=head2 event_on_left_up

NOT IMPLEMENTED IN THE BASE CLASS

This method - if implemented - is called when a user left-clicks in an 
editor. This can be used to implement context-sensitive actions if
the user presses modifier keys while clicking.

Parameters retrieved are the objects for the document, the editor,
and the event.

Returns nothing.

=cut





#####################################################################
# Project Integration Methods

sub project {
	my $self = shift;
	my $root = $self->project_dir;
	if ( defined $root ) {
		return Padre->ide->project($root);
	} else {
		return;
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
	unless ( defined $self->file ) {
		return;
	}

	# Currently no project support for remote files:
	if ( $self->{file}->{protocol} ne 'local' ) { return; }

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
		return File::Spec->catpath( $v, File::Spec->catdir(@d), '' );
	}
	$self->{is_project} = 1;
	return File::Spec->catpath( $v, $dirs, '' );
}





#####################################################################
# Document Analysis Methods

# Unreliable methods that provide heuristic best-attempts at automatically
# determining various document properties.

# Left here a it is used in many places.
# Maybe we need to remove this sub.
sub guess_mimetype {
	my $self = shift;
	Padre::MimeTypes->guess_mimetype(
		$self->{original_content},
		$self->file,
	);
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
	if ( $indentation =~ /^t\d+/ ) { # we only do ONE tab
		$style = {
			use_tabs    => 1,
			tabwidth    => 8,
			indentwidth => 8,
		};
	} elsif ( $indentation =~ /^s(\d+)/ ) {
		$style = {
			use_tabs    => 0,
			tabwidth    => 8,
			indentwidth => $1,
		};
	} elsif ( $indentation =~ /^m(\d+)/ ) {
		$style = {
			use_tabs    => 1,
			tabwidth    => 8,
			indentwidth => $1,
		};
	} else {

		# fallback
		my $config = Padre->ide->config;
		$style = {
			use_tabs    => $config->editor_indent_tab,
			tabwidth    => $config->editor_indent_tab_width,
			indentwidth => $config->editor_indent_width,
		};
	}

	return $style;
}

=head2 guess_filename

  my $name = $document->guess_filename

When creating new code, one job that the editor should really be able to do
for you without needing to be told is to work out where to save the file.

When called on a new unsaved file, this method attempts to guess what the
name of the file should be based purely on the content of the file.

In the base implementation, this returns C<undef> to indicate that the
method cannot make a reasonable guess at the name of the file.

Your mime-type specific document subclass should implement any file name
detection as it sees fit, returning the file name as a string.

=cut

sub guess_filename {
	return undef;
}

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

		my $code2 = $code; # it's ugly, need improvement
		$code2 =~ s/\r\n/\n/g;
		$lines = 1;        # by default
		$lines++ while ( $code2 =~ /[\r\n]/g );
		$chars_with_space = length($code);
	} else {
		$code = $self->text_get;

		# I trust editor more
		$lines            = $editor->GetLineCount();
		$chars_with_space = $editor->GetTextLength();
		$is_readonly      = $editor->GetReadOnly();
	}

	# avoid slow calculation on large files
	# TODO or improve them ?
	if ( length($code) < 100_000 ) {
		$words++               while ( $code =~ /\b\w+\b/g );
		$chars_without_space++ while ( $code =~ /\S/g );
	} else {
		$words               = Wx::gettext("Skipped for large files");
		$chars_without_space = Wx::gettext("Skipped for large files");
	}

	my $filename = $self->filename;

	# not set when first time to save
	# allow the upgread of ascii to utf-8
	require Padre::Locale;
	if ( not $self->{encoding} or $self->{encoding} eq 'ascii' ) {
		$self->{encoding} = Padre::Locale::encoding_from_string($src);
	}
	return (
		$lines, $chars_with_space, $chars_without_space, $words, $is_readonly, $filename, $self->{newline_type},
		$self->{encoding}
	);
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
	my $self   = shift;
	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);

	# line from beginning to current position
	my $prefix = $editor->GetTextRange( $first, $pos );
	$prefix =~ s{^.*?(\w+)$}{$1};
	my $last = $editor->GetLength();
	my $text = $editor->GetTextRange( 0, $last );
	my $pre  = $editor->GetTextRange( 0, $first + length($prefix) );
	my $post = $editor->GetTextRange( $first, $last );

	my $regex = eval {qr{\b($prefix\w+)\b}};
	if ($@) {
		return ("Cannot build regex for '$prefix'");
	}

	my %seen;
	my @words;
	push @words, grep { !$seen{$_}++ } reverse( $pre =~ /$regex/g );
	push @words, grep { !$seen{$_}++ } ( $post =~ /$regex/g );

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

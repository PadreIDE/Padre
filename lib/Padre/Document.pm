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
use Carp            ();
use File::Spec      ();
use Padre::Constant ();
use Padre::Util     ();
use Padre::Wx       ();
use Padre           ();

our $VERSION = '0.40';

# NOTE: This is probably a bad place to store this
my $unsaved_number = 0;

#####################################################################
# Document Registration

# This is the list of binary files
# (which we don't support loading in fallback text mode)
my %EXT_BINARY = map { $_ => 1 } qw{
	aiff  au    avi  bmp  cache  dat   doc  gif  gz   icns
	jar   jpeg  jpg  m4a  mov    mp3   mpg  ogg  pdf  png
	pnt   ppt   qt   ra   svg    svgz  svn  swf  tar  tgz
	tif   tiff  wav  xls  xlw    zip
};

# This is the primary file extension to mime-type mapping
my %EXT_MIME = (
	abc   => 'text/x-abc',
	ada   => 'text/x-adasrc',
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
	pl    => \&perl_mime_type,
	plx   => \&perl_mime_type,
	pm    => \&perl_mime_type,
	pod   => \&perl_mime_type,
	t     => \&perl_mime_type,
	conf  => 'text/x-config',
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
my %MIME_LEXER = (
	'text/x-abc' => Wx::wxSTC_LEX_NULL,

	'text/x-adasrc' => Wx::wxSTC_LEX_ADA, # CONFIRMED
	'text/x-asm'    => Wx::wxSTC_LEX_ASM, # CONFIRMED

	# application/x-msdos-program includes .exe and .com, so don't use it
	'application/x-bat' => Wx::wxSTC_LEX_BATCH, # CONFIRMED

	'text/x-c++src'             => Wx::wxSTC_LEX_CPP,       # CONFIRMED
	'text/css'                  => Wx::wxSTC_LEX_CSS,       # CONFIRMED
	'text/x-patch'              => Wx::wxSTC_LEX_DIFF,      # CONFIRMED
	'text/x-eiffel'             => Wx::wxSTC_LEX_EIFFEL,    # CONFIRMED
	'text/x-forth'              => Wx::wxSTC_LEX_FORTH,     # CONFIRMED
	'text/x-fortran'            => Wx::wxSTC_LEX_FORTRAN,   # CONFIRMED
	'text/html'                 => Wx::wxSTC_LEX_HTML,      # CONFIRMED
	'application/javascript'    => Wx::wxSTC_LEX_ESCRIPT,   # CONFIRMED
	'application/json'          => Wx::wxSTC_LEX_ESCRIPT,   # CONFIRMED
	'application/x-latex'       => Wx::wxSTC_LEX_LATEX,     # CONFIRMED
	'application/x-lisp'        => Wx::wxSTC_LEX_LISP,      # CONFIRMED
	'application/x-shellscript' => Wx::wxSTC_LEX_BASH,
	'text/x-lua'                => Wx::wxSTC_LEX_LUA,       # CONFIRMED
	'text/x-makefile'           => Wx::wxSTC_LEX_MAKEFILE,  # CONFIRMED
	'text/x-matlab'             => Wx::wxSTC_LEX_MATLAB,    # CONFIRMED
	'text/x-pascal'             => Wx::wxSTC_LEX_PASCAL,    # CONFIRMED
	'application/x-perl'        => Wx::wxSTC_LEX_PERL,      # CONFIRMED
	'text/x-python'             => Wx::wxSTC_LEX_PYTHON,    # CONFIRMED
	'application/x-php'         => Wx::wxSTC_LEX_PHPSCRIPT, # CONFIRMED
	'application/x-ruby'        => Wx::wxSTC_LEX_RUBY,      # CONFIRMED
	'text/x-sql'                => Wx::wxSTC_LEX_SQL,       # CONFIRMED
	'application/x-tcl'         => Wx::wxSTC_LEX_TCL,       # CONFIRMED
	'text/vbscript'             => Wx::wxSTC_LEX_VBSCRIPT,  # CONFIRMED

	'text/x-config'             => Wx::wxSTC_LEX_CONF,

	# text/xml specifically means "human-readable XML".
	# This is prefered to the more generic application/xml
	'text/xml' => Wx::wxSTC_LEX_XML,                        # CONFIRMED

	'text/x-yaml'         => Wx::wxSTC_LEX_YAML,            # CONFIRMED
	'application/x-pir'   => Wx::wxSTC_LEX_NULL,            # CONFIRMED
	'application/x-pasm'  => Wx::wxSTC_LEX_NULL,            # CONFIRMED
	'application/x-perl6' => Wx::wxSTC_LEX_NULL,            # CONFIRMED
	'text/plain'          => Wx::wxSTC_LEX_NULL,            # CONFIRMED
);
#	'text/x-abc' => Wx::wxSTC_LEX_CONTAINER,
#	'application/x-pir'   => Wx::wxSTC_LEX_CONTAINER,       # CONFIRMED
#	'application/x-pasm'  => Wx::wxSTC_LEX_CONTAINER,       # CONFIRMED
#	'application/x-perl6' => Wx::wxSTC_LEX_CONTAINER,       # CONFIRMED

# TODO: Set some reasonable default highlighers for each mime-type for when there
# are no plugins. e.g. For Perl 6 style files that should be plain text.
# Either allow the plugins to set the defaults (maybe allow the plugin that implements
# the special features of this mime-type to pick the default or shall we have a list of
# prefered default values ?


# TODO fill this hash and use this name in various places where a human readable
# display of file type is needed
# TODO move the whole mime-type and highlighter related code to its own class
my %AVAILABLE_HIGHLIGHTERS;
my %MIME_TYPES;
$MIME_TYPES{'application/x-perl'}{name}  = 'Perl 5';
$MIME_TYPES{'application/x-perl6'}{name} = 'Perl 6';
foreach my $mt (keys %MIME_LEXER) {
	$MIME_TYPES{$mt}{name} = $mt unless $MIME_TYPES{$mt};
}

# TODO include this data in the MIME_TYPES hash
# This is the mime-type to document class mapping
my %MIME_CLASS = (
	'application/x-perl' => 'Padre::Document::Perl',
	'text/x-pod'         => 'Padre::Document::POD',
);
# array ref of objects with value and mime_type fields that have the raw values
__PACKAGE__->read_current_highlighters_from_db();

__PACKAGE__->add_highlighter('stc', 'Scintilla', Wx::gettext('Scintilla, fast but might be out of date'));

foreach my $mime (keys %MIME_LEXER) {
	__PACKAGE__->add_highlighter_to_mime_type($mime, 'stc');
}

# Perl 5 specific highlighters
__PACKAGE__->add_highlighter('Padre::Document::Perl::Lexer', 
	Wx::gettext('PPI Experimental'),
	Wx::gettext('Slow but accurate and we have full control so bugs can be fixed'));
__PACKAGE__->add_highlighter('Padre::Document::Perl::PPILexer', 
	Wx::gettext('PPI Standard'),
	Wx::gettext('Hopefully faster than the PPI Traditional'));

__PACKAGE__->add_highlighter_to_mime_type('application/x-perl', 'Padre::Document::Perl::Lexer');
__PACKAGE__->add_highlighter_to_mime_type('application/x-perl', 'Padre::Document::Perl::PPILexer');



sub add_mime_class {
	my $self  = shift;
	my $mime  = shift;
	my $class = shift;
	if ($MIME_CLASS{$mime}) {
		# TODO: display on the GUI
		warn "Mime type $mime already has a class '$MIME_CLASS{$mime}' when add_mime_class($class) was called\n";
		return;
	}
	$MIME_CLASS{$mime} = $class;
}

sub remove_mime_class {
	my $self  = shift;
	my $mime  = shift;
	if (not $MIME_CLASS{$mime}) {
		# TODO: display on GUI
		warn "Mime type $mime does not have an entry in the MIME_CLASS when remove_mime_class($mime) was called\n";
	}
	delete $MIME_CLASS{$mime};
}

sub add_highlighter {
	my $self        = shift;
	my $module      = shift;
	my $human       = shift;
	my $explanation = shift || '';
	
	$AVAILABLE_HIGHLIGHTERS{$module} = {
			name        => $human,
			explanation => $explanation,
	};
}
sub get_highlighter_explanation {
	my $self = shift;
	my $name = shift;
	my ($highlighter) = grep { $AVAILABLE_HIGHLIGHTERS{$_}{name} eq $name }	keys %AVAILABLE_HIGHLIGHTERS;

	if (not $highlighter) {
		warn "Could not find highlighter for '$name'\n";
		return '';
	}
	return $AVAILABLE_HIGHLIGHTERS{$highlighter}{explanation};
}

sub get_highlighter_name {
	my $self        = shift;
	my $highlighter = shift;
	return $AVAILABLE_HIGHLIGHTERS{$highlighter}{name};
}

# get a hash of mime-type => highlighter
# update the database
sub change_highlighters {
	my ($self, $changed_highlighters) = @_;

	my %mtn = map { $MIME_TYPES{$_}{name} => $_ } keys %MIME_TYPES;
	my %highlighters = map { $AVAILABLE_HIGHLIGHTERS{$_}{name} => $_ } keys %AVAILABLE_HIGHLIGHTERS;

	require Padre::DB::SyntaxHighlight;
	foreach my $mime_type_name (keys %$changed_highlighters) {
		my $mime_type   = $mtn{$mime_type_name}; # get mime_type from name
		my $highlighter = $highlighters{ $changed_highlighters->{$mime_type_name} }; # get highlighter from name
		Padre::DB::SyntaxHighlight->set_mime_type($mime_type, $highlighter);
	}
	
	$self->read_current_highlighters_from_db();
}


sub read_current_highlighters_from_db {
	require Padre::DB::SyntaxHighlight;

	my $current_highlighters = Padre::DB::SyntaxHighlight->select || [];

	# set defaults
	foreach my $mime_type (keys %MIME_TYPES) {
		$MIME_TYPES{ $mime_type }{current_highlighter} = 'stc';
	}

	foreach my $e (@$current_highlighters) {
		$MIME_TYPES{ $e->mime_type }{current_highlighter} = $e->value;
		#printf("%s   %s\n", $e->mime_type, $e->value);
	}
	#use Data::Dumper;
	#print Data::Dumper::Dumper \%MIME_TYPES;
}

# returns hash of mime_type => highlighter
sub get_current_highlighters {
	my %MT;

	foreach my $mime_type (keys %MIME_TYPES) {
		$MT{ $mime_type } = $MIME_TYPES{$mime_type}{current_highlighter};
	}
	return %MT;
}

# returns hash-ref of mime_type_name => highlighter_name
sub get_current_highlighter_names {
	my %MT;

	foreach my $mime_type (keys %MIME_TYPES) {
		$MT{ Padre::Document->get_mime_type_name($mime_type) }
			= Padre::Document->get_highlighter_name( $MIME_TYPES{$mime_type}{current_highlighter} );
	}
	return \%MT;
}

sub get_current_highlighter_of_mime_type {
	my ($self, $mime_type) = @_;
	return $MIME_TYPES{$mime_type}{current_highlighter};
}

sub add_highlighter_to_mime_type {
	my $self   = shift;
	my $mime   = shift;
	my $module = shift; # module name or stc to indicate Scintilla
	# TODO check overwrite, check if it is listed in HIGHLIGHTER_EXPLANATIONS
	$MIME_TYPES{$mime}{highlighters}{$module} = 1;
}
sub remove_highlighter_from_mime_type {
	my $self   = shift;
	my $mime   = shift;
	my $module = shift;
	# TODO check overwrite
	delete $MIME_TYPES{$mime}{highlighters}{$module};
}

# return the mime-types ordered according to their display-name
sub get_mime_types {
	return [ sort { lc $MIME_TYPES{$a}{name} cmp lc $MIME_TYPES{$b}{name} } keys %MIME_TYPES ];
}

# return the display-names of the mime-types ordered according to the display-names
sub get_mime_type_names {
	my $self = shift;
	return [ map { $MIME_TYPES{$_}{name} } @{ $self->get_mime_types } ];
}

# given a mime-type
# return its display-name
sub get_mime_type_name {
	my $self      = shift;
	my $mime_type = shift;
	return $MIME_TYPES{$mime_type}{name};
}	

# given a mime-type 
# return the display-names of the available highlighters
sub get_highlighters_of_mime_type {
	my ($self, $mime_type) = @_;
	my @names = map {__PACKAGE__->get_highlighter_name($_)} sort keys %{ $MIME_TYPES{$mime_type}{highlighters} };
	return \@names;
}

# given the display-name of a mime-type 
# return the display-names of the available highlighters
sub get_highlighters_of_mime_type_name {
	my ($self, $mime_type_name) = @_;
	my ($mime_type) = grep { $MIME_TYPES{$_}{name} eq $mime_type_name } keys %MIME_TYPES;
	if (not $mime_type) {
		warn "Could not find the mime-type of the display name '$mime_type_name'\n";
		return []; # return [] to avoid crash
	}
	$self->get_highlighters_of_mime_type($mime_type);
}


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
		'21Perl 6'      => 'application/x-perl6',
		;
}

#####################################################################
# Constructor and Accessors

use Class::XSAccessor getters => {
	editor           => 'editor',
	filename         => 'filename',    # TODO is this read_only or what?
	get_mimetype     => 'mimetype',
	get_newline_type => 'newline_type',
	errstr           => 'errstr',
	tempfile         => 'tempfile',
	get_highlighter  => 'highlighter',
	},
	setters => {
	_set_filename    => 'filename',    # TODO temporary hack
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
	my $mime_type = $self->get_mimetype;
	my $class = $MIME_CLASS{ $mime_type} || __PACKAGE__;
	Padre::Util::debug("Reblessing to mimetype: '$class'");
	if ($class) {
		unless ( $class->VERSION ) {
			eval "require $class;";
			die("Failed to load $class: $@") if $@;
		}
		bless $self, $class;
	}

	my $module = __PACKAGE__->get_current_highlighter_of_mime_type($mime_type);
	my $filename = $self->filename || '';
	warn("No module  mime_type='$mime_type' filename='$filename'\n") if not $module;
	#warn("Module '$module' mime_type='$mime_type' filename='$filename'\n") if $module;
	$self->set_highlighter($module);

	return;
}

#####################################################################
# Padre::Document GUI Integration

sub colorize {
	my $self = shift;

	Padre::Util::debug("colorize called");

	my $module = $self->get_highlighter;
	if ($module eq 'stc') {
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
	if (not $module->can('colorize')) {
		eval "use $module";
		if ($@) {
			Carp::cluck("Could not load module '$module' for file '" . ($self->filename || '') . "'\n");
			return;
		}
	}
	if ($module->can('colorize')) {
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
	my $filename = $_[0]->filename;
	defined($filename) ? File::Basename::basename($filename) : undef;
}

sub dirname {
	my $filename = $_[0]->filename;
	defined($filename) ? File::Basename::dirname($filename) : undef;
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

	# Try derive the mime type from the file extension
	if ( $filename and $filename =~ /\.([^.]+)$/ ) {
		my $ext = lc $1;
		if ( $EXT_MIME{$ext} ) {
			if ( ref $EXT_MIME{$ext} ) {
				return $EXT_MIME{$ext}->();
			} else {
				return $EXT_MIME{$ext};
			}
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
	if ( $text and $text =~ /\A#!/m ) {

		# Found a hash bang line
		if ( $text =~ /\A#![^\n]*\bperl6?\b/m ) {
			return $self->perl_mime_type;
		}
		if ( $text =~ /\A---/ ) {
			return 'text/x-yaml';
		}
	}

	# Fall back to plain text file
	return 'text/plain'
}

sub perl_mime_type {
	my $self = shift;

	my $text = $self->{original_content};

	# Sometimes Perl 6 will look like Perl 5
	# But only do this test if the Perl 6 plugin is enabled.
	if ( $MIME_CLASS{'application/x-perl6'} and is_perl6($text) ) {
		return 'application/x-perl6';
	} else {
		return 'application/x-perl';
	}
}

sub mime_type_by_extension {
	$EXT_MIME{ $_[1] };
}

# For ts without a newline type
# TODO: get it from config
sub _get_default_newline_type {
	Padre::Constant::NEWLINE;
}

# naive sub to decide if a piece of code is Perl 6 or Perl 5.
# Perl 6:   use v6; class ..., module ...
# maybe also grammar ...
# but make sure that is real code and not just a comment or doc in some perl 5 code...
sub is_perl6 {
	my ($text) = @_;
	return if not $text;
	return 1 if $text =~ /^=begin\s+pod/msx;

	# Needed for eg/perl5_with_perl6_example.pod
	return if $text =~ /^=head[12]/msx;

	return 1 if $text =~ /^\s*use\s+v6;/msx;
	return 1 if $text =~ /^\s*(?:class|grammar|module|role)\s+\w/msx;

	return;
}

# Where to convert (UNIX, WIN, MAC)
# or Ask (the user) or Keep (the garbage)
# mixed files
# TODO get from config
sub _mixed_newlines {
	Padre::Constant::NEWLINE;
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
	return 0 unless defined $self->filename;
	return 0 unless defined $self->last_sync;
	return 1 unless $self->time_on_file;
	return $self->last_sync < $self->time_on_file ? 1 : 0;
}

sub time_on_file {
	my $filename = $_[0]->filename;
	return 0 unless defined $filename;
	return 0 unless -e $filename;
	return ( stat($filename) )[9];
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

	Padre::Util::debug("Loading file '$file'");

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
	} else {
		$self->set_errstr($!);
		return;
	}
	$self->{_timestamp} = $self->time_on_file;

	# if guess encoding fails then use 'utf-8'
	require Padre::Locale;
	$self->{encoding} = Padre::Locale::encoding_from_string($content);

	#warn $self->{encoding};
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
	} elsif ( $current_type eq 'Mixed' ) {
		my $mixed = $self->_mixed_newlines();
		if ( $mixed eq 'Ask' ) {
			warn "TODO ask the user what to do with $file";

			# $convert_to = $newline_type = ;
		} elsif ( $mixed eq 'Keep' ) {
			warn "TODO probably we should not allow keeping garbage ($file) \n";
		} else {

			#warn "TODO converting $file";
			$convert_to = $newline_type = $mixed;
		}
	} else {
		$convert_to = $self->_auto_convert;
		if ($convert_to) {

			#warn "TODO call converting on $file";
			$newline_type = $convert_to;
		} else {
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
	# allow the upgrade from ascii to utf-8 if there were unicode characters added
	require Padre::Locale;
	if ( not $self->{encoding} or $self->{encoding} eq 'ascii' ) {
		$self->{encoding} = Padre::Locale::encoding_from_string($content);
	}

	my $encode = '';
	if ( defined $self->{encoding} ) {
		$encode = ":raw:encoding($self->{encoding})";
	} else {
		warn "encoding is not set, (couldn't get from contents) when saving file $filename\n";
	}

	if ( open my $fh, ">$encode", $filename ) {
		print {$fh} $content;
	} else {
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
	
	# this should never happen as now we set mime-type on everything
	return Wx::wxSTC_LEX_AUTOMATIC unless $self->get_mimetype;

	my $highlighter = $self->get_highlighter;
	if (not $highlighter) {
		warn "no highlighter\n";
		$highlighter = 'stc';
	}
	return Wx::wxSTC_LEX_CONTAINER if $highlighter ne 'stc';
	return Wx::wxSTC_LEX_AUTOMATIC unless defined $MIME_LEXER{ $self->get_mimetype };

	Padre::Util::debug( 'STC Lexer will be based on mime type "' . $self->get_mimetype . '"' );
	return $MIME_LEXER{ $self->get_mimetype };
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

package Padre::MIME;

=pod

=head1 NAME

Padre::MIME - Padre MIME Registry and Type Detection

=head1 DESCRIPTION

B<Padre::MIME> is a light weight module for detecting the MIME type of files
and the type registry acts as the basis for all other type-specific
functionality in Padre.

Because of the light weight it can be quickly and safely loaded in any
background tasks that need to walk directories and act on files based on
their file type.

The class itself consists of two main elements, a type registry and a type
detection mechanism.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Locale::T;

our $VERSION    = '1.00';
our $COMPATIBLE = '0.95';

# The MIME object store
my %MIME = ();

# The "Unknown" MIME type
my $UNKNOWN = Padre::MIME->new(
	type => '',
	name => _T('UNKNOWN'),
);

# File extension to MIME type mapping
my %EXT = (
	abc   => 'text/x-abc',
	ada   => 'text/x-adasrc',
	asc   => 'text/plain',
	asm   => 'text/x-asm',
	bat   => 'text/x-bat',
	cmd   => 'text/x-bat',
	bib   => 'application/x-bibtex',
	bin   => 'application/octet-stream',
	bml   => 'application/x-bml',        # Livejournal templates
	c     => 'text/x-csrc',
	h     => 'text/x-csrc',
	cc    => 'text/x-c++src',
	cpp   => 'text/x-c++src',
	cxx   => 'text/x-c++src',
	cob   => 'text/x-cobol',
	cbl   => 'text/x-cobol',
	csv   => 'text/csv',
	'c++' => 'text/x-c++src',
	hh    => 'text/x-c++src',
	hpp   => 'text/x-c++src',
	hxx   => 'text/x-c++src',
	'h++' => 'text/x-c++src',
	cs    => 'text/x-csharp',
	css   => 'text/css',
	diff  => 'text/x-patch',
	e     => 'text/x-eiffel',
	exe   => 'application/octet-stream',
	f     => 'text/x-fortran',
	htm   => 'text/html',
	html  => 'text/html',
	hs    => 'text/x-haskell',
	i     => 'text/x-csrc',              # Non-preprocessed C
	ii    => 'text/x-c++src',            # Non-preprocessed C
	java  => 'text/x-java',
	js    => 'application/javascript',
	json  => 'application/json',
	lsp   => 'application/x-lisp',
	lua   => 'text/x-lua',
	m     => 'text/x-matlab',
	mak   => 'text/x-makefile',
	pdf   => 'application/pdf',
	pod   => 'text/x-pod',
	py    => 'text/x-python',
	r     => 'text/x-r',
	rb    => 'application/x-ruby',
	rtf   => 'text/rtf',
	sgm   => 'text/sgml',
	sgml  => 'text/sgml',
	sql   => 'text/x-sql',
	tcl   => 'application/x-tcl',
	patch => 'text/x-patch',
	pks   => 'text/x-sql',               # PLSQL package spec
	pkb   => 'text/x-sql',               # PLSQL package body
	pl    => 'application/x-perl',
	plx   => 'application/x-perl',
	pm    => 'application/x-perl',
	pmc   => 'application/x-perl',       # Compiled Perl or gimme5
	pod   => 'text/x-pod',
	pov   => 'text/x-povray',
	psgi  => 'application/x-psgi',
	sty   => 'application/x-latex',
	t     => 'application/x-perl',
	tex   => 'application/x-latex',
	xs    => 'text/x-perlxs',            # Define our own MIME type
	tt    => 'text/x-perltt',            # Define our own MIME type
	tt2   => 'text/x-perltt',            # Define our own MIME type
	conf  => 'text/x-config',
	sh    => 'application/x-shellscript',
	ksh   => 'application/x-shellscript',
	txt   => 'text/plain',
	text  => 'text/plain',
	xml   => 'text/xml',
	yml   => 'text/x-yaml',
	yaml  => 'text/x-yaml',
	'4th' => 'text/x-forth',
	zip   => 'application/zip',
	pasm  => 'application/x-pasm',
	pir   => 'application/x-pir',
	p6    => 'application/x-perl6',      # See Perl6/Spec/S01-overview.pod
	p6l   => 'application/x-perl6',
	p6m   => 'application/x-perl6',
	pl6   => 'application/x-perl6',
	pm6   => 'application/x-perl6',
	pas   => 'text/x-pascal',
	dpr   => 'text/x-pascal',
	dfm   => 'text/x-pascal',
	inc   => 'text/x-pascal',
	pp    => 'text/x-pascal',
	as    => 'text/x-actionscript',
	asc   => 'text/x-actionscript',
	jsfl  => 'text/x-actionscript',
	php   => 'application/x-php',
	php3  => 'application/x-php',
	php4  => 'application/x-php',
	php5  => 'application/x-php',
	phtm  => 'application/x-php',
	phtml => 'application/x-php',
	vb    => 'text/vbscript',
	bas   => 'text/vbscript',
	frm   => 'text/vbscript',
	cls   => 'text/vbscript',
	ctl   => 'text/vbscript',
	pag   => 'text/vbscript',
	dsr   => 'text/vbscript',
	dob   => 'text/vbscript',
	vbs   => 'text/vbscript',
	dsm   => 'text/vbscript',
);





######################################################################
# MIME Registry Methods

=pod

=head2 exts

  my @extensions = Padre::MIME->exts;

The C<exts> method returns the list of all known file extensions.

=cut

sub exts {
	keys %EXT;
}

=pod

=head2 types

  my @registered = Padre::MIME->types;

The C<types> method returns the list of all registered MIME types.

=cut

sub types {
	keys %MIME;
}

=pod

=head2 find

  my $mime = Padre::MIME->find('text/plain');

The C<find> method takes a MIME type string and returns a L<Padre::MIME>
object for that string. If the MIME type is not registered, then the
unknown type object will be returned.

=cut

sub find {
	$MIME{ $_[1] } || $UNKNOWN;
}





######################################################################
# MIME Objects

=pod

=head2 new

  my $mime = Padre::MIME->new(
      type      => 'text/x-csrc',
      name      => _T('C'),
      supertype => 'text/plain',
  );

The C<new> constructor creates a new anonymous MIME type object which
is not registered with the MIME type system.

It takes three parameters, C<type> which should be the string identifying
the MIME type, C<name> which should be the (localisable) English name for
the language, and C<supertype> which should be the parent type that the
new type inherits from.

While not compulsory, all MIME types generally inherit from other languages
with three main types at the top of the inheritance tree.

=over 4

=item *

C<text/plain> for human-readable text files including pretty-printed XML

=item *

C<application/xml> for tightly packed XML files not intended to opened

=item *

C<application/octet-stream> for binary files (that cannot be opened)

=back

At the time of creation, new MIME type objects (even anonymous ones) must
inherit from a registered MIME type if the C<supertype> param is provided.

Returns a L<Padre::MIME> object, or throws an exception on error.

=cut

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# Check the supertype and precalculate the supertype path
	unless ( defined $self->{type} ) {
		die "Missing or invalid MIME type";
	}
	if ( $self->{supertype} ) {
		unless ( $MIME{ $self->{supertype} } ) {
			die "MIME type '$self->{supertype}' does not exist";
		}
		$self->{superpath} = [
			$self->{type},
			$MIME{ $self->{supertype} }->superpath,
		];
	} else {
		$self->{superpath} = [ $self->{type} ];
	}

	return $self;
}

=pod

=head2 create

 Padre::MIME->create(
      type      => 'application/x-shellscript',
      name      => _T('Shell Script'),
      supertype => 'text/plain',
  );

The C<create> method creates and registers a new MIME type for use in
L<Padre>. It will not in and of itself add support for that file type,
but registration of the MIME type is the first step, and a prerequisite of,
supporting that file type anywhere else in Padre.

Returns the new L<Padre::MIME> object as a convenience, or throws an
exception on error.

=cut

sub create {
	my $class = shift;
	my $self  = $class->new(@_);
	$MIME{ $self->type } = $self;
}

=pod

=head2 type

  print Padre::MIME->find('text/plain')->type;

The C<type> accessor returns the type string for the MIME type, for example
the above would print C<text/plain>.

=cut

sub type {
	$_[0]->{type};
}

=pod

=head2 name

  print Padre::MIME->find('text/plain')->name;

The C<name> accessor returns the (localisable) English name of the MIME
type. For example, the above would print C<"Text">.

=cut

sub name {
	$_[0]->{name};
}

=pod

=head2 super

  # Find the root type for a mime type
  my $mime = Padre::MIME->find('text/x-actionscript');
  $mime = $mime->super while $mime->super;

The C<super> method returns the L<Padre::MIME> object for the immediate
supertype of a particular MIME type, or false if there is no supertype.

=cut

sub super {
	$MIME{ $_[0]->{supertype} || '' };
}

=pod

=head2 supertype

  # Find the root type for a mime type
  my $mime = Padre::MIME->find('text/x-actionscript');
  $mime = $mime->super while defined $mime->supertype;

The C<supertype> method returns the string form of the immediate supertype
for a particular MIME type, or C<undef> if there is no supertype.

=cut

sub supertype {
	$_[0]->{supertype};
}

=pod

=head2 superpath

  # Find the comment format for a type
  my $mime    = Padre::MIME->find('text/x-actionscript');
  my $comment = undef;
  foreach my $type ( $mime->superpath ) {
      $comment = Padre::Comment->find($type) and last;
  }

The C<superpath> method returns a list of MIME type strings of the entire
inheritance path for a particular MIME type, including itself.

This can allow inherited types to gain default access to various resources
such as the comment type or syntax highlighting of the supertypes without
needing to be implemented seperately, if they are no different from their
supertype in some respect.

=cut

sub superpath {
	@{ $_[0]->{superpath} };
}

=pod

=head2 document

  my $module = Padre::MIME->find('text/x-perl')->document;

The C<document> method attempts to resolve an implementation class for this
MIME type, either from the Padre core or from a plugin. For example, the
above would return C<'Padre::Document::Perl'>.

Returns the class name as a string, or C<undef> if no implementation class
can be resolved.

=cut

sub document {
	my $self = shift;
	my $mime = $self;

	do {
		return $mime->{plugin}   if $mime->{plugin};
		return $mime->{document} if $mime->{document};
	} while ( $mime = $mime->super );

	# die "Failed to find a document class for '" . $self->type . "'";
	return undef;
}

=pod

=head2 binary

  if ( Padre::MIME->find('application/octet-stream')->binary ) {
      die "Padre does not support binary files";
  }

The C<binary> method is a convenience for determining if a MIME type is a
type of non-text file that Padre does not support opening.

Returns true if the MIME type is binary or false if not.

=cut

sub binary {
	!!grep { $_ eq 'application/octet-stream' } $_[0]->superpath;
}

=pod

=head2 plugin

  # Overload the default Python support
  my $python = Padre::MIME->find('text/x-python');
  $python->plugin('Padre::Plugin::Python::Document');

The C<plugin> method is used to overload support for a MIME type and cause
it to be loaded by an arbitrary class. This method should generally not be
used directly, it is intended for internal use by L<Padre::PluginManager>
and does not do any form of testing or management of the classes passed in.

=cut

sub plugin {
	$_[0]->{plugin} = $_[1];
}

=pod

=head2 reset

  # Remove the overloaded Python support
  Padre::MIME->find('text/x-python')->reset;

The C<reset> method is used to remove the overloading of a MIME type by a
plugin and return to default support. This method should generally not be
used directly, it is intended for internal use by L<Padre::PluginManager>
and does not do any form of testing or management.

=cut

sub reset {
	delete $_[0]->{plugin};
}

=pod

=head2 comment

  my $comment = Padre::MIME->find('text/x-perl')->comment;

The C<comment> method fetches the comment rules for the mime type from
the L<Padre::Comment> subsystem of L<Padre>.

Returns the basic comment as a string, or C<undef> if no comment rule is
known for the MIME type.

=cut

sub comment {
	require Padre::Comment;
	$_[0]->{comment}
		or $_[0]->{comment} = Padre::Comment->find( $_[0] );
}





#####################################################################
# MIME Type Detection

=pod

=head2 detect

  my $type = Padre::MIME->detect(
      file => 'path/file.pm',
      text => "#!/usr/bin/perl\n\n",
      svn  => 1,
  );

The C<detect> method implements MIME detection using a variety of different
methods. It takes up to three different params, which it will use in the
order it considers most efficient and reliable.

The optional parameter C<file> param can either be a L<Padre::File> object,
or the path of the file in string form.

The optional string parameter C<text> should be all or part of the content
of the file as a plain string.

The optional boolean parameter C<svn> indicates whether or not the detection
code should look for a C<svn:mime-type> property in the C<.svn> metadata
directory for the file.

Returns a MIME type string for a registered MIME type if a reasonable guess
can be made, or the null string C<''> if the detection code cannot determine
the MIME type of the file/content.

=cut

sub detect {
	my $class = shift;
	my %param = @_;

	# Could be a Padre::File object with an identified mime type
	my $file = $param{file};
	if ( ref $file ) {

		# The mime might already be identified
		my $mime = $file->mime;
		return $mime if defined $mime;

		# Not identified, just use the actual file name
		$file = $file->filename;
	}

	# Use SVN metadata if we are allowed to
	my $mime = '';
	if ( $param{svn} and $file ) {
		require Padre::SVN;
		$mime = Padre::SVN::file_mimetype($file) || '';
	}

	# Try derive the mime type from the file extension
	if ( not $mime and $file ) {
		if ( $file =~ /\.([^.]+)$/ ) {
			my $ext = lc $1;
			$mime = $EXT{$ext} if $EXT{$ext};

		} else {

			# Try to derive the mime type from the basename
			# Makefile is now highlighted as a Makefile
			# Changelog files are now displayed as text files
			require File::Basename;
			my $basename = File::Basename::basename($file);
			if ($basename) {
				$mime = 'text/x-makefile' if $basename =~ /^Makefile\.?/i;
				$mime = 'text/plain'      if $basename =~ /^(changes|changelog)/i;
			}
		}
	}

	# Fall back on deriving the type from the content.
	# Hardcode this for now for the cases that we care about and
	# are obvious.
	my $text = $param{text};
	if ( not $mime and defined $text ) {
		$mime = eval { $class->detect_content($text) };
		return '' if $@;
	}

	# Fallback mime-type of new files, should be configurable in the GUI
	# TO DO: Make it configurable in the GUI :)
	if ( not $mime and not defined $file ) {
		$mime = 'application/x-perl';
	}

	# Finally fall back to plain text file
	unless ( $mime and length $mime ) {
		$mime = 'text/plain';
	}

	# If we found Perl 5 we might need to second-guess it and check
	# for it actually being Perl 6.
	if ( $mime eq 'application/x-perl' and $param{perl6} ) {
		if ( $class->detect_perl6($text) ) {
			$mime = 'application/x-perl6';
		}
	}

	return $mime;
}

=pod

=head2 detect_svn

  my $type = Padre::MIME->detect_svn($path);

The C<detect_svn> method takes the path to a file as a string, and attempts
to determine a MIME type for the file based on the file's Subversion
C<svn:eol-style> property.

Returns a MIME type string which may or may not be registered with L<Padre>
or the null string C<''> if the property does not exist (or it is not stored
in Subversion).

=cut

sub detect_svn {
	my $class = shift;
	my $file  = shift;
	my $mime  = undef;
	local $@;
	eval {
		require Padre::SVN;
		$mime = Padre::SVN::file_mimetype($file);
	};
	return $mime || '';
}

=pod

=head2 detect_content

The C<detect_content> method takes a string parameter containing the content
of a file (or head-anchored partial content of a file) and attempts to
heuristically determine the the type of the file based only on the content.

Returns a MIME type string for a registered MIME type if a reasonable guess
can be made, or the null string C<''> if the detection code cannot determine
the file type of the content.

=cut

sub detect_content {
	my $class = shift;
	my $text  = shift;

	# Working on content with malformed/bad UTF-8 chars may drop warnings
	# which just say that there are bad UTF-8 chars in the file currently
	# being checked. Maybe they are no UTF-8 chars at all but just a line
	# of bits and Padre/Perl simply has the wrong point of view (UTF-8),
	# so we drop these warnings:
	local $SIG{__WARN__} = sub {

		# Die if we throw a bad codepoint - this is a binary file.
		if ( $_[0] =~ /Code point .* is not Unicode/ ) {
			die $_[0];
		} elsif ( $_[0] !~ /Malformed UTF\-8 char/ ) {
			return;

			# print STDERR "$_[0] while looking for mime type of $file";
		}
	};

	# Is this a script of some kind?
	if ( $text =~ /\A#!.*\bperl6?\b/m ) {
		return 'application/x-perl';
	}
	if ( $text =~ /\A#!.*\bsh\b.*(?:\n.*)?\nexec wish/m ) {
		return 'application/x-tcl';
	}
	if ( $text =~ /\A#!.*\bwish\b/m ) {
		return 'application/x-tcl';
	}
	if ( $text =~ /\A#!.*\b(?:z|k|ba|t?c|da)?sh\b/m ) {
		return 'application/x-shellscript';
	}
	if ( $text =~ /\A#!.*\bpython\b/m ) {
		return 'text/x-python';
	}
	if ( $text =~ /\A#!.*\bruby\b/m ) {
		return 'application/x-ruby';
	}

	# YAML will start with a ---
	if ( $text =~ /\A---/ ) {
		return 'text/x-yaml';
	}

	# Rich Text Format
	if ( $text =~ /^\{\\rtf/ ) {
		return 'text/rtf';
	}

	# Try to identify Perl Scripts based on soft criterias as a last resort
	# TO DO: Improve the tests
	SCOPE: {
		my $score = 0;
		if ( $text =~ /^package\s+[\w:]+;/ ) {
			$score += 2;
		}
		if ( $text =~ /\b(use \w+(\:\:\w+)*.+?\;[\r\n][\r\n.]*){3,}/ ) {
			$score += 2;
		}
		if ( $text =~ /\buse \w+(\:\:\w+)*.+?\;/ ) {
			$score += 1;
		}
		if ( $text =~ /\brequire ([\"\'])[a-zA-Z0-9\.\-\_]+\1\;[\r\n]/ ) {
			$score += 1;
		}
		if ( $text =~ /[\r\n]sub \w+ ?(\(\$*\))? ?\{([\s\t]+\#.+)?[\r\n]/ ) {
			$score += 1;
		}
		if ( $text =~ /\=\~ ?[sm]?\// ) {
			$score += 1;
		}
		if ( $text =~ /\bmy [\$\%\@]/ ) {
			$score += 0.5;
		}
		if ( $text =~ /\bmy \$self\b/ ) {
			$score += 1;
		}
		if ( $text =~ /\bforeach\s+my\s+\$\w+/ ) {
			$score += 1;
		}
		if ( $text =~ /\bour \$VERSION\b/ ) {
			$score += 1;
		}
		if ( $text =~ /1\;[\r\n]+$/ ) {
			$score += 0.5;
		}
		if ( $text =~ /\$\w+\{/ ) {
			$score += 0.5;
		}
		if ( $text =~ /\bsplit[ \(]\// ) {
			$score += 0.5;
		}
		if ( $score >= 2 ) {
			return 'application/x-perl';
		}
	}

	# Look for Template::Toolkit syntax
	#  - traditional syntax:
	my $TT = qr/(?:PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b/;
	if ( $text =~ /\[\%[\+\-\=\~]? $TT\b .* [\+\-\=\~]?\%\]/ ) {
		return 'text/x-perltt';
	}

	#  - default alternate styles (match 2 tags)
	if ( $text =~ /(\%\%[\+\-\=\~]? $TT .* [\+\-\=\~]?\%\%.*){2}/s ) {
		return 'text/x-perltt';
	}
	if ( $text =~ /(\[\*[\+\-\=\~]? $TT .* [\+\-\=\~]?\*\].*){2}/s ) {
		return 'text/x-perltt';
	}

	#  - other languages defaults (match 3 tags)
	if ( $text =~ /(\<([\?\%])[\+\-\=\~]? $TT .* [\+\-\=\~]?\1\>.*){3}/s ) {
		return 'text/x-perltt';
	}
	if ( $text =~ /(\<\%[\+\-\=\~]? $TT .* [\+\-\=\~]?\>.*){3}/s ) {
		return 'text/x-perltt';
	}
	if ( $text =~ /(\<\!\-\-[\+\-\=\~]? $TT .* [\+\-\=\~]?\-\-\>.*){3}/s ) {
		return 'text/x-perltt';
	}

	#  - traditional, but lowercase syntax (3 tags)
	if ( $text =~ /(\[\%[\+\-\=\~]? $TT .* [\+\-\=\~]?\%\].*){3}/si ) {
		return 'text/x-perltt';
	}

	# Recognise XML and variants
	if ( $text =~ /\A<\?xml\b/s ) {

		# Detect XML formats without XML namespace declarations
		return 'text/html'           if $text =~ /^<!DOCTYPE html/m;
		return 'xml/x-wxformbuilder' if $text =~ /<wxFormBuilder_Project>/;

		# Fall through to generic XML
		return 'text/xml';
	}

	# Look for HTML (now we can be relatively confident it's not HTML inside Perl)
	if ( $text =~ /\<\/(?:html|body|div|p|table)\>/ ) {

		# Is it Template Toolkit HTML?
		# Only try to text the default [% %]
		if ( $text =~ /\[\%\-?\s+\w+(?:\.\w+)*\s+\-?\%\]/ ) {
			return 'text/x-perltt';
		}

		return 'text/html';
	}

	# Try to detect plain CSS without HTML around it
	if ( $text !~ /\<\w+\/?\>/ ) {
		if ( $text =~ /^([\.\#]?\w+( [\.\#]?\w+)*)(\,[\s\t\r\n]*([\.\#]?\w+( [\.\#]?\w+)*))*[\s\t\r\n]*\{/ ) {
			return 'text/css';
		}
	}

	# LUA detection
	SCOPE: {
		my $lua_score = 0;
		for ( 'end', 'it', 'in', 'nil', 'repeat', '...', '~=' ) {
			$lua_score += 1.1 if $text =~ /[\s\t]$_[\s\t]/;
		}
		$lua_score += 2.01
			if $text =~ /^[\s\t]?function[\s\t]+\w+[\s\t]*\([\w\,]*\)[\s\t\r\n]+[^\{]/;
		$lua_score -= 5.02 if $text =~ /[\{\}]/; # Not used in lua
		$lua_score += 3.04 if $text =~ /\-\-\[.+?\]\]\-\-/s; # Comment
		return 'text/x-lua' if $lua_score >= 5;
	}

	return '';
}

=pod

=head2 detect_perl6

  my $is_perl6 = Padre::MIME->detect_perl6($content);

The C<detect_perl6> is a special case method used to distinguish between
Perl 5 and Perl 6, as the two types often share the same file extension.

Returns true if the content appears to be Perl 6, or false if the content
appears to be Perl 5.

=cut

sub detect_perl6 {
	my $class = shift;
	my $text  = shift;

	# Empty/undef text is not Perl 6 :)
	return 0 unless $text;

	# Perl 6 POD
	return 1 if $text =~ /^=begin\s+pod/msx;

	# Needed for eg/perl5_with_perl6_example.pod
	return 0 if $text =~ /^=head[12]/msx;

	# =cut is a sure sign for Perl 5 code (moritz++)
	return 0 if $text =~ /^=cut/msx;

	# Special case: If MooseX::Declare is there, then we're in Perl 5 land
	return 0 if $text =~ /^\s*use\s+MooseX::Declare/msx;

	# Perl 6 'use v6;'
	return 1 if $text =~ /^\s*use\s+v6;/msx;

	# One of Perl 6 compilation units
	return 1 if $text =~ /^\s*(?:class|grammar|module|role)\s+\w/msx;

	# Not Perl 6 for sure...
	return 0;
}





######################################################################
# MIME Declarations

# Plain text, which editable files inherit from
Padre::MIME->create(
	type     => 'text/plain',
	name     => _T('Text'),
	document => 'Padre::Document',
);

# Binary files, which we cannot open at all
Padre::MIME->create(
	type => 'application/octet-stream',
	name => _T('Binary File'),
);

Padre::MIME->create(
	type      => 'text/x-abc',
	name      => 'ABC',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-actionscript',
	name      => 'ActionScript',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-adasrc',
	name      => 'Ada',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-asm',
	name      => 'Assembly',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-bat',
	name      => 'Batch',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-bibtex',
	name      => 'BibTeX',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-bml',
	name      => 'BML',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-csrc',
	name      => 'C',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-cobol',
	name      => 'COBOL',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/csv',
	name      => 'CSV',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-c++src',
	name      => 'C++',
	supertype => 'text/x-csrc',
);

Padre::MIME->create(
	type      => 'text/css',
	name      => 'CSS',
	supertype => 'text/x-csrc',
);

Padre::MIME->create(
	type      => 'text/x-eiffel',
	name      => 'Eiffel',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-forth',
	name      => 'Forth',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-fortran',
	name      => 'Fortran',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-haskell',
	name      => 'Haskell',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/sgml',
	name      => 'SGML',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/html',
	name      => 'HTML',
	supertype => 'text/sgml',
);

Padre::MIME->create(
	type      => 'application/javascript',
	name      => 'JavaScript',
	supertype => 'text/x-csrc',
);

Padre::MIME->create(
	type      => 'application/json',
	name      => 'JSON',
	supertype => 'application/javascript',
);

Padre::MIME->create(
	type      => 'application/x-latex',
	name      => 'LaTeX',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-lisp',
	name      => 'LISP',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-patch',
	name      => 'Patch',
	supertype => 'text/plain',
	document  => 'Padre::Document::Patch',
);

Padre::MIME->create(
	type      => 'application/pdf',
	name      => 'PDF',
	supertype => 'application/octet-stream',
);

Padre::MIME->create(
	type      => 'application/x-shellscript',
	name      => _T('Shell Script'),
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-java',
	name      => 'Java',
	supertype => 'text/x-csrc',
	document  => 'Padre::Document::Java',
);

Padre::MIME->create(
	type      => 'text/x-lua',
	name      => 'Lua',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-makefile',
	name      => 'Makefile',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-matlab',
	name      => 'Matlab',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-pascal',
	name      => 'Pascal',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-perl',
	name      => 'Perl 5',
	supertype => 'text/plain',
	document  => 'Padre::Document::Perl',
);

Padre::MIME->create(
	type      => 'text/x-povray',
	name      => 'POVRAY',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-psgi',
	name      => 'PSGI',
	supertype => 'application/x-perl',
);

Padre::MIME->create(
	type      => 'text/x-python',
	name      => 'Python',
	supertype => 'text/plain',
	document  => 'Padre::Document::Python',
);

Padre::MIME->create(
	type      => 'application/x-php',
	name      => 'PHP',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-r',
	name      => 'R',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/rtf',
	name      => 'RTF',
	supertype => 'text/plain',

	# magic     => "{\\rtf",
);

Padre::MIME->create(
	type      => 'application/x-ruby',
	name      => 'Ruby',
	supertype => 'text/plain',
	document  => 'Padre::Document::Ruby',
);

Padre::MIME->create(
	type      => 'text/x-sql',
	name      => 'SQL',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-tcl',
	name      => 'Tcl',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/vbscript',
	name      => 'VBScript',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-config',
	name      => 'Config',
	supertype => 'text/plain',
);

# text/xml specifically means "human-readable XML".
# This is preferred to the more generic application/xml
Padre::MIME->create(
	type     => 'text/xml',
	name     => 'XML',
	document => 'Padre::Document',
);

Padre::MIME->create(
	type      => 'text/x-yaml',
	name      => 'YAML',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-pir',
	name      => 'PIR',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-pasm',
	name      => 'PASM',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'application/x-perl6',
	name      => 'Perl 6',
	supertype => 'text/plain',
);

# Completely custom mime types
Padre::MIME->create(
	type      => 'text/x-perlxs', # totally not confirmed
	name      => 'XS',
	supertype => 'text/x-csrc',
);

Padre::MIME->create(
	type      => 'text/x-perltt',
	name      => 'Template Toolkit',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'text/x-csharp',
	name      => 'C#',
	supertype => 'text/x-csrc',
	document  => 'Padre::Document::CSharp',
);

Padre::MIME->create(
	type      => 'text/x-pod',
	name      => 'POD',
	supertype => 'text/plain',
);

Padre::MIME->create(
	type      => 'xml/x-wxformbuilder',
	name      => 'wxFormBuilder',
	supertype => 'text/xml',
);

Padre::MIME->create(
	type      => 'application/zip',
	name      => _T('ZIP Archive'),
	supertype => 'application/octet-stream',
);

1;

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2013 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

package Padre::MimeTypes;

=pod

=head1 NAME

Padre::MimeTypes - Padre Mime-types

=head1 DESCRIPTION

See L<Padre::Document>

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp           ();
use File::Basename ();
use Padre::Config  ();
use Padre::Current ();
use Padre::Util    ('_T');
use Padre::Wx      ();
use Padre::DB      ();

our $VERSION = '0.90';

# Binary file extensions, which we don't support loading at all
my %EXT_BINARY = ();

# Text file extension to MIME type mapping (either string or code reference)
my %EXT_MIME = ();

# The list of available syntax highlighting modules
my %HIGHLIGHTER = ();

# Highlighters preferences defined in Padre's configuration system
my %HIGHLIGHTER_CONFIG = ();

# Main MIME type database and settings.
# NOTE: This has gotten complex enough it probably needs to be a HASH
#       of objects now.
my %MIME = ();

# Default document classes
my %DEFAULT_DOC_CLASS = ();

#####################################################################
# Document Registration

_initialize();

sub _initialize {
	return if %EXT_BINARY; # call it only once

	%EXT_BINARY = map { $_ => 1 } qw{
		aiff  au    avi  bmp  cache  dat   doc  docx gif  gz   icns
		jar   jpeg  jpg  m4a  mov    mp3   mpg  ogg  pdf  png
		pnt   ppt   qt   ra   svg    svgz  svn  swf  tar  tgz
		tif   tiff  wav  xls  xlw    xlsx  zip
	};

	# This is the primary file extension to mime-type mapping
	%EXT_MIME = (
		abc   => 'text/x-abc',
		ada   => 'text/x-adasrc',
		asm   => 'text/x-asm',
		bat   => 'text/x-bat',
		bib   => 'application/x-bibtex',
		bml   => 'application/x-bml',     # dreamwidth file format
		c     => 'text/x-c',
		h     => 'text/x-c',
		cc    => 'text/x-c++src',
		cpp   => 'text/x-c++src',
		cxx   => 'text/x-c++src',
		'c++' => 'text/x-c++src',
		hh    => 'text/x-c++src',
		hpp   => 'text/x-c++src',
		hxx   => 'text/x-c++src',
		'h++' => 'text/x-c++src',
		cs    => 'text/x-csharp',
		css   => 'text/css',
		diff  => 'text/x-patch',
		e     => 'text/x-eiffel',
		f     => 'text/x-fortran',
		htm   => 'text/html',
		html  => 'text/html',
		i     => 'text/x-c',              # C code that should not be preprocessed
		ii    => 'text/x-c++src',         # C++ code that should not be preprocessed
		java  => 'text/x-java-source',
		js    => 'application/javascript',
		json  => 'application/json',
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
		pmc   => \&perl_mime_type,        # Compiled Perl Module or gimme5's output
		pod   => \&pod_mime_type,
		psgi  => 'application/x-psgi',
		sty   => 'application/x-latex',
		t     => \&perl_mime_type,
		tex   => 'application/x-latex',

		# Lacking a better solution, define our own MIME
		xs => 'text/x-perlxs',
		tt => 'text/x-perltt',

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

		# See docs/Perl6/Spec/S01-overview.pod for the
		# list of acceptable Perl 6 extensions
		p6  => 'application/x-perl6',
		p6l => 'application/x-perl6',
		p6m => 'application/x-perl6',
		pl6 => 'application/x-perl6',
		pm6 => 'application/x-perl6',
	);

	%DEFAULT_DOC_CLASS = (

		#	'text/x-abc'                => ## \
		'text/x-adasrc' => 'DoubleDashComment',
		'text/x-asm'    => 'HashComment',

		#	'text/x-bat'                => ## REM
		'application/x-bibtex' => 'PercentComment',
		'text/x-c'             => 'DoubleSlashComment',
		'text/x-c++src'        => 'DoubleSlashComment',

		#	'text/css'                  => ## /* ... */
		'text/x-eiffel' => 'DoubleDashComment',

		#	'text/x-forth'              => ## \
		#	'text/x-fortran'            => ## !
		#	'text/html'                 => ## <!-- ... -->
		'application/javascript' => 'DoubleSlashComment',
		'application/x-latex'    => 'PercentComment',

		#	'application/x-lisp'        => ## ;
		'application/x-shellscript' => 'HashComment',
		'text/x-java-source'        => 'DoubleSlashComment',
		'text/x-lua'                => 'DoubleDashComment',
		'text/x-makefile'           => 'HashComment',
		'text/x-matlab'             => 'PercentComment',

		#	'text/x-pascal'             => ## { ... }
		'application/x-perl' => 'Perl',

		#	'application/x-psgi'        => ## Perl or HashComment or something else?
		'text/x-python' => 'HashComment',

		'application/x-php'  => 'HashComment',
		'application/x-ruby' => 'HashComment',

		'text/x-sql' => 'DoubleDashComment',

		#	'text/vbscript'             => ## '
		'text/x-config' => 'HashComment',

		#	'text/xml'                  => ## <!-- ... -->
		'text/x-yaml'         => 'HashComment',
		'application/x-perl6' => 'HashComment',

		#       'text/x-perlxs'             => ## ' #'
		#	'text/x-perltt'             => ## <!-- ... -->
		'text/x-csharp' => 'DoubleSlashComment',

		'text/x-pod' => 'POD',
	);

	%HIGHLIGHTER_CONFIG = (
		'application/x-perl' => 'lang_perl5_lexer',
	);

	# This is the mime-type to Scintilla lexer mapping.
	# Lines marked with CONFIRMED indicate that the mime-type has been checked
	# that the MIME type is either the official type, or the primary
	# one in use by the relevant language community.

	# name  => Human readable name
	# lexer => The Scintilla lexer to be used

	# Padre can use Wx::Scintilla's built-in Perl 6 lexer
	my $perl6_scintilla_lexer =
		Padre::Config::wx_scintilla_ready() ? Wx::Scintilla::wxSCINTILLA_LEX_PERL6() : Wx::wxSTC_LEX_NULL;

	%MIME = (
		'text/x-abc' => {
			name  => 'ABC',
			lexer => Wx::wxSTC_LEX_NULL,
		},

		'text/x-adasrc' => {
			name  => 'ADA',
			lexer => Wx::wxSTC_LEX_ADA, # CONFIRMED
		},

		'text/x-asm' => {
			name  => 'ASM',
			lexer => Wx::wxSTC_LEX_ASM, # CONFIRMED
		},

		# application/x-msdos-program includes .exe and .com, so don't use it
		# text/x-bat is used in EXT_MIME, application/x-bat was listed here,
		# they need to be the same
		'text/x-bat' => {
			name  => 'BAT',
			lexer => Wx::wxSTC_LEX_BATCH, # CONFIRMED
		},

		'application/x-bibtex' => {
			name  => 'BibTeX',
			lexer => Wx::wxSTC_LEX_NULL,
		},

		'application/x-bml' => {
			name  => 'BML',
			lexer => Wx::wxSTC_LEX_NULL,  #
		},

		'text/x-c' => {
			name  => 'C',
			lexer => Wx::wxSTC_LEX_CPP,
		},

		'text/x-c++src' => {
			name  => 'C++',
			lexer => Wx::wxSTC_LEX_CPP,   # CONFIRMED
		},

		'text/css' => {
			name  => 'CSS',
			lexer => Wx::wxSTC_LEX_CSS,   # CONFIRMED
		},

		'text/x-eiffel' => {
			name  => 'Eiffel',
			lexer => Wx::wxSTC_LEX_EIFFEL, # CONFIRMED
		},

		'text/x-forth' => {
			name  => 'Forth',
			lexer => Wx::wxSTC_LEX_FORTH,  # CONFIRMED
		},

		'text/x-fortran' => {
			name  => 'Fortran',
			lexer => Wx::wxSTC_LEX_FORTRAN, # CONFIRMED
		},

		'text/html' => {
			name  => 'HTML',
			lexer => Wx::wxSTC_LEX_HTML,    # CONFIRMED
		},

		'application/javascript' => {
			name  => 'JavaScript',
			lexer => Wx::wxSTC_LEX_ESCRIPT, # CONFIRMED
		},

		'application/json' => {
			name  => 'JSON',
			lexer => Wx::wxSTC_LEX_ESCRIPT, # CONFIRMED
		},

		'application/x-latex' => {
			name  => 'LaTeX',
			lexer => Wx::wxSTC_LEX_LATEX,   # CONFIRMED
		},

		'application/x-lisp' => {
			name  => 'LISP',
			lexer => Wx::wxSTC_LEX_LISP,    # CONFIRMED
		},

		'text/x-patch' => {
			name  => 'Patch',
			lexer => Wx::wxSTC_LEX_DIFF,    # CONFIRMED
		},

		'application/x-shellscript' => {
			name  => _T('Shell Script'),
			lexer => Wx::wxSTC_LEX_BASH,
		},

		'text/x-java-source' => {
			name  => 'Java',
			lexer => Wx::wxSTC_LEX_CPP,
		},

		'text/x-lua' => {
			name  => 'Lua',
			lexer => Wx::wxSTC_LEX_LUA, # CONFIRMED
		},

		'text/x-makefile' => {
			name  => 'Makefile',
			lexer => Wx::wxSTC_LEX_MAKEFILE, # CONFIRMED
		},

		'text/x-matlab' => {
			name  => 'Matlab',
			lexer => Wx::wxSTC_LEX_MATLAB,   # CONFIRMED
		},

		'text/x-pascal' => {
			name  => 'Pascal',
			lexer => Wx::wxSTC_LEX_PASCAL,   # CONFIRMED
		},

		'application/x-perl' => {
			name  => 'Perl 5',
			lexer => Wx::wxSTC_LEX_PERL,     # CONFIRMED
		},

		'application/x-psgi' => {
			name  => 'PSGI',
			lexer => Wx::wxSTC_LEX_PERL,     # CONFIRMED
		},

		'text/x-python' => {
			name  => 'Python',
			lexer => Wx::wxSTC_LEX_PYTHON,          # CONFIRMED
			class => 'Padre::Document::HashComment',
		},

		'application/x-php' => {
			name  => 'PHP',
			lexer => Wx::wxSTC_LEX_PHPSCRIPT,       # CONFIRMED
		},

		'application/x-ruby' => {
			name  => 'Ruby',
			lexer => Wx::wxSTC_LEX_RUBY,            # CONFIRMED
			class => 'Padre::Document::HashComment',
		},

		'text/x-sql' => {
			name  => 'SQL',
			lexer => Wx::wxSTC_LEX_SQL,             # CONFIRMED
		},

		'application/x-tcl' => {
			name  => 'Tcl',
			lexer => Wx::wxSTC_LEX_TCL,             # CONFIRMED
		},

		'text/vbscript' => {
			name  => 'VBScript',
			lexer => Wx::wxSTC_LEX_VBSCRIPT,        # CONFIRMED
		},

		'text/x-config' => {
			name  => 'Config',
			lexer => Wx::wxSTC_LEX_CONF,
		},

		# text/xml specifically means "human-readable XML".
		# This is prefered to the more generic application/xml
		'text/xml' => {
			name  => 'XML',
			lexer => Wx::wxSTC_LEX_XML,             # CONFIRMED
		},

		'text/x-yaml' => {
			name  => 'YAML',
			lexer => Wx::wxSTC_LEX_YAML,            # CONFIRMED
		},

		'application/x-pir' => {
			name  => 'PIR',
			lexer => Wx::wxSTC_LEX_NULL,            # CONFIRMED
		},

		'application/x-pasm' => {
			name  => 'PASM',
			lexer => Wx::wxSTC_LEX_NULL,            # CONFIRMED
		},

		'application/x-perl6' => {
			name  => 'Perl 6',
			lexer => $perl6_scintilla_lexer,        # CONFIRMED
		},

		'text/plain' => {
			name  => _T('Text'),
			lexer => Wx::wxSTC_LEX_NULL,            # CONFIRMED
		},

		# Completely custom mime types
		'text/x-perlxs' => {                        # totally not confirmed
			name => 'XS',
			lexer =>
				Wx::wxSTC_LEX_CPP,                  # for the lack of a better XS lexer (vim?)
		},
		'text/x-perltt' => {
			name  => 'Template Toolkit',
			lexer => Wx::wxSTC_LEX_HTML,
		},

		'text/x-csharp' => {
			name  => 'C#',
			lexer => Wx::wxSTC_LEX_CPP,
		},
		'text/x-pod' => {
			name  => 'POD',
			lexer => Wx::wxSTC_LEX_PERL,
		},
	);


	foreach my $type ( keys %DEFAULT_DOC_CLASS ) {
		if ( exists $MIME{$type} ) {
			$MIME{$type}->{class} = 'Padre::Document::' . $DEFAULT_DOC_CLASS{$type};
		} else {
			warn "Unknown MIME type: $type\n";
		}
	}

	# Array ref of objects with value and mime_type fields that have the raw values
	__PACKAGE__->load_highlighter_config;

	__PACKAGE__->add_highlighter(
		'stc', _T('Scintilla'),
		_T('Fast but might be out of date')
	);

	foreach my $mime ( keys %MIME ) {
		__PACKAGE__->add_highlighter_to_mime_type( $mime, 'stc' );
	}

	__PACKAGE__->add_highlighter(
		'stc', _T('Scintilla'),
		_T('Fast but might be out of date')
	);

	# Perl 5 specific highlighters
	__PACKAGE__->add_highlighter(
		'Padre::Document::Perl::Lexer',
		_T('PPI Experimental'),
		_T('Slow but accurate and we have full control so bugs can be fixed')
	);
	__PACKAGE__->add_highlighter(
		'Padre::Document::Perl::PPILexer',
		_T('PPI Standard'),
		_T('Hopefully faster than the PPI Traditional. Big file will fall back to Scintilla highlighter.')
	);

	__PACKAGE__->add_highlighter_to_mime_type(
		'application/x-perl',
		'Padre::Document::Perl::Lexer'
	);
	__PACKAGE__->add_highlighter_to_mime_type(
		'application/x-perl',
		'Padre::Document::Perl::PPILexer'
	);
}

sub get_lexer {
	$MIME{ $_[1] }->{lexer};
}

sub add_mime_class {
	my $class      = shift;
	my $type       = shift;
	my $mime_class = shift;

	if ( not $MIME{$type} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type was not supported when %s(%s) was called'),
				'add_mime_class',
				$type
			)
		);
		return;
	}

	$MIME{$type}->{class} = $mime_class;
}

sub reset_mime_class {
	my $class = shift;
	my $type  = shift;

	if ( not $MIME{$type} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type is not supported when %s(%s) was called'),
				'remove_mime_class',
				$type
			)
		);
		return;
	}

	if ( not $MIME{$type}->{class} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type did not have a class entry when %s(%s) was called'),
				'remove_mime_class',
				$type
			)
		);
		return;
	}

	if ( exists $DEFAULT_DOC_CLASS{$type} ) {
		$MIME{$type}->{class} = 'Padre::Document::' . $DEFAULT_DOC_CLASS{$type};
	} else {
		delete $MIME{$type}->{class};
	}
}

sub get_mime_class {
	my $class = shift;
	my $type  = shift;

	if ( not $MIME{$type} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type is not supported when %s(%s) was called'),
				'get_mime_class',
				$type
			)
		);
		return;
	}

	return $MIME{$type}->{class};
}

sub add_highlighter {
	my $class       = shift;
	my $module      = shift;
	my $human       = shift;
	my $explanation = shift || '';

	if ( not defined $human ) {
		Carp::Cluck("human name not defined for '$module'\n");
		return;
	}
	$HIGHLIGHTER{$module} = {
		name        => $human,
		explanation => $explanation,
	};
}

sub get_highlighter_explanation {
	my $class = shift;
	my $name  = shift;

	my ($highlighter) =
		grep { $HIGHLIGHTER{$_}->{name} eq $name }
		keys %HIGHLIGHTER;
	if ( not $highlighter ) {
		Carp::cluck("Could not find highlighter for '$name'\n");
		return '';
	}
	return Wx::gettext( $HIGHLIGHTER{$highlighter}->{explanation} );
}

sub get_highlighter_name {
	my $class       = shift;
	my $highlighter = shift;

	# TO DO this can happen if the user configured highlighter but on the next start
	# the highlighter is not available any more
	# we need to handle this situation
	return '' if !defined($highlighter);
	return ''
		if not $HIGHLIGHTER{$highlighter}; # avoid autovivification
	return $HIGHLIGHTER{$highlighter}->{name};
}

# get a hash of mime-type => highlighter
# update the database
sub change_highlighters {
	my $class   = shift;
	my $changed = shift;

	my %mtn = map { $MIME{$_}->{name} => $_ } keys %MIME;
	my %highlighters =
		map { $HIGHLIGHTER{$_}->{name} => $_ }
		keys %HIGHLIGHTER;

	foreach my $name ( keys %$changed ) {
		my $type        = $mtn{$name};
		my $highlighter = $highlighters{ $changed->{$name} };
		Padre::DB::SyntaxHighlight->set_mime_type( $type, $highlighter );
	}

	$class->load_highlighter_config;
}

sub load_highlighter_config {
	my $current_highlighters = Padre::DB::SyntaxHighlight->select || [];

	# Set defaults
	foreach my $type ( keys %MIME ) {
		$MIME{$type}->{current_highlighter} = 'stc';
	}

	# TO DO check if the highlighter is really available
	foreach my $e (@$current_highlighters) {
		if ( defined $e->mime_type ) {
			$MIME{ $e->mime_type }->{current_highlighter} = $e->value;
		}
	}

	# Override with settings that have been moved from the database
	# to the Padre::Config system
	# Can't use Padre::Current here, because we won't have Padre->new yet.
	my $config = Padre::Config->read;
	foreach my $type ( keys %HIGHLIGHTER_CONFIG ) {
		my $method = $HIGHLIGHTER_CONFIG{$type};
		$MIME{$type}->{current_highlighter} = $config->$method();
	}
}

# returns hash of mime_type => highlighter
sub get_current_highlighters {
	map { $_ => $MIME{$_}->{current_highlighter} } keys %MIME;
}

# returns hash-ref of mime_type_name => highlighter_name
sub get_current_highlighter_names {
	my $class = shift;
	my %hash  = ();

	foreach my $type ( keys %MIME ) {
		$hash{ $class->get_mime_type_name($type) } =
			$class->get_highlighter_name( $MIME{$type}->{current_highlighter} );
	}
	return \%hash;
}

sub get_current_highlighter_of_mime_type {
	return $MIME{ $_[1] }->{current_highlighter};
}

sub add_highlighter_to_mime_type {
	my $class  = shift;
	my $mime   = shift;
	my $module = shift; # Or 'stc' to indicate Scintilla

	# TO DO check overwrite, check if it is listed in HIGHLIGHTER_EXPLANATIONS
	$MIME{$mime}->{highlighters}->{$module} = 1;
}

sub remove_highlighter_from_mime_type {
	my $class  = shift;
	my $mime   = shift;
	my $module = shift;

	# TO DO check overwrite
	delete $MIME{$mime}->{highlighters}->{$module};
}

# return the MIME types ordered according to their display name
sub get_mime_types {
	return [
		sort { lc $MIME{$a}->{name} cmp lc $MIME{$b}->{name} }
			keys %MIME
	];
}

# return the display-names of the MIME types ordered according to the display names
sub get_mime_type_names {
	my $class = shift;

	return [ map { $MIME{$_}->{name} } @{ $class->get_mime_types } ]; # Need to be checked with non Western languages

}

# given a MIME type
# return its display name
sub get_mime_type_name {
	my $class = shift;
	my $type = shift || '';
	return Wx::gettext('UNKNOWN')
		if $type eq ''
			or not $MIME{$type}
			or not $MIME{$type}->{name};
	return Wx::gettext( $MIME{$type}->{name} );
}

# given a MIME type
# return the display names of the available highlighters
sub get_highlighters_of_mime_type {
	my $class = shift;
	my $type  = shift;
	my @names = map { __PACKAGE__->get_highlighter_name($_) } sort keys %{ $MIME{$type}->{highlighters} };
	return \@names;
}

# given the display name of a MIME type
# return the display names of the available highlighters
sub get_highlighters_of_mime_type_name {
	my ( $class, $name ) = @_;
	my ($type) =
		grep { $MIME{$_}->{name} eq $name } keys %MIME;
	if ( not $type ) {
		warn "Could not find the MIME type of the display name '$name'\n";
		return []; # return [] to avoid crash
	}
	$class->get_highlighters_of_mime_type($type);
}





#####################################################################
# Bad/Ugly/Broken Methods
# These don't really completely belong in this class, but there's
# currently nowhere better for them. Some break API boundaries...
# NOTE: This is NOT an excuse to invent somewhere new that's just as
# innappropriate just to get them out of here.

sub _guess_mimetype {
	warn join( ',', caller ) . ' called MimeTypes::_guess_mimetype which is depreached, use ::guess_mimetype!';
	return $_[0]->guess_mimetype(@_);
}

sub guess_mimetype {
	my $class = shift;
	my $text  = shift;
	my $file  = shift; # Could be a filename or a Padre::File - object

	my $filename;

	if ( ref($file) ) {
		$filename = $file->{filename};

		# Combining this to one line would check if the method ->mime exists, not the result!
		my $MIME = $file->mime;
		defined($MIME) and return $MIME;

	} else {
		$filename = $file;
		undef $file;
	}


	# Try derive the mime type from the file extension
	if ( $filename and $filename =~ /\.([^.]+)$/ ) {
		my $ext = lc $1;
		if ( $EXT_MIME{$ext} ) {
			if ( ref $EXT_MIME{$ext} ) {
				return $EXT_MIME{$ext}->( $class, $text );
			} else {
				return $EXT_MIME{$ext};
			}
		}
	}

	# Try derive the mime type from the basename
	# Makefile is now highlighted as a Makefile
	# Changelog files are now displayed as text files
	if ($filename) {
		my $basename = File::Basename::basename($filename);
		if ($basename) {
			return 'text/x-makefile' if $basename =~ /^Makefile\.?/i;
			return 'text/plain'      if $basename =~ /^(changes|changelog)/i;
		}
	}

	# Fall back on deriving the type from the content.
	# Hardcode this for now for the cases that we care about and
	# are obvious.
	if ( defined $text ) {
		my $eval_mime_type = eval {

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
					print STDERR "$_[0] while looking for mime type of $filename";
				}
			};

			# Is this a script of some kind?
			if ( $text =~ /\A#!/ ) {
				return $class->perl_mime_type($text)
					if $text =~ /\A#!.*\bperl6?\b/m;
				return 'application/x-tcl'
					if $text =~ /\A#!.*\bsh\b.*(?:\n.*)?\nexec wish/m;
				return 'application/x-tcl'
					if $text =~ /\A#!.*\bwish\b/m;
				return 'application/x-shellscript'
					if $text =~ /\A#!.*\b(?:z|k|ba|t?c|da)?sh\b/m;
				return 'text/x-python'
					if $text =~ /\A#!.*\bpython\b/m;
				return 'application/x-ruby'
					if $text =~ /\A#!.*\bruby\b/m;
			}

			# YAML will start with a ---
			if ( $text =~ /\A---/ ) {
				return 'text/x-yaml';
			}

			# Try to identify Perl Scripts based on soft criterias as a last resort
			# TO DO: Improve the tests
			SCOPE: {
				my $score = 0;
				if ( $text =~ /(use \w+\:\:\w+.+?\;[\r\n][\r\n.]*){3,}/ ) {
					$score += 2;
				}
				if ( $text =~ /use \w+\:\:\w+.+?\;[\r\n]/ ) { $score += 1; }
				if ( $text =~ /require ([\"\'])[a-zA-Z0-9\.\-\_]+\1\;[\r\n]/ ) {
					$score += 1;
				}
				if ( $text =~ /[\r\n]sub \w+ ?(\(\$*\))? ?\{([\s\t]+\#.+)?[\r\n]/ ) {
					$score += 1;
				}
				if ( $text =~ /\=\~ ?[sm]?\// )  { $score += 1; }
				if ( $text =~ /\bmy [\$\%\@]/ )  { $score += .5; }
				if ( $text =~ /1\;[\r\n]+$/ )    { $score += .5; }
				if ( $text =~ /\$\w+\{/ )        { $score += .5; }
				if ( $text =~ /\bsplit[ \(]\// ) { $score += .5; }
				return $class->perl_mime_type($text) if $score >= 3;
			}

			# Look for Template::Toolkit syntax
			#  - traditional syntax:
			return 'text/x-perltt'
				if $text =~ /\[\%[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\%\]/;

			#  - default alternate styles (match 2 tags)
			return 'text/x-perltt'
				if $text
					=~ /(\%\%[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\%\%.*){2}/s;
			return 'text/x-perltt'
				if $text
					=~ /(\[\*[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\*\].*){2}/s;

			#  - other languages defaults (match 3 tags)
			return 'text/x-perltt'
				if $text
					=~ /(\<([\?\%])[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\1\>.*){3}/s;
			return 'text/x-perltt'
				if $text
					=~ /(\<\%[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\>.*){3}/s;
			return 'text/x-perltt'
				if $text
					=~ /(\<\!\-\-[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\-\-\>.*){3}/s;

			#  - traditional, but lowercase syntax (3 tags)
			return 'text/x-perltt'
				if $text
					=~ /(\[\%[\+\-\=\~]? (PROCESS|WRAPPER|FOREACH|BLOCK|END|INSERT|INCLUDE)\b .* [\+\-\=\~]?\%\].*){3}/si;

			# Try to recognize XHTML
			return 'text/html'
				if $text =~ /\A<\?xml version="\d+\.\d+" encoding=".+"\?>/m
					and $text =~ /^<!DOCTYPE html/m;

			# Try to recognize XML
			return 'text/xml'
				if $text =~ /^<\?xml version="\d+\.\d+"(?: +encoding=".+")?(?: +standalone="(?:yes|no)")?\?>/;

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
			return 'text/css'
				if $text !~ /\<\w+\/?\>/
					and $text =~ /^([\.\#]?\w+( [\.\#]?\w+)*)(\,[\s\t\r\n]*([\.\#]?\w+( [\.\#]?\w+)*))*[\s\t\r\n]*\{/;

			# LUA detection
			my $lua_score = 0;
			for ( 'end', 'it', 'in', 'nil', 'repeat', '...', '~=' ) {
				$lua_score += 1.1 if $text =~ /[\s\t]$_[\s\t]/;
			}
			$lua_score += 2.01
				if $text =~ /^[\s\t]?function[\s\t]+\w+[\s\t]*\([\w\,]*\)[\s\t\r\n]+[^\{]/;
			$lua_score -= 5.02 if $text =~ /[\{\}]/; # Not used in lua
			$lua_score += 3.04 if $text =~ /\-\-\[.+?\]\]\-\-/s; # Comment
			return 'text/x-lua' if $lua_score >= 5;

			return '';
		};
		return if $@;
		return $eval_mime_type if $eval_mime_type;
	}

	# Fallback mime-type of new files, should be configurable in the GUI
	# TO DO: Make it configurable in the GUI :)
	unless ($filename) {
		return $class->perl_mime_type($text);
	}

	# Fall back to plain text file
	return 'text/plain';
}

# currently we only have one pod mime-type but probably we should have
# two separate ones. One for Perl 5 and one for Perl 6
sub pod_mime_type {
	return 'text/x-pod';
}

sub perl_mime_type {
	my $class = shift;
	my $text  = shift;

	# Sometimes Perl 6 will look like Perl 5
	# But only do this test if the Perl 6 plugin is enabled.
	if ( $MIME{'application/x-perl6'}->{class} and is_perl6($text) ) {
		return 'application/x-perl6';
	} else {
		return 'application/x-perl';
	}
}

sub mime_type_by_extension {
	$EXT_MIME{ $_[1] };
}

sub get_extensions_by_mime_type {

	# %EXT_MIME holds a mapping of extenions to their mimetypes
	# We may want to know what extensions belong to a mimetype:
	my $class    = shift;
	my $mimetype = shift;

	my @extensions;
	while ( my ( $key, $value ) = each(%EXT_MIME) ) {

		# this is just so bad, but to be honest I have no idea
		# how else to do this :(
		$value = 'application/x-perl'
			if ( ref($value) eq 'CODE' ); # assume the hash holds a code ref for all perl extensions.
		if ( $value eq $mimetype ) {
			push @extensions, $key;
		}

	}
	return @extensions;

}

# naive sub to decide if a piece of code is Perl 6 or Perl 5.
# Perl 6:   use v6; class ..., module ...
# maybe also grammar ...
# but make sure that is real code and not just a comment or doc in some perl 5 code...
sub is_perl6 {
	my $text = shift;

	# empty/undef text is not Perl 6 :)
	return if not $text;

	# Perl 6 POD
	return 1 if $text =~ /^=begin\s+pod/msx;

	# Needed for eg/perl5_with_perl6_example.pod
	return if $text =~ /^=head[12]/msx;

	# =cut is a sure sign for Perl 5 code (moritz++)
	return if $text =~ /^=cut/msx;

	# Special case: If MooseX::Declare is there, then we're in Perl 5 land
	return if $text =~ /^\s*use\s+MooseX::Declare/msx;

	# Perl 6 'use v6;'
	return 1 if $text =~ /^\s*use\s+v6;/msx;

	# One of Perl 6 compilation units
	return 1 if $text =~ /^\s*(?:class|grammar|module|role)\s+\w/msx;

	# Not Perl 6 for sure...
	return;
}

sub menu_view_mimes {
	my %menu_view_mimes = ();
	foreach my $type ( keys %MIME ) {
		my $name = $MIME{$type}->{name};
		if ($name) {
			$menu_view_mimes{$type} = $name;
		}
	}
	return %menu_view_mimes;
}


1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Wx::Scintilla;

# Utility package for integrating Wx::Scintilla with Padre

use 5.008;
use Padre::Config           ();
use Padre::MimeTypes        ();
use Padre::Util             ('_T');
use Wx::Scintilla::Constant ();
use Wx::Scintilla           ();





######################################################################
# Content Lexers

my %LEXER = (
	'text/x-abc'                => Wx::Scintilla::Constant::SCLEX_NULL,
	'text/x-actionscript'       => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-adasrc'             => Wx::Scintilla::Constant::SCLEX_ADA,       # CONFIRMED
	'text/x-asm'                => Wx::Scintilla::Constant::SCLEX_ASM,       # CONFIRMED
	'application/x-bibtex'      => Wx::Scintilla::Constant::SCLEX_NULL,
	'application/x-bml'         => Wx::Scintilla::Constant::SCLEX_NULL,
	'text/x-bat'                => Wx::Scintilla::Constant::SCLEX_BATCH,     # CONFIRMED
	'text/x-c'                  => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-cobol'              => Wx::Scintilla::Constant::SCLEX_COBOL,     # CONFIRMED 
	'text/x-c++src'             => Wx::Scintilla::Constant::SCLEX_CPP,       # CONFIRMED
	'text/css'                  => Wx::Scintilla::Constant::SCLEX_CSS,       # CONFIRMED
	'text/x-eiffel'             => Wx::Scintilla::Constant::SCLEX_EIFFEL,    # CONFIRMED
	'text/x-forth'              => Wx::Scintilla::Constant::SCLEX_FORTH,     # CONFIRMED
	'text/x-fortran'            => Wx::Scintilla::Constant::SCLEX_FORTRAN,   # CONFIRMED
	'text/x-haskell'            => Wx::Scintilla::Constant::SCLEX_HASKELL,   # CONFIRMED
	'text/html'                 => Wx::Scintilla::Constant::SCLEX_HTML,      # CONFIRMED
	'application/javascript'    => Wx::Scintilla::Constant::SCLEX_ESCRIPT,   # CONFIRMED
	'application/json'          => Wx::Scintilla::Constant::SCLEX_ESCRIPT,   # CONFIRMED
	'application/x-latex'       => Wx::Scintilla::Constant::SCLEX_LATEX,     # CONFIRMED
	'application/x-lisp'        => Wx::Scintilla::Constant::SCLEX_LISP,      # CONFIRMED
	'text/x-patch'              => Wx::Scintilla::Constant::SCLEX_DIFF,      # CONFIRMED
	'application/x-shellscript' => Wx::Scintilla::Constant::SCLEX_BASH,
	'text/x-java-source'        => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-lua'                => Wx::Scintilla::Constant::SCLEX_LUA,       # CONFIRMED
	'text/x-makefile'           => Wx::Scintilla::Constant::SCLEX_MAKEFILE,  # CONFIRMED
	'text/x-matlab'             => Wx::Scintilla::Constant::SCLEX_MATLAB,    # CONFIRMED
	'text/x-pascal'             => Wx::Scintilla::Constant::SCLEX_PASCAL,    # CONFIRMED
	'application/x-perl'        => Wx::Scintilla::Constant::SCLEX_PERL,      # CONFIRMED
	'text/x-povray'             => Wx::Scintilla::Constant::SCLEX_POV,
	'application/x-psgi'        => Wx::Scintilla::Constant::SCLEX_PERL,      # CONFIRMED
	'text/x-python'             => Wx::Scintilla::Constant::SCLEX_PYTHON,    # CONFIRMED
	'application/x-php'         => Wx::Scintilla::Constant::SCLEX_PHPSCRIPT, # CONFIRMED
	'application/x-ruby'        => Wx::Scintilla::Constant::SCLEX_RUBY,      # CONFIRMED
	'text/x-sql'                => Wx::Scintilla::Constant::SCLEX_SQL,       # CONFIRMED
	'application/x-tcl'         => Wx::Scintilla::Constant::SCLEX_TCL,       # CONFIRMED
	'text/vbscript'             => Wx::Scintilla::Constant::SCLEX_VBSCRIPT,  # CONFIRMED
	'text/x-config'             => Wx::Scintilla::Constant::SCLEX_CONF,
	'text/xml'                  => Wx::Scintilla::Constant::SCLEX_XML,       # CONFIRMED
	'text/x-yaml'               => Wx::Scintilla::Constant::SCLEX_YAML,      # CONFIRMED
	'application/x-pir'         => Wx::Scintilla::Constant::SCLEX_NULL, # CONFIRMED
	'application/x-pasm'        => Wx::Scintilla::Constant::SCLEX_NULL, # CONFIRMED
	'application/x-perl6'       => 102, # TODO Wx::Scintilla::Constant::PERL_6
	'text/plain'                => Wx::Scintilla::Constant::SCLEX_NULL, # CONFIRMED
	# for the lack of a better XS lexer (vim?)
	'text/x-perlxs'             => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-perltt'             => Wx::Scintilla::Constant::SCLEX_HTML,
	'text/x-csharp'             => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-pod'                => Wx::Scintilla::Constant::SCLEX_PERL,
);

sub lexer {
	my $class = shift;
	my $mime  = shift;
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $mime;
	return Wx::Scintilla::Constant::SCLEX_CONTAINER if $HIGHLIGHTER{$mime};
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $LEXER{$mime};
	return $LEXER{$mime};
}





######################################################################
# Syntax Highlighters

# Supported non-Scintilla colourising modules
my %MODULE = (
	'Padre::Document::Perl::Lexer' => {
		name => _T('PPI Experimental'),
		mime => {
			'application/x-perl' => 1,
		}
	},
	'Padre::Document::Perl::PPILexer' => {
		name => _T('PPI Standard'),
		mime => {
			'application/x-perl' => 1,
		}
	},
);

# Current highlighter for each mime type
my %HIGHLIGHTER = ();

# Fill from configuration settings
sub highlighter_init {
	my $config = Padre::Config->read;
	%HIGHLIGHTER = (
		'application/x-perl' => $config->lang_perl5_lexer,
	);

	return 1;
}

sub highlighter {
	$HIGHLIGHTER{ $_[1] };
}

1;

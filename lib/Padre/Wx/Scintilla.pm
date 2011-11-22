package Padre::Wx::Scintilla;

# Utility package for integrating Wx::Scintilla with Padre

use 5.008;
use strict;
use warnings;
use Params::Util            ();
use Class::Inspector        ();
use Padre::Config           ();
use Padre::MIME             ();
use Padre::Util             ('_T');
use Wx::Scintilla::Constant ();

our $VERSION    = '0.93';
our $COMPATIBLE = '0.93';





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
my %HIGHLIGHTER = (
	'application/x-perl' => Padre::Config->read->lang_perl5_lexer,
);

sub highlighter {
	my $mime = _TYPE($_[1]);
	return $HIGHLIGHTER{$mime};
}

sub add_highlighter {
	my $class  = shift;
	my $module = shift;
	my $params = shift;

	# Check the highlighter params
	unless ( Class::Inspector->installed($module) ) {
		die "Missing or invalid highlighter $module";
	}
	if ( $MODULE{$module} ) {
		die "Duplicate highlighter registration $module";
	}
	unless ( Params::Util::_HASH($params) ) {
		die "Missing or invalid highlighter params";
	}
	unless ( defined Params::Util::_STRING($params->{name}) ) {
		die "Missing or invalid highlighter name";
	}
	unless ( Params::Util::_ARRAY($params->{mime}) ) {
		die "Missing or invalid highlighter mime list";
	}

	# Register the highlighter module
	my %mime = map { $_ => 1 } @{$params->{mime}};
	$MODULE{$module} = {
		name => $params->{name},
		mime => \%mime,
	};

	# Bind the mime types to the highlighter
	foreach my $mime ( keys %mime ) {
		$HIGHLIGHTER{$mime} = $module;
	}

	return 1;
}

sub remove_highlighter {
	my $class  = shift;
	my $module = shift;

	# Unregister the highlighter module
	my $deleted = delete $MODULE{$module} or return;

	# Unbind the mime types for the highlighter
	foreach my $mime ( keys %HIGHLIGHTER ) {
		next unless $HIGHLIGHTER{$mime} eq $module;
		delete $HIGHLIGHTER{$mime};
	}

	return 1;
}





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
	'text/x-csrc'               => Wx::Scintilla::Constant::SCLEX_CPP,       # CONFIRMED
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
	'text/x-java'               => Wx::Scintilla::Constant::SCLEX_CPP,       # CONFIRMED
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
	'application/x-pir'         => Wx::Scintilla::Constant::SCLEX_NULL,      # CONFIRMED
	'application/x-pasm'        => Wx::Scintilla::Constant::SCLEX_NULL,      # CONFIRMED
	'application/x-perl6'       => 102, # TODO Wx::Scintilla::Constant::PERL_6
	'text/plain'                => Wx::Scintilla::Constant::SCLEX_NULL,      # CONFIRMED
	# for the lack of a better XS lexer (vim?)
	'text/x-perlxs'             => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-perltt'             => Wx::Scintilla::Constant::SCLEX_HTML,
	'text/x-csharp'             => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-pod'                => Wx::Scintilla::Constant::SCLEX_PERL,
);

# Must ALWAYS return a valid lexer (defaulting to AUTOMATIC as a last resort)
sub lexer {
	my $mime  = _TYPE($_[1]);
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $mime;
	return Wx::Scintilla::Constant::SCLEX_CONTAINER if $HIGHLIGHTER{$mime};
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $LEXER{$mime};
	return $LEXER{$mime};
}





######################################################################
# Support Functions

sub _TYPE {
	my $it = shift;
	if ( Params::Util::_INSTANCE($it, 'Padre::Document') ) {
		$it = $it->mime;
	}
	if ( Params::Util::_INSTANCE($it, 'Padre::MIME') ) {
		$it = $it->type;
	}
	return $it || '';
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::MimeTypes;

=pod

=head1 NAME

Padre::MimeTypes - Padre MIME Types

=head1 DESCRIPTION

See L<Padre::Document>

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp           ();
use Padre::Config  ();
use Padre::Current ();
use Padre::Util    ('_T');

our $VERSION    = '0.93';
our $COMPATIBLE = '0.93';

# Binary file extensions, which we don't support loading at all
my %EXT_BINARY = ();

# Text file extension to MIME type mapping (either string or code reference)
my %EXT_MIME = ();

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
		cmd   => 'text/x-bat',
		bib   => 'application/x-bibtex',
		bml   => 'application/x-bml',     # dreamwidth file format
		c     => 'text/x-c',
		h     => 'text/x-c',
		cc    => 'text/x-c++src',
		cpp   => 'text/x-c++src',
		cxx   => 'text/x-c++src',
		cob   => 'text/x-cobol',
		cbl   => 'text/x-cobol',
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
		hs    => 'text/x-haskell',
		i     => 'text/x-c',              # C code that should not be preprocessed
		ii    => 'text/x-c++src',         # C++ code that should not be preprocessed
		java  => 'text/x-java-source',
		js    => 'application/javascript',
		json  => 'application/json',
		lsp   => 'application/x-lisp',
		lua   => 'text/x-lua',
		m     => 'text/x-matlab',
		mak   => 'text/x-makefile',
		pod   => 'text/x-pod',
		py    => 'text/x-python',
		rb    => 'application/x-ruby',
		sql   => 'text/x-sql',
		tcl   => 'application/x-tcl',
		patch => 'text/x-patch',
		pks   => 'text/x-sql',            # PLSQL package spec
		pkb   => 'text/x-sql',            # PLSQL package body
		pl    => \&perl_mime_type,
		plx   => \&perl_mime_type,
		pm    => \&perl_mime_type,
		pmc   => \&perl_mime_type,        # Compiled Perl Module or gimme5's output
		pod   => 'text/x-pod',
		pov   => 'text/x-povray',
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

		# Pascal
		pas => 'text/x-pascal',
		dpr => 'text/x-pascal',
		dfm => 'text/x-pascal',
		inc => 'text/x-pascal',
		pp  => 'text/x-pascal',

		# ActionScript
		as   => 'text/x-actionscript',
		asc  => 'text/x-actionscript',
		jsfl => 'text/x-actionscript',

		# PHP
		php   => 'application/x-php',
		php3  => 'application/x-php',
		phtml => 'application/x-php',

		# VisualBasic and VBScript
		vb  => 'text/vbscript',
		bas => 'text/vbscript',
		frm => 'text/vbscript',
		cls => 'text/vbscript',
		ctl => 'text/vbscript',
		pag => 'text/vbscript',
		dsr => 'text/vbscript',
		dob => 'text/vbscript',
		vbs => 'text/vbscript',
		dsm => 'text/vbscript',
	);

	%DEFAULT_DOC_CLASS = (
		'application/x-perl' => 'Padre::Document::Perl',
		'text/x-python'      => 'Padre::Document::Python',
		'application/x-ruby' => 'Padre::Document::Ruby',
		'text/x-java-source' => 'Padre::Document::Java',
		'text/x-csharp'      => 'Padre::Document::CSharp',
		'text/x-patch'       => 'Padre::Document::Patch',
	);

	# Lines marked with CONFIRMED indicate that the mime-type has been checked
	# that the MIME type is either the official type, or the primary
	# one in use by the relevant language community.

	# name  => Human readable name

	%MIME = (
		'text/x-abc' => {
			name  => 'ABC',
		},
		'text/x-actionscript' => {
			name  => 'ABC',
		},
		'text/x-adasrc' => {
			name  => 'Ada',
		},
		'text/x-asm' => {
			name  => 'Assembly',
		},

		# application/x-msdos-program includes .exe and .com, so don't use it
		# text/x-bat is used in EXT_MIME, application/x-bat was listed here,
		# they need to be the same
		'text/x-bat' => {
			name  => 'Batch',
		},

		'application/x-bibtex' => {
			name  => 'BibTeX',
		},

		'application/x-bml' => {
			name  => 'BML',
		},

		'text/x-c' => {
			name  => 'C',
		},

		'text/x-cobol' => {
			name  => 'COBOL',
		},

		'text/x-c++src' => {
			name  => 'C++',
		},

		'text/css' => {
			name  => 'CSS',
		},

		'text/x-eiffel' => {
			name  => 'Eiffel',
		},

		'text/x-forth' => {
			name  => 'Forth',
		},

		'text/x-fortran' => {
			name  => 'Fortran',
		},

		'text/x-haskell' => {
			name  => 'Haskell',
		},

		'text/html' => {
			name  => 'HTML',
		},

		'application/javascript' => {
			name  => 'JavaScript',
		},

		'application/json' => {
			name  => 'JSON',
		},

		'application/x-latex' => {
			name  => 'LaTeX',
		},

		'application/x-lisp' => {
			name  => 'LISP',
		},

		'text/x-patch' => {
			name  => 'Patch',
		},

		'application/x-shellscript' => {
			name  => _T('Shell Script'),
		},

		'text/x-java-source' => {
			name  => 'Java',
		},

		'text/x-lua' => {
			name  => 'Lua',
		},

		'text/x-makefile' => {
			name  => 'Makefile',
		},

		'text/x-matlab' => {
			name  => 'Matlab',
		},

		'text/x-pascal' => {
			name  => 'Pascal',
		},

		'application/x-perl' => {
			name  => 'Perl 5',
		},
		
		'text/x-povray' => {
			name  => 'POVRAY',
		},

		'application/x-psgi' => {
			name  => 'PSGI',
		},

		'text/x-python' => {
			name  => 'Python',
		},

		'application/x-php' => {
			name  => 'PHP',
		},

		'application/x-ruby' => {
			name  => 'Ruby',
		},

		'text/x-sql' => {
			name  => 'SQL',
		},

		'application/x-tcl' => {
			name  => 'Tcl',
		},

		'text/vbscript' => {
			name  => 'VBScript',
		},

		'text/x-config' => {
			name  => 'Config',
		},

		# text/xml specifically means "human-readable XML".
		# This is prefered to the more generic application/xml
		'text/xml' => {
			name  => 'XML',
		},

		'text/x-yaml' => {
			name  => 'YAML',
		},

		'application/x-pir' => {
			name  => 'PIR',
		},

		'application/x-pasm' => {
			name  => 'PASM',
		},

		'application/x-perl6' => {
			name  => 'Perl 6',
		},

		'text/plain' => {
			name  => _T('Text'),
		},

		# Completely custom mime types
		'text/x-perlxs' => {                       # totally not confirmed
			name => 'XS',
		},
		'text/x-perltt' => {
			name  => 'Template Toolkit',
		},

		'text/x-csharp' => {
			name  => 'C#',
		},
		'text/x-pod' => {
			name  => 'POD',
		},
	);

	foreach my $mime ( keys %DEFAULT_DOC_CLASS ) {
		if ( exists $MIME{$mime} ) {
			$MIME{$mime}->{class} = $DEFAULT_DOC_CLASS{$mime};
		} else {
			warn "Unknown MIME type: $mime\n";
		}
	}
}

sub add_mime_class {
	my $class  = shift;
	my $mime   = shift;
	my $module = shift;

	if ( not $MIME{$mime} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type was not supported when %s(%s) was called'),
				'add_mime_class',
				$mime
			)
		);
		return;
	}

	$MIME{$mime}->{class} = $module;
}

sub reset_mime_class {
	my $class = shift;
	my $mime  = shift;

	if ( not $MIME{$mime} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type is not supported when %s(%s) was called'),
				'remove_mime_class',
				$mime
			)
		);
		return;
	}

	if ( not $MIME{$mime}->{class} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type did not have a class entry when %s(%s) was called'),
				'remove_mime_class',
				$mime
			)
		);
		return;
	}

	if ( exists $DEFAULT_DOC_CLASS{$mime} ) {
		$MIME{$mime}->{class} = $DEFAULT_DOC_CLASS{$mime};
	} else {
		delete $MIME{$mime}->{class};
	}
}

sub get_mime_class {
	my $class = shift;
	my $mime  = shift;

	if ( not $MIME{$mime} ) {
		Padre::Current->main->error(
			sprintf(
				Wx::gettext('MIME type is not supported when %s(%s) was called'),
				'get_mime_class',
				$mime
			)
		);
		return;
	}

	return $MIME{$mime}->{class};
}

# return the MIME types ordered according to their display name
sub get_mime_types {
	return [
		sort { lc $MIME{$a}->{name} cmp lc $MIME{$b}->{name} }
			keys %MIME
	];
}

# given a MIME type
# return its display name
sub get_mime_type_name {
	my $class = shift;
	my $mime = shift || '';
	return Wx::gettext('UNKNOWN')
		if $mime eq ''
			or not $MIME{$mime}
			or not $MIME{$mime}->{name};
	return Wx::gettext( $MIME{$mime}->{name} );
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
		require File::Basename;
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

sub perl_mime_type {
	my $class = shift;
	my $text  = shift;

	# Sometimes Perl 6 will look like Perl 5
	# But only do this test if the lang_perl6_auto_detection is enabled.
	my $config = Padre::Config->read;
	if ( $config->lang_perl6_auto_detection and is_perl6($text) ) {
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
	foreach my $mime ( keys %MIME ) {
		my $name = $MIME{$mime}->{name};
		if ($name) {
			$menu_view_mimes{$mime} = $name;
		}
	}
	return %menu_view_mimes;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

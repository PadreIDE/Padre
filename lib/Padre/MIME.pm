package Padre::MIME;

=pod

=head1 NAME

Padre::MIME - Padre MIME Types

=head1 DESCRIPTION

See L<Padre::Document>

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Locale::T;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';

# The MIME object store
my %MIME = ();

# The "Unknown" MIME type
my $UNKNOWN = Padre::MIME->new(
	type  => '',
	name  => _T('UNKNOWN'),
);

# File extension to MIME type mapping
my %EXT = (
	abc   => 'text/x-abc',
	ada   => 'text/x-adasrc',
	asm   => 'text/x-asm',
	bat   => 'text/x-bat',
	cmd   => 'text/x-bat',
	bib   => 'application/x-bibtex',

	# Dreamwidth file format
	bml   => 'application/x-bml',

	c     => 'text/x-csrc',
	h     => 'text/x-csrc',
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

	# C code that should not be preprocessed
	i     => 'text/x-csrc',
	ii    => 'text/x-c++src',

	java  => 'text/x-java',
	js    => 'application/javascript',
	json  => 'application/json',
	lsp   => 'application/x-lisp',
	lua   => 'text/x-lua',
	m     => 'text/x-matlab',
	mak   => 'text/x-makefile',
	pod   => 'text/x-pod',
	py    => 'text/x-python',
        r     => 'text/x-r',
	rb    => 'application/x-ruby',
	sql   => 'text/x-sql',
	tcl   => 'application/x-tcl',
	patch => 'text/x-patch',
	pks   => 'text/x-sql',         # PLSQL package spec
	pkb   => 'text/x-sql',         # PLSQL package body
	pl    => 'application/x-perl',
	plx   => 'application/x-perl',
	pm    => 'application/x-perl',

	# Compiled Perl Module or gimme5's output
	pmc   => 'application/x-perl',

	pod   => 'text/x-pod',
	pov   => 'text/x-povray',
	psgi  => 'application/x-psgi',
	sty   => 'application/x-latex',
	t     => 'application/x-perl',
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
	php4  => 'application/x-php',
	php5  => 'application/x-php',
	phtm  => 'application/x-php',
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






######################################################################
# MIME Registry Methods

sub types {
	keys %MIME;
}

sub find {
	$MIME{$_[1]} || $UNKNOWN;
}





######################################################################
# MIME Objects

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Check the supertype and precalculate the supertype path
	if ( $self->{supertype} ) {
		unless ( $MIME{$self->{supertype}} ) {
			die "MIME type '$self->{supertype}' does not exist";
		}
		$self->{superpath} = [
			$self->{type},
			$MIME{$self->{supertype}}->superpath,
		];
	} else {
		$self->{superpath} = [ $self->{type} ];
	}

	return $self;
}

sub create {
	my $class = shift;
	my $self  = $class->new(@_);
	$MIME{$self->type} = $self;
}

sub type {
	$_[0]->{type};
}

sub name {
	$_[0]->{name};
}

sub supertype {
	$_[0]->{supertype};
}

sub superpath {
	@{$_[0]->{superpath}};
}

sub super {
	$MIME{ $_[0]->{supertype} || '' };
}

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

sub plugin {
	$_[0]->{plugin} = $_[1];
}

sub reset {
	delete $_[0]->{plugin};
}





######################################################################
# MIME Declarations

# Plain text from which everything else should inherit
Padre::MIME->create(
	type      => 'text/plain',
	name      => _T('Text'),
	document  => 'Padre::Document',
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
	type      => 'application/x-bat',
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
	type      => 'text/html',
	name      => 'HTML',
	supertype => 'text/plain',
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
	type      => 'text/xml',
	name      => 'XML',
	document  => 'Padre::Document',
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





#####################################################################
# MIME Type Detection

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
	my $mime = undef;
	if ( $param{svn} and $file ) {
		$mime = $class->detect_mimetype($file);
	}

	# Try derive the mime type from the file extension
	if ( not defined $mime and $file ) {
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
	if ( not defined $mime and defined $text ) {
		$mime = eval {
			$class->detect_content($text)
		};
		return undef if $@;
	}

	# Fallback mime-type of new files, should be configurable in the GUI
	# TO DO: Make it configurable in the GUI :)
	if ( not defined $mime and not defined $file ) {
		$mime = 'application/x-perl';
	}

	# Finally fall back to plain text file
	unless ( defined $mime and length $mime ) {
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

sub detect_svn {
	my $class = shift;
	my $file  = shift;
	my $mime  = undef;
	local $@;
	eval {
		require Padre::SVN;
		$mime = Padre::SVN::file_mimetype($file);
	};
	return $mime;
}

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
		return 'text/html' if $text =~ /^<!DOCTYPE html/m;
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

# naive sub to decide if a piece of code is Perl 6 or Perl 5.
# Perl 6:   use v6; class ..., module ...
# maybe also grammar ...
# but make sure that is real code and not just a comment or doc in some perl 5 code...
sub detect_perl6 {
	my $class = shift;
	my $text  = shift;

	# empty/undef text is not Perl 6 :)
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

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

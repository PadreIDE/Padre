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
use Padre::Config  ();
use Padre::Util    ('_T');

our $VERSION    = '0.93';
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
	bml   => 'application/x-bml',     # dreamwidth file format
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
	i     => 'text/x-csrc',           # C code that should not be preprocessed
	ii    => 'text/x-c++src',         # C++ code that should not be preprocessed
	java  => 'text/x-java',
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





######################################################################
# MIME Objects

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	# Check the supertype and precalculate the super path
	if ( $self->{super} ) {
		unless ( $MIME{$self->{super}} ) {
			die "Supertype '$self->{super}' does not exist";
		}
		$self->{super_path} = [
			$self->{type},
			$MIME{$self->{super}}->super_path,
		];
	} else {
		$self->{super_path} = [ $self->{type} ];
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

sub super {
	$_[0]->{super};
}

sub super_path {
	@{$_[0]->{super_path}};
}

sub class {
	my $self = shift;
	foreach my $type ( $self->super_path ) {
		my $mime = $MIME{$type};
		return $mime->{class}    if $mime->{class};
		return $mime->{document} if $mime->{document};
	}
	die "Failed to find a document class for '" . $self->type . "'";
}





######################################################################
# MIME Registry

sub types {
	keys %MIME;
}

sub get {
	$MIME{$_[1]} || $UNKNOWN;
}

sub get_class {
	my $class = shift;
	my $mime  = $MIME{ shift || '' };
	unless ( $mime ) {
		warn "Unknown MIME type '$mime'";
		return;
	}
	return $mime->{class} if $mime->{class};
	return $mime->{document};
}

sub set_class {
	my $class  = shift;
	my $mime   = shift;
	my $module = shift;
	unless ( $mime and $MIME{$mime} ) {
		warn "Unknown MIME type '$mime'";
		return;
	}
	$MIME{$mime}->{class} = $module;
}

sub reset_class {
	my $class = shift;
	my $mime  = shift;
	unless ( $mime and $MIME{$mime} ) {
		warn "Unknown MIME type '$mime'";
		return;
	}
	delete $MIME{$mime}->{class};
}





######################################################################
# MIME Declarations

# Plain text from which everything else should inherit
Padre::MIME->create(
	type     => 'text/plain',
	name     => _T('Text'),
	document => 'Padre::Document',
);

Padre::MIME->create(
	type  => 'text/x-abc',
	name  => 'ABC',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-actionscript',
	name  => 'ActionScript',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-adasrc',
	name  => 'Ada',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-asm',
	name  => 'Assembly',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-bat',
	name  => 'Batch',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-bibtex',
	name  => 'BibTeX',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-bat',
	name  => 'BML',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-csrc',
	name  => 'C',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-cobol',
	name  => 'COBOL',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-c++src',
	name  => 'C++',
	super => 'text/x-csrc',
);

Padre::MIME->create(
	type  => 'text/css',
	name  => 'CSS',
	super => 'text/x-csrc',
);

Padre::MIME->create(
	type  => 'text/x-eiffel',
	name  => 'Eiffel',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-forth',
	name  => 'Forth',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-fortran',
	name  => 'Fortran',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-haskell',
	name  => 'Haskell',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/html',
	name  => 'HTML',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/javascript',
	name  => 'JavaScript',
	super => 'text/x-csrc',
);

Padre::MIME->create(
	type  => 'application/json',
	name  => 'JSON',
	super => 'application/javascript',
);

Padre::MIME->create(
	type  => 'application/x-latex',
	name  => 'LaTeX',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-lisp',
	name  => 'LISP',
	super => 'text/plain',
);

Padre::MIME->create(
	type     => 'text/x-patch',
	name     => 'Patch',
	super    => 'text/plain',
	document => 'Padre::Document::Patch',
);

Padre::MIME->create(
	type  => 'application/x-shellscript',
	name  => _T('Shell Script'),
	super => 'text/plain',
);

Padre::MIME->create(
	type     => 'text/x-java',
	name     => 'Java',
	super    => 'text/x-csrc',
	document => 'Padre::Document::Java',
);

Padre::MIME->create(
	type  => 'text/x-lua',
	name  => 'Lua',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-makefile',
	name  => 'Makefile',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-matlab',
	name  => 'Matlab',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-pascal',
	name  => 'Pascal',
	super => 'text/plain',
);

Padre::MIME->create(
	type     => 'application/x-perl',
	name     => 'Perl 5',
	super    => 'text/plain',
	document => 'Padre::Document::Perl',
);

Padre::MIME->create(
	type  => 'text/x-povray',
	name  => 'POVRAY',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-psgi',
	name  => 'PSGI',
	super => 'application/x-perl',
);

Padre::MIME->create(
	type     => 'text/x-python',
	name     => 'Python',
	super    => 'text/plain',
	document => 'Padre::Document::Python',
);

Padre::MIME->create(
	type  => 'application/x-php',
	name  => 'PHP',
	super => 'text/plain',
);

Padre::MIME->create(
	type     => 'application/x-ruby',
	name     => 'Ruby',
	super    => 'text/plain',
	document => 'Padre::Document::Ruby',
);

Padre::MIME->create(
	type  => 'text/x-sql',
	name  => 'SQL',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-tcl',
	name  => 'Tcl',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/vbscript',
	name  => 'VBScript',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'text/x-config',
	name  => 'Config',
	super => 'text/plain',
);

# text/xml specifically means "human-readable XML".
# This is prefered to the more generic application/xml
Padre::MIME->create(
	type  => 'text/xml',
	name  => 'XML',
);

Padre::MIME->create(
	type  => 'text/x-yaml',
	name  => 'YAML',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-pir',
	name  => 'PIR',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-pasm',
	name  => 'PASM',
	super => 'text/plain',
);

Padre::MIME->create(
	type  => 'application/x-perl6',
	name  => 'Perl 6',
	super => 'text/plain',
);

# Completely custom mime types
Padre::MIME->create(
	type  => 'text/x-perlxs', # totally not confirmed
	name => 'XS',
	super=> 'text/x-csrc',
);

Padre::MIME->create(
	type  => 'text/x-perltt',
	name  => 'Template Toolkit',
	super => 'text/plain',
);

Padre::MIME->create(
	type     => 'text/x-csharp',
	name     => 'C#',
	super    => 'text/x-csrc',
	document => 'Padre::Document::CSharp',
);

Padre::MIME->create(
	type  => 'text/x-pod',
	name  => 'POD',
	super => 'text/plain',
);





#####################################################################
# MIME Type Detection

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
		if ( $EXT{$ext} ) {
			if ( ref $EXT{$ext} ) {
				return $EXT{$ext}->( $class, $text );
			} else {
				return $EXT{$ext};
			}
		}
	}

	# Try to derive the mime type from the basename
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

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

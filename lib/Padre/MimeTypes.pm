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
use Data::Dumper   ();
use File::Basename ();
use Padre::Wx      ();
use Padre::DB      ();

our $VERSION = '0.50';

#####################################################################
# Document Registration

# This is the list of binary files
# (which we don't support loading in fallback text mode)
my %EXT_BINARY;
my %EXT_MIME;
my %AVAILABLE_HIGHLIGHTERS;
my %MIME_TYPES;

_initialize();

sub _initialize {
	return if %EXT_BINARY; # call it only once

	%EXT_BINARY = map { $_ => 1 } qw{
		aiff  au    avi  bmp  cache  dat   doc  gif  gz   icns
		jar   jpeg  jpg  m4a  mov    mp3   mpg  ogg  pdf  png
		pnt   ppt   qt   ra   svg    svgz  svn  swf  tar  tgz
		tif   tiff  wav  xls  xlw    zip
	};

	# This is the primary file extension to mime-type mapping
	%EXT_MIME = (
		abc   => 'text/x-abc',
		ada   => 'text/x-adasrc',
		asm   => 'text/x-asm',
		bat   => 'text/x-bat',
		bml   => 'text/x-bml',            # dreamwidth file format
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

		# Compiled Perl Module or gimme5's output
		pmc   => \&perl_mime_type,
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

	# This is the mime-type to Scintilla lexer mapping.
	# Lines marked with CONFIRMED indicate that the mime-typehas been checked
	# to confirm that the MIME type is either the official type, or the primary
	# one in use by the relevant language community.

	# name => Human readable name
	# lexer => The Scintilla lexer to be used
	# class => document class

	%MIME_TYPES = (
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
		'application/x-bat' => {
			name  => 'BAT',
			lexer => Wx::wxSTC_LEX_BATCH, # CONFIRMED
		},

		'application/x-bml' => {
			name  => 'BML',
			lexer => Wx::wxSTC_LEX_NULL,  #
		},

		'text/x-c++src' => {
			name  => 'c++',
			lexer => Wx::wxSTC_LEX_CPP,   # CONFIRMED
		},
		'text/css' => {
			name  => 'CSS',
			lexer => Wx::wxSTC_LEX_CSS,   # CONFIRMED
		},
		'text/x-patch' => {
			name  => 'Patch',
			lexer => Wx::wxSTC_LEX_DIFF,  # CONFIRMED
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
			name  => 'Javascript',
			lexer => Wx::wxSTC_LEX_ESCRIPT, # CONFIRMED
		},
		'application/json' => {
			name  => 'JSON',
			lexer => Wx::wxSTC_LEX_ESCRIPT, # CONFIRMED
		},
		'application/x-latex' => {
			name  => 'Latex',
			lexer => Wx::wxSTC_LEX_LATEX,   # CONFIRMED
		},
		'application/x-lisp' => {
			name  => 'LISP',
			lexer => Wx::wxSTC_LEX_LISP,    # CONFIRMED
		},
		'application/x-shellscript' => {
			name  => 'Shellscript',
			lexer => Wx::wxSTC_LEX_BASH,
		},
		'text/x-lua' => {
			name  => 'Lua',
			lexer => Wx::wxSTC_LEX_LUA,     # CONFIRMED
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
			class => 'Padre::Document::Perl',
		},
		'text/x-python' => {
			name  => 'Python',
			lexer => Wx::wxSTC_LEX_PYTHON,   # CONFIRMED
		},
		'application/x-php' => {
			name  => 'PHP',
			lexer => Wx::wxSTC_LEX_PHPSCRIPT, # CONFIRMED
		},
		'application/x-ruby' => {
			name  => 'Ruby',
			lexer => Wx::wxSTC_LEX_RUBY,      # CONFIRMED
		},
		'text/x-sql' => {
			name  => 'SQL',
			lexer => Wx::wxSTC_LEX_SQL,       # CONFIRMED
		},
		'application/x-tcl' => {
			name  => 'Tcl',
			lexer => Wx::wxSTC_LEX_TCL,       # CONFIRMED
		},
		'text/vbscript' => {
			name  => 'VBScript',
			lexer => Wx::wxSTC_LEX_VBSCRIPT,  # CONFIRMED
		},

		'text/x-config' => {
			name  => 'Config',
			lexer => Wx::wxSTC_LEX_CONF,
		},

		# text/xml specifically means "human-readable XML".
		# This is prefered to the more generic application/xml
		'text/xml' => {
			name  => 'XML',
			lexer => Wx::wxSTC_LEX_XML,       # CONFIRMED
		},

		'text/x-yaml' => {
			name  => 'YAML',
			lexer => Wx::wxSTC_LEX_YAML,      # CONFIRMED
		},
		'application/x-pir' => {
			name  => 'PIR',
			lexer => Wx::wxSTC_LEX_NULL,      # CONFIRMED
		},
		'application/x-pasm' => {
			name  => 'PASM',
			lexer => Wx::wxSTC_LEX_NULL,      # CONFIRMED
		},
		'application/x-perl6' => {
			name  => 'Perl 6',
			lexer => Wx::wxSTC_LEX_NULL,      # CONFIRMED
		},
		'text/plain' => {
			name  => 'Text',
			lexer => Wx::wxSTC_LEX_NULL,      # CONFIRMED
		},
	);

	# TO DO:
	# add some mime-type for pod files
	# or remove the whole Padre::Document::POD class as it is not in use
	#'text/x-pod'         => 'Padre::Document::POD',



	# array ref of objects with value and mime_type fields that have the raw values
	__PACKAGE__->read_current_highlighters_from_db();

	__PACKAGE__->add_highlighter( 'stc', 'Scintilla', Wx::gettext('Fast but might be out of date') );

	foreach my $mime ( keys %MIME_TYPES ) {
		__PACKAGE__->add_highlighter_to_mime_type( $mime, 'stc' );
	}

	# Perl 5 specific highlighters
	__PACKAGE__->add_highlighter(
		'Padre::Document::Perl::Lexer',
		Wx::gettext('PPI Experimental'),
		Wx::gettext('Slow but accurate and we have full control so bugs can be fixed')
	);
	__PACKAGE__->add_highlighter(
		'Padre::Document::Perl::PPILexer',
		Wx::gettext('PPI Standard'),
		Wx::gettext('Hopefully faster than the PPI Traditional. Big file will fall back to Scintilla highlighter.')
	);

	__PACKAGE__->add_highlighter_to_mime_type( 'application/x-perl', 'Padre::Document::Perl::Lexer' );
	__PACKAGE__->add_highlighter_to_mime_type( 'application/x-perl', 'Padre::Document::Perl::PPILexer' );
}

sub get_lexer {
	my ( $self, $mime_type ) = @_;
	return $MIME_TYPES{$mime_type}{lexer};
}

# TO DO: Set some reasonable default highlighers for each mime-type for when there
# are no plugins. e.g. For Perl 6 style files that should be plain text.
# Either allow the plugins to set the defaults (maybe allow the plugin that implements
# the special features of this mime-type to pick the default or shall we have a list of
# prefered default values ?


sub add_mime_class {
	my $self  = shift;
	my $mime  = shift;
	my $class = shift;
	if ( not $MIME_TYPES{$mime} ) {

		# TO DO: display on the GUI
		warn "Mime type $mime is not supported when add_mime_class($class) was called\n";
		return;
	}

	if ( $MIME_TYPES{$mime}{class} ) {

		# TO DO: display on the GUI
		warn "Mime type $mime already has a class '$MIME_TYPES{$mime}{class}' when add_mime_class($class) was called\n";
		return;
	}
	$MIME_TYPES{$mime}{class} = $class;
}

sub remove_mime_class {
	my $self = shift;
	my $mime = shift;

	if ( not $MIME_TYPES{$mime} ) {

		# TO DO: display on GUI
		warn "Mime type $mime is not supported when remove_mime_class($mime) was called\n";
		return;
	}

	if ( not $MIME_TYPES{$mime}{class} ) {

		# TO DO: display on GUI
		warn "Mime type $mime does not have a class entry when remove_mime_class($mime) was called\n";
		return;
	}
	delete $MIME_TYPES{$mime}{class};
}

sub get_mime_class {
	my $self = shift;
	my $mime = shift;

	if ( not $MIME_TYPES{$mime} ) {

		# TO DO: display on GUI
		warn "Mime type $mime is not supported when remove_mime_class($mime) was called\n";
		return;
	}

	return $MIME_TYPES{$mime}{class};
}

sub add_highlighter {
	my $self        = shift;
	my $module      = shift;
	my $human       = shift;
	my $explanation = shift || '';

	if ( not defined $human ) {
		Carp::Cluck("human name not defined for '$module'\n");
		return;
	}
	$AVAILABLE_HIGHLIGHTERS{$module} = {
		name        => $human,
		explanation => $explanation,
	};
}

sub get_highlighter_explanation {
	my $self = shift;
	my $name = shift;

	#print Data::Dumper::Dumper \%AVAILABLE_HIGHLIGHTERS;
	my ($highlighter) = grep { $AVAILABLE_HIGHLIGHTERS{$_}{name} eq $name } keys %AVAILABLE_HIGHLIGHTERS;
	if ( not $highlighter ) {
		Carp::cluck("Could not find highlighter for '$name'\n");
		return '';
	}
	return $AVAILABLE_HIGHLIGHTERS{$highlighter}{explanation};
}

sub get_highlighter_name {
	my $self        = shift;
	my $highlighter = shift;

	# TO DO this can happen if the user configureda highlighter but on the next start
	# the highlighter is not available any more
	# we need to handle this situation
	return '' if !defined($highlighter);
	return '' if not $AVAILABLE_HIGHLIGHTERS{$highlighter}; # avoid autovivification
	return $AVAILABLE_HIGHLIGHTERS{$highlighter}{name};
}

# get a hash of mime-type => highlighter
# update the database
sub change_highlighters {
	my ( $self, $changed_highlighters ) = @_;

	my %mtn          = map { $MIME_TYPES{$_}{name}             => $_ } keys %MIME_TYPES;
	my %highlighters = map { $AVAILABLE_HIGHLIGHTERS{$_}{name} => $_ } keys %AVAILABLE_HIGHLIGHTERS;

	foreach my $mime_type_name ( keys %$changed_highlighters ) {
		my $mime_type   = $mtn{$mime_type_name};                                     # get mime_type from name
		my $highlighter = $highlighters{ $changed_highlighters->{$mime_type_name} }; # get highlighter from name
		Padre::DB::SyntaxHighlight->set_mime_type( $mime_type, $highlighter );
	}

	$self->read_current_highlighters_from_db();
}


sub read_current_highlighters_from_db {
	require Padre::DB::SyntaxHighlight;

	my $current_highlighters = Padre::DB::SyntaxHighlight->select || [];

	# set defaults
	foreach my $mime_type ( keys %MIME_TYPES ) {
		$MIME_TYPES{$mime_type}{current_highlighter} = 'stc';
	}

	# TO DO check if the highlighter is really available
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

	foreach my $mime_type ( keys %MIME_TYPES ) {
		$MT{$mime_type} = $MIME_TYPES{$mime_type}{current_highlighter};
	}
	return %MT;
}

# returns hash-ref of mime_type_name => highlighter_name
sub get_current_highlighter_names {
	my $self = shift;
	my %MT;

	foreach my $mime_type ( keys %MIME_TYPES ) {
		$MT{ $self->get_mime_type_name($mime_type) } =
			$self->get_highlighter_name( $MIME_TYPES{$mime_type}{current_highlighter} );
	}
	return \%MT;
}

sub get_current_highlighter_of_mime_type {
	my ( $self, $mime_type ) = @_;
	return $MIME_TYPES{$mime_type}{current_highlighter};
}

sub add_highlighter_to_mime_type {
	my $self   = shift;
	my $mime   = shift;
	my $module = shift; # module name or stc to indicate Scintilla
	                    # TO DO check overwrite, check if it is listed in HIGHLIGHTER_EXPLANATIONS
	$MIME_TYPES{$mime}{highlighters}{$module} = 1;
}

sub remove_highlighter_from_mime_type {
	my $self   = shift;
	my $mime   = shift;
	my $module = shift;

	# TO DO check overwrite
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
	my $self = shift;
	my $mime_type = shift || '';
	return $MIME_TYPES{$mime_type}{name};
}

# given a mime-type
# return the display-names of the available highlighters
sub get_highlighters_of_mime_type {
	my ( $self, $mime_type ) = @_;
	my @names = map { __PACKAGE__->get_highlighter_name($_) } sort keys %{ $MIME_TYPES{$mime_type}{highlighters} };
	return \@names;
}

# given the display-name of a mime-type
# return the display-names of the available highlighters
sub get_highlighters_of_mime_type_name {
	my ( $self, $mime_type_name ) = @_;
	my ($mime_type) = grep { $MIME_TYPES{$_}{name} eq $mime_type_name } keys %MIME_TYPES;
	if ( not $mime_type ) {
		warn "Could not find the mime-type of the display name '$mime_type_name'\n";
		return []; # return [] to avoid crash
	}
	$self->get_highlighters_of_mime_type($mime_type);
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
	my $self = shift;
	my $text = shift;
	my $file = shift; # Could be a filename or a Padre::File - object

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
				return $EXT_MIME{$ext}->( $self, $text );
			} else {
				return $EXT_MIME{$ext};
			}
		}
	}

	# Try derive the mime type from the basename
	if ($filename) {
		my $basename = File::Basename::basename($filename);
		if ($basename) {
			return 'text/x-makefile' if $basename =~ /^Makefile\.?/i;
		}
	}

	# Fall back on deriving the type from the content.
	# Hardcode this for now for the cases that we care about and
	# are obvious.
	if ( $text and $text =~ /\A#!/m ) {

		# Found a hash bang line
		if ( $text =~ /\A#![^\n]*\bperl6?\b/m ) {
			return $self->perl_mime_type($text);
		}
		if ( $text =~ /\A---/ ) {
			return 'text/x-yaml';
		}
	}

	# Try to identify Perl Scripts based on soft criterias as a last resort
	# TO DO: Improve the tests
	if ( defined($text) ) {
		my $Score = 0;
		if ( $text =~ /(use \w+\:\:\w+.+?\;[\r\n][\r\n.]*){3,}/ )           { $Score += 2; }
		if ( $text =~ /use \w+\:\:\w+.+?\;[\r\n]/ )                         { $Score += 1; }
		if ( $text =~ /require ([\"\'])[a-zA-Z0-9\.\-\_]+\1\;[\r\n]/ )      { $Score += 1; }
		if ( $text =~ /[\r\n]sub \w+ ?(\(\$*\))? ?\{([\s\t]+\#.+)?[\r\n]/ ) { $Score += 1; }
		if ( $text =~ /\=\~ ?[sm]?\// )                                     { $Score += 1; }
		if ( $text =~ /\bmy [\$\%\@]/ )                                     { $Score += .5; }
		if ( $text =~ /1\;[\r\n]+$/ )                                       { $Score += .5; }
		if ( $text =~ /\$\w+\{/ )                                           { $Score += .5; }
		if ( $text =~ /\bsplit[ \(]\// )                                    { $Score += .5; }
		return $self->perl_mime_type($text) if $Score >= 3;
	}

	# Fallback mime-type of new files, should be configurable in the GUI
	# TO DO: Make it configurable in the GUI :)
	unless ($filename) {
		return $self->perl_mime_type($text);
	}

	# Fall back to plain text file
	return 'text/plain';
}

sub perl_mime_type {
	my $self = shift;
	my $text = shift;

	# Sometimes Perl 6 will look like Perl 5
	# But only do this test if the Perl 6 plugin is enabled.
	if ( $MIME_TYPES{'application/x-perl6'}{class} and is_perl6($text) ) {
		return 'application/x-perl6';
	} else {
		return 'application/x-perl';
	}
}

sub mime_type_by_extension {
	$EXT_MIME{ $_[1] };
}

# naive sub to decide if a piece of code is Perl 6 or Perl 5.
# Perl 6:   use v6; class ..., module ...
# maybe also grammar ...
# but make sure that is real code and not just a comment or doc in some perl 5 code...
sub is_perl6 {
	my ($text) = @_;

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

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

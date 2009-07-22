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
use Carp            ();
use Data::Dumper    ();
use File::Basename  ();

our $VERSION = '0.40';

#####################################################################
# Document Registration

# This is the list of binary files
# (which we don't support loading in fallback text mode)
my %EXT_BINARY;
my %EXT_MIME;


# TODO fill this hash and use this name in various places where a human readable
# display of file type is needed
# TODO move the whole mime-type and highlighter related code to its own class
my %AVAILABLE_HIGHLIGHTERS;
my %MIME_TYPES;
# This is the mime-type to document class mapping
my %MIME_CLASS;

_initialize();

sub _initialize {
	return if %EXT_BINARY;

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

		'text/x-config' => Wx::wxSTC_LEX_CONF,

		# text/xml specifically means "human-readable XML".
		# This is prefered to the more generic application/xml
		'text/xml' => Wx::wxSTC_LEX_XML,                        # CONFIRMED

		'text/x-yaml'         => Wx::wxSTC_LEX_YAML,            # CONFIRMED
		'application/x-pir'   => Wx::wxSTC_LEX_NULL,            # CONFIRMED
		'application/x-pasm'  => Wx::wxSTC_LEX_NULL,            # CONFIRMED
		'application/x-perl6' => Wx::wxSTC_LEX_NULL,            # CONFIRMED
		'text/plain'          => Wx::wxSTC_LEX_NULL,            # CONFIRMED
	);

	%MIME_CLASS = (
		'application/x-perl' => 'Padre::Document::Perl',
		'text/x-pod'         => 'Padre::Document::POD',
	);

	%MIME_TYPES = (
		'application/x-perl' => {
			name  => 'Perl 5',
		},
		'application/x-perl6' => {
			name => 'Perl 6',
		}
	);
	foreach my $mt ( keys %MIME_LEXER ) {
		$MIME_TYPES{$mt}{name} = $mt unless $MIME_TYPES{$mt};
		$MIME_TYPES{$mt}{lexer} = $MIME_LEXER{$mt};
	}

	# array ref of objects with value and mime_type fields that have the raw values
	__PACKAGE__->read_current_highlighters_from_db();

	__PACKAGE__->add_highlighter( 'stc', 'Scintilla', Wx::gettext('Scintilla, fast but might be out of date') );

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
		Wx::gettext('Hopefully faster than the PPI Traditional')
	);

	__PACKAGE__->add_highlighter_to_mime_type( 'application/x-perl', 'Padre::Document::Perl::Lexer' );
	__PACKAGE__->add_highlighter_to_mime_type( 'application/x-perl', 'Padre::Document::Perl::PPILexer' );
}

sub get_lexer {
	my ($self, $mime_type) = @_;
	return $MIME_TYPES{ $mime_type }{lexer};
}

# TODO: Set some reasonable default highlighers for each mime-type for when there
# are no plugins. e.g. For Perl 6 style files that should be plain text.
# Either allow the plugins to set the defaults (maybe allow the plugin that implements
# the special features of this mime-type to pick the default or shall we have a list of
# prefered default values ?






sub add_mime_class {
	my $self  = shift;
	my $mime  = shift;
	my $class = shift;
	if ( $MIME_CLASS{$mime} ) {

		# TODO: display on the GUI
		warn "Mime type $mime already has a class '$MIME_CLASS{$mime}' when add_mime_class($class) was called\n";
		return;
	}
	$MIME_CLASS{$mime} = $class;
}

sub remove_mime_class {
	my $self = shift;
	my $mime = shift;
	if ( not $MIME_CLASS{$mime} ) {

		# TODO: display on GUI
		warn "Mime type $mime does not have an entry in the MIME_CLASS when remove_mime_class($mime) was called\n";
	}
	delete $MIME_CLASS{$mime};
}

sub get_mime_class {
	my $self = shift;
	my $mime = shift;
	return $MIME_CLASS{$mime};
}

sub add_highlighter {
	my $self        = shift;
	my $module      = shift;
	my $human       = shift;
	my $explanation = shift || '';

	if (not defined $human) {
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
	# TODO this can happen if the user configureda highlighter but on the next start
	# the highlighter is not available any more
	# we need to handle this situation
	return '' if not $AVAILABLE_HIGHLIGHTERS{$highlighter}; # avoid autovivification
	return $AVAILABLE_HIGHLIGHTERS{$highlighter}{name};
}

# get a hash of mime-type => highlighter
# update the database
sub change_highlighters {
	my ( $self, $changed_highlighters ) = @_;

	my %mtn          = map { $MIME_TYPES{$_}{name}             => $_ } keys %MIME_TYPES;
	my %highlighters = map { $AVAILABLE_HIGHLIGHTERS{$_}{name} => $_ } keys %AVAILABLE_HIGHLIGHTERS;

	require Padre::DB::SyntaxHighlight;
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

	# TODO check if the highlighter is really available
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
	my $self = shift;
	my $text = shift;
	my $filename = shift;
	
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
				return $EXT_MIME{$ext}->( $text );
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
			return $self->perl_mime_type( $text );
		}
		if ( $text =~ /\A---/ ) {
			return 'text/x-yaml';
		}
	}

	# Fall back to plain text file
	return 'text/plain';
}

sub perl_mime_type {
	my $self = shift;
	my $text = shift;

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


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Document;

=pod

=head1 NAME

Padre::Document - Padre Document Abstraction Layer

=head1 DESCRIPTION

This is an internal module of L<Padre> that provides a 
logical document abstraction, allowing Padre to associate 
several Wx elements with the one document.

The objective would be to allow the use of this module without
loading Wx.

Currently there are still interdependencies that need to be cleaned.

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp           ();
use File::Spec     ();
use Class::Autouse ();
use POSIX          qw(LC_CTYPE);
use Padre::Util    ();
use Padre::Wx      ();
use Padre;

our $VERSION = '0.22';

my $unsaved_number = 0;

# see Wx-0.86/ext/stc/cpp/st_constants.cpp for extension
# There might be some constants are defined in 
#  wxWidgets-2.8.8/contrib/include/wx/stc/stc.h 
# but not (yet) in 
#  Wx-0.86/ext/stc/cpp/st_constants.cpp
# so we have to hard-code their numeric value.

	# asp => wxSTC_LEX_ASP, #in ifdef
#	,
#	f     => wxSTC_LEX_FORTRAN,
	#     => wxSTC_LEX_VB, # What's the difference between VB and VBSCRIPT?

# partially made-up MIME-types; some parts extracted from /etc/mime.types
# Someone should go over and see if there are official mime-type definitions
# missing from the languages list
our %EXT_MIME = (
	ada   => 'text/x-adasrc',
	asm   => 'text/x-asm',
	bat   => 'text/x-bat',
	cpp   => 'text/x-c++src',
	css   => 'text/css',
	diff  => 'text/x-patch',
	e     => 'text/x-eiffel',
	f     => 'text/x-fortran',
	html  => 'text/html',
	js    => 'application/javascript',
	json  => 'application/json',
	latex => 'application/x-latex',
	lsp   => 'application/x-lisp',
	lua   => 'text/x-lua',
	mak   => 'text/x-makefile',
	mat   => 'text/x-matlab',
	pas   => 'text/x-pascal',
	php   => 'application/x-php',
	py    => 'text/x-python',
	rb    => 'application/x-ruby',
	sql   => 'text/x-sql',
	tcl   => 'application/x-tcl',
	vbs   => 'text/vbscript',
	patch => 'text/x-patch',
	pl    => 'application/x-perl',
	plx   => 'application/x-perl',
	pm    => 'application/x-perl',
	pod   => 'application/x-perl',
	t     => 'application/x-perl',
	xml   => 'text/xml',
	yml   => 'text/x-yaml',
	yaml  => 'text/x-yaml',
	'4th' => 'text/x-forth',
	pasm  => 'application/x-pasm',
	pir   => 'application/x-pir',
	p6    => 'application/x-perl6',
);

our %MIME_CLASS = (
	'application/x-perl'     => 'Padre::Document::Perl',
);

# Document types marked here with CONFIRMED have be checked to confirm that
# the MIME type is either the official type, or the primary one in use by
# the relevant language communities.
our %MIME_LEXER = (
	'text/x-adasrc'          => Wx::wxSTC_LEX_ADA,       # CONFIRMED
	'text/x-asm'             => Wx::wxSTC_LEX_ASM,       # CONFIRMED
	'application/x-bat'      => Wx::wxSTC_LEX_BATCH,     # CONFIRMED (application/x-msdos-program includes .exe and .com)
	'text/x-c++src'          => Wx::wxSTC_LEX_CPP,       # CONFIRMED
	'text/css'               => Wx::wxSTC_LEX_CSS,       # CONFIRMED
	'text/x-patch'           => Wx::wxSTC_LEX_DIFF,      # CONFIRMED
	'text/x-eiffel'          => Wx::wxSTC_LEX_EIFFEL,    # CONFIRMED
	'text/x-forth'           => Wx::wxSTC_LEX_FORTH,     # CONFIRMED
	'text/x-fortran'         => Wx::wxSTC_LEX_FORTRAN,   # CONFIRMED
	'text/html'              => Wx::wxSTC_LEX_HTML,      # CONFIRMED
	'application/javascript' => Wx::wxSTC_LEX_ESCRIPT,   # CONFIRMED
	'application/json'       => Wx::wxSTC_LEX_ESCRIPT,   # CONFIRMED
	'application/x-latex'    => Wx::wxSTC_LEX_LATEX,     # CONFIRMED
	'application/x-lisp'     => Wx::wxSTC_LEX_LISP,      # CONFIRMED
	'text/x-lua'             => Wx::wxSTC_LEX_LUA,       # CONFIRMED
	'text/x-makefile'        => Wx::wxSTC_LEX_MAKEFILE,  # CONFIRMED
	'text/x-matlab'          => Wx::wxSTC_LEX_MATLAB,    # CONFIRMED
	'text/x-pascal'          => Wx::wxSTC_LEX_PASCAL,    # CONFIRMED
	'application/x-perl'     => Wx::wxSTC_LEX_PERL,      # CONFIRMED
	'text/x-python'          => Wx::wxSTC_LEX_PYTHON,    # CONFIRMED
	'application/x-php'      => Wx::wxSTC_LEX_PHPSCRIPT, # CONFIRMED
	'application/x-ruby'     => Wx::wxSTC_LEX_RUBY,      # CONFIRMED
	'text/x-sql'             => Wx::wxSTC_LEX_SQL,       # CONFIRMED
	'application/x-tcl'      => Wx::wxSTC_LEX_TCL,       # CONFIRMED
	'text/vbscript'          => Wx::wxSTC_LEX_VBSCRIPT,  # CONFIRMED
	'text/xml'               => Wx::wxSTC_LEX_XML,       # CONFIRMED (text/xml specifically means "human-readable XML")
	'text/x-yaml'            => Wx::wxSTC_LEX_YAML,      # CONFIRMED
	'application/x-pir'      => Wx::wxSTC_LEX_CONTAINER, # CONFIRMED
	'application/x-pasm'     => Wx::wxSTC_LEX_CONTAINER, # CONFIRMED
	'application/x-perl6'    => Wx::wxSTC_LEX_CONTAINER, # CONFIRMED
);





#####################################################################
# Constructor and Accessors

use Class::XSAccessor
	getters => {
		editor           => 'editor',
		filename         => 'filename', # TODO is this read_only or what?
		get_mimetype     => 'mimetype',
		get_newline_type => 'newline_type',
		errstr           => 'errstr',
	},
	setters => {
		_set_filename    => 'filename', # TODO temporary hack
		set_newline_type => 'newline_type',
		set_mimetype     => 'mimetype',
		set_errstr       => 'errstr',
		set_editor       => 'editor',
	};

=pod

=head2 new

  my $doc = Padre::Document->new(
      filename => $file,
  );
 

$file is optional and if given it will be loaded in the document

mime-type is defined by the guess_mimetype function

TODO describe

 $editor is required and is a Padre::Wx::Editor object

=cut

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	$self->setup;

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
	my $subclass = $MIME_CLASS{$self->get_mimetype} || __PACKAGE__;
	if ( $subclass ) {
		Class::Autouse->autouse($subclass);
		bless $self, $subclass;
	}

	return;
}

sub guess_mimetype {
	my $self = shift;

	# default mime-type of new files, should be configurable in the GUI
	if (not $self->filename) {
		return 'application/x-perl';
	}

	# Try derive the mime type from the name
	if ( $self->filename and $self->filename =~ /\.([^.]+)$/ ) {
		my $ext = lc $1;
		return $EXT_MIME{$ext} if $EXT_MIME{$ext};
	}

	# Fall back on deriving the type from the content
	# Hardcode this for now for the special cases we care about.
	my $text = $self->{original_content};
	if ( $text and $text =~ /\A#!/m ) {
		# Found a hash bang line
		if ( $text =~ /\A#![^\n]*\bperl\b/m ) {
			return 'application/x-perl';
		}
	}

	# Fall back to a null value
	return '';
}

sub setup {
	my $self = shift;
	if ( $self->{filename} ) {
		$self->load_file;
	} else {
		$unsaved_number++;
		$self->{newline_type} = $self->_get_default_newline_type;
	}
}

sub get_title {
	my $self = shift;
	if ( $self->{filename} ) {
		return File::Basename::basename( $self->{filename} );
	} else {
		my $str = sprintf(Wx::gettext("Unsaved %d"), $unsaved_number);

		# A bug in Wx requires a space at the front of the title
		# (For reasons I don't understand yet)
		return ' ' . $str;
	}
}

# For ts without a newline type
# TODO: get it from config
sub _get_default_newline_type {
	Padre::Util::NEWLINE;
}

# Where to convert (UNIX, WIN, MAC)
# or Ask (the user) or Keep (the garbage)
# mixed files
# TODO get from config
sub _mixed_newlines {
	Padre::Util::NEWLINE;
}

# What to do with files that have inconsistent line endings:
# 0 if keep as they are
# MAC|UNIX|WIN convert them to the appropriate type
sub _auto_convert {
	my ($self) = @_;
	# TODO get from config
	return 0;
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
	$self->set_errstr('');
	my $content;
	if (open my $fh, '<', $file) {
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
	$content = Encode::decode($self->{encoding}, $content);
	#print "DEBUG: SystemDefault($system_default), $lang_shortname:$self->{encoding}, $file\n";

	$self->{original_content} = $content;

	return 1;
}

sub newline_type {
	my ($self) = @_;

	my $file = $self->{filename};
	my $newline_type = $self->_get_default_newline_type;
	my $convert_to;
	my $current_type = Padre::Util::newline_type( $self->{original_content} );
	if ($current_type eq 'None') {
		# keep default
	} elsif ($current_type eq 'Mixed') {
		my $mixed = $self->_mixed_newlines();
		if ( $mixed eq 'Ask') {
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
	return ($newline_type, $convert_to);
}

sub save_file {
	my ($self) = @_;
	$self->set_errstr('');

	my $content  = $self->text_get;
	my $filename = $self->filename;

	# not set when first time to save
	require Padre::Locale;
	$self->{encoding} ||= Padre::Locale::encoding_from_string($content);

	my $encode = '';
	if (defined $self->{encoding}) {
		$encode = ":raw:encoding($self->{encoding})";
	} else {
		warn "encoding is not set, (couldn't get from contents) when saving file $filename\n";
	}
	
	if (open my $fh,  ">$encode", $filename ) {
		print {$fh} $content;
	} else {
		$self->set_errstr($!);
		return;
	}
	$self->{_timestamp} = $self->time_on_file;
	return 1;
}

sub lexer {
	my $self = shift;
	return Wx::wxSTC_LEX_AUTOMATIC unless $self->get_mimetype;
	return Wx::wxSTC_LEX_AUTOMATIC unless defined $MIME_LEXER{$self->get_mimetype};
	return $MIME_LEXER{$self->get_mimetype};
}

sub is_new {
	return !! ( not defined $_[0]->filename );
}

sub is_modified {
	return !! ( $_[0]->editor->GetModify );
}

# check if the file on the disk has changed
# 1) when document gets the focus (gvim, notepad++)
# 2) when we try to save the file (gvim)
# 3) every time we type something ????

# returns if file has changed on the disk 
# since load time or the last time we saved
sub has_changed_on_disk {
	my ($self) = @_;
	return 0 if not defined $self->filename;
	return 0 if not defined $self->last_sync;
	return $self->last_sync < $self->time_on_file ? 1 : 0;
}

sub time_on_file {
	return 0 if not defined $_[0]->filename;
	return 0 if not -e $_[0]->filename;
	return (stat($_[0]->filename))[9];
}

sub last_sync {
	return $_[0]->{_timestamp};
}

# A new document that isn't worth saving
sub is_unused {
	my $self = shift;
	return '' unless $self->is_new;
	return 1  unless $self->is_modified;
	return 1  if     $self->text_get eq '';
	return '';
}

sub is_saved {
	return !! ( defined $_[0]->filename and not $_[0]->is_modified );
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

=pod

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

=cut




#####################################################################
# Content Manipulation

sub text_get {
	$_[0]->editor->GetText;
}

sub text_set {
	$_[0]->editor->SetText($_[1]);
}

sub text_like {
	my $self = shift;
	return !! ( $self->text_get =~ /$_[0]/m );
}





#####################################################################
# Project Methods

sub project_dir {
	my $self = shift;
	$self->{project_dir} or
	$self->{project_dir} = $self->find_project;
}

sub find_project {
	my $self = shift;

	# Anonmous files don't have a project
	unless ( defined $self->filename ) {
		return;
	}

	# Search upwards from the file to find the project root
	my ($v, $d, $f) = File::Spec->splitpath( $self->filename );
	my @d = File::Spec->splitdir($d);
	pop @d if $d[-1] eq '';
	require List::Util;
	my $dirs = List::Util::first {
		-f File::Spec->catpath( $v, $_, 'Makefile.PL' )
		or
		-f File::Spec->catpath( $v, $_, 'Build.PL' )
		or
		# Some notional Padre project file
		-f File::Spec->catpath( $v, $_, 'padre.yml' )
	} map {
		File::Spec->catdir(@d[0 .. $_])
	} reverse ( 0 .. $#d );

	unless ( defined $dirs ) {
		# This document is not part of a recognised project
		return;
	}

	return File::Spec->catpath( $v, $dirs );
}

# abstract method, each subclass should implement it
sub keywords           { return {} }
sub get_functions      { return () };
sub get_function_regex { return '' };

# should return ($length, @words)
# where $length is the length of the prefix to be replaced by one of the words
# or
# return ($error_message)
# in case of some error
sub autocomplete {
	my $self   = shift;

	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);

	# line from beginning to current position
	my $prefix = $editor->GetTextRange($first, $pos);
	   $prefix =~ s{^.*?(\w+)$}{$1};
	my $last   = $editor->GetLength();
	my $text   = $editor->GetTextRange(0, $last);
	my $pre_text  = $editor->GetTextRange(0, $first+length($prefix)); 
	my $post_text = $editor->GetTextRange($first, $last); 

	my $regex;
	eval { $regex = qr{\b($prefix\w+)\b} };
	if ($@) {
		return ("Cannot build regex for '$prefix'");
	}

	my %seen;
	my @words;
	push @words ,grep { ! $seen{$_}++ } reverse ($pre_text =~ /$regex/g);
	push @words , grep { ! $seen{$_}++ } ($post_text =~ /$regex/g);

	if (@words > 20) {
		@words = @words[0..19];
	}

	return (length($prefix), @words);
}

sub remove_color {
	my ($self) = @_;

	my $editor = $self->editor;
	# TODO this is strange, do we really need to do it with all?
	for my $i ( 0..31 ) {
		$editor->StartStyling(0, $i);
		$editor->SetStyling($editor->GetLength, 0);
	}

	return;
}

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
sub comment_lines_str {}

sub stats {
	my ($self) = @_;
	
	my ( $lines, $chars_with_space, $chars_without_space, $words, $is_readonly )
		= (0) x 5;

	my $editor = $self->editor;
	my $src = $editor->GetSelectedText;
	my $code;
	if ( $src ) {
		$code = $src;

		my $code2 = $code; # it's ugly, need improvement
		$code2 =~ s/\r\n/\n/g;
		$lines = 1; # by default
		$lines++ while ( $code2 =~ /[\r\n]/g );
		$chars_with_space = length($code);
	} else {
		$code = $self->text_get;

		# I trust editor more
		$lines = $editor->GetLineCount();
		$chars_with_space = $editor->GetTextLength();
		$is_readonly = $editor->GetReadOnly();
	}

	$words++ while ( $code =~ /\b\w+\b/g );
	$chars_without_space++ while ( $code =~ /\S/g );

	my $filename = $self->filename;
	
	return ( $lines, $chars_with_space, $chars_without_space, $words, $is_readonly, 
			$filename, $self->{newline_type}, $self->{encoding} );
}


# TODO: experimental
sub get_indentation_style {
	my $self = shift;
	my $config = Padre->ide->config;

	# TODO: (document >) project > config

	my $style;
	if ($config->{editor_auto_indentation_style}) {
		# TODO: This should be cached? What's with newish documents then?
		$style = $self->guess_indentation_style;
	}
	else {
		$style = {
			use_tabs    => $config->{editor_use_tabs},
			tabwidth    => $config->{editor_tabwidth},
			indentwidth => $config->{editor_indentwidth},
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
	my $self = shift;

	my $style  = shift || $self->get_indentation_style;
	my $editor = $self->editor;
	# The display width of literal tab characters (ne "indentation width"!)
	$editor->SetTabWidth( $style->{tabwidth} );
	# The actual indentation width in COLUMNS!
	$editor->SetIndent( $style->{indentwidth} );
	# Use tabs for indentation where possible?
	$editor->SetUseTabs(  $style->{use_tabs} );
	return();
}


=head2 guess_indentation_style

Automatically infer the indentation style of the document using
L<Text::FindIndent>.

Returns a hash reference containing the keys C<use_tabs>,
C<tabwidth>, and C<indentwidth>. It is suitable for passing
to C<set_indendentation_style>.

=cut

sub guess_indentation_style {
	my $self  = shift;

	require Text::FindIndent;
	my $indentation = Text::FindIndent->parse($self->text_get);

	my $style;
	if ($indentation =~ /^t\d+/) { # we only do ONE tab
		$style = {
			use_tabs    => 1,
			tabwidth    => 8,
			indentwidth => 8,
		};
	}
	elsif ($indentation =~ /^s(\d+)/) {
		$style = {
			use_tabs    => 0,
			tabwidth    => 8,
			indentwidth => $1,
		};
	}
	elsif ($indentation =~ /^m(\d+)/) {
		$style = {
			use_tabs    => 1,
			tabwidth    => 8,
			indentwidth => $1,
		};
	}
	else {
		# fallback
		my $config = Padre->ide->config;
		$style = {
			use_tabs    => $config->{editor_use_tabs},
			tabwidth    => $config->{editor_tabwidth},
			indentwidth => $config->{editor_indentwidth},
		};
	}
	
	return $style;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Document::Perl;

use 5.008;
use strict;
use warnings;
use Carp   ();
use Encode ();
use Params::Util '_INSTANCE';
use YAML::Tiny      ();
use Padre::Document ();
use Padre::Util     ();
use Padre::Perl     ();

our $VERSION = '0.43';
our @ISA     = 'Padre::Document';

#####################################################################
# Padre::Document::Perl Methods

# TODO watch out! These PPI methods may be VERY expensive!
# (Ballpark: Around 1 Gigahertz-second of *BLOCKING* CPU per 1000 lines)
# Check out Padre::Task::PPI and its subclasses instead!
sub ppi_get {
	my $self = shift;
	my $text = $self->text_get;
	require PPI::Document;
	PPI::Document->new( \$text );
}

sub ppi_set {
	my $self = shift;
	my $document = _INSTANCE( shift, 'PPI::Document' );
	unless ($document) {
		Carp::croak("Did not provide a PPI::Document");
	}

	# Serialize and overwrite the current text
	$self->text_set( $document->serialize );
}

sub ppi_find {
	shift->ppi_get->find(@_);
}

sub ppi_find_first {
	shift->ppi_get->find_first(@_);
}

sub ppi_transform {
	my $self = shift;
	my $transform = _INSTANCE( shift, 'PPI::Transform' );
	unless ($transform) {
		Carp::croak("Did not provide a PPI::Transform");
	}

	# Apply the transform to the document
	my $document = $self->ppi_get;
	unless ( $transform->document($document) ) {
		Carp::croak("Transform failed");
	}
	$self->ppi_set($document);

	return 1;
}

sub ppi_select {
	my $self     = shift;
	my $location = shift;
	my $editor   = $self->editor or return;
	my $start    = $self->ppi_location_to_character_position($location);
	$editor->SetSelection( $start, $start + 1 );
}

# Convert a ppi-style location [$line, $col, $apparent_col]
# to an absolute document offset
sub ppi_location_to_character_position {
	my $self     = shift;
	my $location = shift;
	if ( _INSTANCE( $location, 'PPI::Element' ) ) {
		$location = $location->location;
	}
	my $editor = $self->editor or return;
	my $line   = $editor->PositionFromLine( $location->[0] - 1 );
	my $start  = $line + $location->[1] - 1;
	return $start;
}

# Convert an absolute document offset to
# a ppi-style location [$line, $col, $apparent_col]
# FIXME: Doesn't handle $apparent_col right
sub character_position_to_ppi_location {
	my $self     = shift;
	my $position = shift;

	my $ed   = $self->editor;
	my $line = 1 + $ed->LineFromPosition($position);
	my $col  = 1 + $position - $ed->PositionFromLine( $line - 1 );

	return [ $line, $col, $col ];
}

sub set_highlighter {
	my $self   = shift;
	my $module = shift;

	# These are hard coded limits because the PPI highlighter
	# is slow. Probably there is not much use in moving this back to a
	# configuration variable
	my $limit;
	if ( $module eq 'Padre::Document::Perl::PPILexer' ) {
		$limit = 2000;
	} elsif ( $module eq 'Padre::Document::Perl::Lexer' ) {
		$limit = 2000;
	} elsif ( $module eq 'Padre::Plugin::Kate' ) {
		$limit = 2000;
	}

	my $length = $self->{original_content} ? length $self->{original_content} : 0;
	my $editor = $self->editor;
	if ($editor) {
		$length = $editor->GetTextLength;
	}

	Padre::Util::debug( "Setting highlighter for Perl 5 code. length: $length" . ( $limit ? " limit is $limit" : '' ) );

	if ( defined $limit and $length > $limit ) {
		Padre::Util::debug("Forcing STC highlighting");
		$module = 'stc';
	}
	return $self->SUPER::set_highlighter($module);
}


#####################################################################
# Padre::Document Document Analysis

my $keywords;

sub keywords {
	unless ( defined $keywords ) {
		$keywords = YAML::Tiny::LoadFile( Padre::Util::sharefile( 'languages', 'perl5', 'perl5.yml' ) );
	}
	return $keywords;
}

sub get_functions {
	my $self = shift;
	my $text = $self->text_get;

	# Filter out POD
	$text =~ s/(?:\015{1,2}\012|\015|\012)/\n/sg;
	$text =~ s/(\n)\n*__(?:DATA|END)__\b.*\z/$1/s;
	$text =~ s/\n\n=\w+.+?\n\n=cut\b.+?\n+/\n\n/sg;

	return $text =~ m/\n\s*sub\s+(\w+(?:::\w+)*)/g;
}

sub get_function_regex {

	# This emulates qr/(?<=^|[\012\015])sub\s$name\b/ but without
	# triggering a "Variable length lookbehind not implemented" error.
	return qr/(?:(?<=^)\s*sub\s+$_[1]|(?<=[\012\015])\s*sub\s+$_[1])\b/;
}

sub get_command {
	my $self  = shift;
	my $debug = shift;

	my $config = Padre->ide->config;

	# Use a temporary file if run_save is set to 'unsaved'
	my $filename =
		  $config->run_save eq 'unsaved' && !$self->is_saved
		? $self->store_in_tempfile
		: $self->filename;

	# Run with the same Perl that launched Padre
	# TODO: get preferred Perl from configuration
	my $perl = Padre::Perl::perl();

	# Set default arguments
	my %run_args = (
		interpreter => $config->run_interpreter_args_default,
		script      => $config->run_script_args_default,
	);

	# Overwrite default arguments with the ones preferred for given document
	foreach my $arg ( keys %run_args ) {
		my $type = "run_${arg}_args_" . File::Basename::fileparse($filename);
		$run_args{$arg} = Padre::DB::History->previous($type) if Padre::DB::History->previous($type);
	}

	my $dir = File::Basename::dirname($filename);
	chdir $dir;
	return $debug
		? qq{"$perl" -Mdiagnostics(-traceonly) $run_args{interpreter} "$filename" $run_args{script}}
		: qq{"$perl" $run_args{interpreter} "$filename" $run_args{script}};
}

sub pre_process {
	my $self = shift;

	if ( Padre->ide->config->editor_beginner ) {
		require Padre::Document::Perl::Beginner;
		my $b = Padre::Document::Perl::Beginner->new;
		if ( $b->check( $self->text_get ) ) {
			return 1;
		} else {
			$self->set_errstr( $b->error );
			return;
		}
	}

	return 1;
}

# Checks the syntax of a Perl document.
# Documented in Padre::Document!
# Implemented as a task. See Padre::Task::SyntaxChecker::Perl
sub check_syntax {
	my $self = shift;
	my %args = @_;
	$args{background} = 0;
	return $self->_check_syntax_internals( \%args );
}

sub check_syntax_in_background {
	my $self = shift;
	my %args = @_;
	$args{background} = 1;
	return $self->_check_syntax_internals( \%args );
}

sub _check_syntax_internals {
	my $self = shift;
	my $args = shift;
	my $text = $self->text_get;
	unless ( defined $text and $text ne '' ) {
		return [];
	}

	# Do we really need an update?
	require Digest::MD5;
	my $md5 = Digest::MD5::md5_hex( Encode::encode_utf8($text) );
	unless ( $args->{force} ) {
		if ( defined( $self->{last_syncheck_md5} )
			and $self->{last_syncheck_md5} eq $md5 )
		{
			return;
		}
	}
	$self->{last_syncheck_md5} = $md5;

	my $nlchar = $self->newline;

	# Obsoleted by ->newline
	#	if ( $self->get_newline_type eq 'WIN' ) {
	#		$nlchar = "\r\n";
	#	} elsif ( $self->get_newline_type eq 'MAC' ) {
	#		$nlchar = "\r";
	#	}
	#
	require Padre::Task::SyntaxChecker::Perl;
	my %check = (
		editor   => $self->editor,
		text     => $text,
		newlines => $nlchar,
	);
	if ( exists $args->{on_finish} ) {
		$check{on_finish} = $args->{on_finish};
	}
	if ( $self->project ) {
		$check{cwd}      = $self->project->root;
		$check{perl_cmd} = ['-Ilib'];
	}
	my $task = Padre::Task::SyntaxChecker::Perl->new(%check);
	if ( $args->{background} ) {

		# asynchroneous execution (see on_finish hook)
		$task->schedule;
		return ();
	} else {

		# serial execution, returning the result
		return () if $task->prepare() =~ /^break$/;
		$task->run();
		return $task->{syntax_check};
	}
}

sub get_outline {
	my $self = shift;
	my %args = @_;

	my $text = $self->text_get;
	unless ( defined $text and $text ne '' ) {
		return [];
	}

	# Do we really need an update?
	require Digest::MD5;
	my $md5 = Digest::MD5::md5_hex( Encode::encode_utf8($text) );
	unless ( $args{force} ) {
		if ( defined( $self->{last_outline_md5} )
			and $self->{last_outline_md5} eq $md5 )
		{
			return;
		}
	}
	$self->{last_outline_md5} = $md5;

	my %check = (
		editor => $self->editor,
		text   => $text,
	);
	if ( $self->project ) {
		$check{cwd}      = $self->project->root;
		$check{perl_cmd} = ['-Ilib'];
	}

	require Padre::Task::Outline::Perl;
	my $task = Padre::Task::Outline::Perl->new(%check);

	# asynchronous execution (see on_finish hook)
	$task->schedule;
	return;
}

sub comment_lines_str {
	return '#';
}

sub find_unmatched_brace {
	my ($self) = @_;

	# create a new object of the task class and schedule it
	require Padre::Task::PPI::FindUnmatchedBrace;
	Padre::Task::PPI::FindUnmatchedBrace->new(

		# for parsing
		text => $self->text_get,

		# will be available in "finish" but not in "run"/"process_ppi"
		document => $self,
	)->schedule;

	return ();
}

# finds the start of the current symbol.
# current symbol means in the context something remotely similar
# to what PPI considers a PPI::Token::Symbol, but since we're doing
# it the manual, stupid way, this may also work within quotelikes and regexes.
sub _get_current_symbol {
	my $editor = shift;
	my $pos    = shift;
	$pos = $editor->GetCurrentPos if not defined $pos;
	my $line         = $editor->LineFromPosition($pos);
	my $line_start   = $editor->PositionFromLine($line);
	my $line_end     = $editor->GetLineEndPosition($line);
	my $cursor_col   = $pos - $line_start;
	my $line_content = $editor->GetTextRange( $line_start, $line_end );
	$cursor_col = length($line_content) - 1 if $cursor_col >= length($line_content);
	my $col = $cursor_col;

	# find start of symbol TODO: This could be more robust, no?
	while (1) {
		if ( $col <= 0 or substr( $line_content, $col, 1 ) =~ /^[^#\w:\']$/ ) {
			last;
		}
		$col--;
	}

	return () if $col >= length($line_content);
	if ( substr( $line_content, $col + 1, 1 ) !~ /^[#\w:\']$/ ) {
		return ();
	}

	# Extract the token, too.
	my $token;
	if ( substr( $line_content, $col ) =~ /^\s?(\S+)/ ) {
		$token = $1;
	} else {
		die "This shouldn't happen. The algorithm is wrong";
	}

	# truncate token
	if ( $token =~ /^(\W*[\w:]+)/ ) {
		$token = $1;
	}

	# remove garbage first charactor from the token in case it's
	# not a variable (Example: ->foo becomes >foo but should be foo)
	$token =~ s/^[^\w\$\@\%\*\&:]//;

	return ( [ $line + 1, $col + 1 ], $token );
}

sub find_variable_declaration {
	my ($self) = @_;

	my ( $location, $token ) = _get_current_symbol( $self->editor );
	unless ( defined $location ) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a variable"),
			Wx::gettext("Check cancelled"),
			Wx::wxOK,
			Padre->ide->wx->main
		);
		return ();
	}

	# create a new object of the task class and schedule it
	require Padre::Task::PPI::FindVariableDeclaration;
	Padre::Task::PPI::FindVariableDeclaration->new(
		document => $self,
		location => $location,
	)->schedule;

	return ();
}

#####################################################################
# Padre::Document Document Manipulation

sub lexical_variable_replacement {
	my ( $self, $replacement ) = @_;

	my ( $location, $token ) = _get_current_symbol( $self->editor );
	if ( not defined $location ) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a variable"),
			Wx::gettext("Check cancelled"),
			Wx::wxOK,
			Padre->ide->wx->main
		);
		return ();
	}

	# create a new object of the task class and schedule it
	require Padre::Task::PPI::LexicalReplaceVariable;
	Padre::Task::PPI::LexicalReplaceVariable->new(
		document    => $self,
		location    => $location,
		replacement => $replacement,
	)->schedule;

	return ();
}

sub introduce_temporary_variable {
	my ( $self, $varname ) = @_;

	my $editor         = $self->editor;
	my $start_position = $editor->GetSelectionStart;
	my $end_position   = $editor->GetSelectionEnd - 1;

	# create a new object of the task class and schedule it
	require Padre::Task::PPI::IntroduceTemporaryVariable;
	Padre::Task::PPI::IntroduceTemporaryVariable->new(
		document       => $self,
		start_location => $start_position,
		end_location   => $end_position,
		varname        => $varname,
	)->schedule;

	return ();
}

sub autocomplete {
	my $self = shift;

	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);

	# line from beginning to current position
	my $prefix = $editor->GetTextRange( $first, $pos );

	# WARNING: This is totally not done, but Gabor made me commit it.
	# TODO:
	# a) complete this list
	# b) make the path configurable
	# c) make the whole thing optional and/or pluggable
	# d) make it not suck
	# e) make the types of auto-completion configurable
	# f) remove the old auto-comp code or at least let the user choose to use the new
	#    *or* the old code via configuration
	# g) hack STC so that we can get more information in the autocomp. window,
	# h) hack STC so we can start populating the autocompletion choices and continue to do so in the background
	# i) hack Perl::Tags to be better (including inheritance)
	# j) add inheritance support
	# k) figure out how to do method auto-comp. on objects
	require Parse::ExuberantCTags;

	# check for variables
	if ( $prefix =~ /([\$\@\%\*])(\w+(?:::\w+)*)$/ ) {
		my $prefix = $2;
		my $type   = $1;
		my $parser = Parse::ExuberantCTags->new( File::Spec->catfile( $ENV{PADRE_HOME}, 'perltags' ) );
		if ( defined $parser ) {
			my $tag = $parser->findTag( $prefix, partial => 1 );
			my @words;
			my %seen;
			while ( defined($tag) ) {

				# TODO check file scope?
				if ( !defined( $tag->{kind} ) ) {

					# This happens with some tagfiles which have no kind
				} elsif ( $tag->{kind} eq 'v' ) {

					# TODO potentially don't skip depending on circumstances.
					if ( not $seen{ $tag->{name} }++ ) {
						push @words, $tag->{name};
					}
				}
				$tag = $parser->findNextTag();
			}
			return ( length($prefix), @words );
		}
	}

	# check for hashs
	elsif ( $prefix =~ /(\$\w+(?:\-\>)?)\{([\'\"]?)([\$\&]?\w*)$/ ) {
		my $hashname   = $1;
		my $textmarker = $2;
		my $keyprefix  = $3;

		my $last = $editor->GetLength();
		my $text = $editor->GetTextRange( 0, $last );

		my %words;
		while ( $text =~ /\Q$hashname\E\{(([\'\"]?)\Q$keyprefix\E.+?\2)\}/g ) {
			$words{$1} = 1;
		}

		return (
			length( $textmarker . $keyprefix ),
			sort {
				my $a1 = $a;
				my $b1 = $b;
				$a1 =~ s/^([\'\"])(.+)\1/$2/;
				$b1 =~ s/^([\'\"])(.+)\1/$2/;
				$a1 cmp $b1;
				} ( keys(%words) )
		);

	}

	# check for methods
	elsif ( $prefix =~ /(?![\$\@\%\*])(\w+(?:::\w+)*)\s*->\s*(\w*)$/ ) {
		my $class  = $1;
		my $prefix = $2;
		$prefix = '' if not defined $prefix;
		my $parser = Parse::ExuberantCTags->new( File::Spec->catfile( $ENV{PADRE_HOME}, 'perltags' ) );
		if ( defined $parser ) {
			my $tag = ( $prefix eq '' ) ? $parser->firstTag() : $parser->findTag( $prefix, partial => 1 );
			my @words;

			# TODO: INHERITANCE!
			while ( defined($tag) ) {
				if ( !defined( $tag->{kind} ) ) {

					# This happens with some tagfiles which have no kind
				} elsif ( $tag->{kind} eq 's'
					and defined $tag->{extension}{class}
					and $tag->{extension}{class} eq $class )
				{
					push @words, $tag->{name};
				}
				$tag = ( $prefix eq '' ) ? $parser->nextTag() : $parser->findNextTag();
			}
			return ( length($prefix), @words );
		}
	}

	# check for packages
	elsif ( $prefix =~ /(?![\$\@\%\*])(\w+(?:::\w+)*)/ ) {
		my $prefix = $1;
		my $parser = Parse::ExuberantCTags->new( File::Spec->catfile( $ENV{PADRE_HOME}, 'perltags' ) );
		if ( defined $parser ) {
			my $tag = $parser->findTag( $prefix, partial => 1 );
			my @words;
			my %seen;
			while ( defined($tag) ) {

				# TODO check file scope?
				if ( !defined( $tag->{kind} ) ) {

					# This happens with some tagfiles which have no kind
				} elsif ( $tag->{kind} eq 'p' ) {

					# TODO potentially don't skip depending on circumstances.
					if ( not $seen{ $tag->{name} }++ ) {
						push @words, $tag->{name};
					}
				}
				$tag = $parser->findNextTag();
			}
			return ( length($prefix), @words );
		}
	}

	$prefix =~ s{^.*?((\w+::)*\w+)$}{$1};
	my $last      = $editor->GetLength();
	my $text      = $editor->GetTextRange( 0, $last );
	my $pre_text  = $editor->GetTextRange( 0, $first + length($prefix) );
	my $post_text = $editor->GetTextRange( $first, $last );

	my $regex;
	eval { $regex = qr{\b($prefix\w+(?:::\w+)*)\b} };
	if ($@) {
		return ("Cannot build regex for '$prefix'");
	}

	my %seen;
	my @words;
	push @words, grep { !$seen{$_}++ } reverse( $pre_text =~ /$regex/g );
	push @words, grep { !$seen{$_}++ } ( $post_text =~ /$regex/g );

	if ( @words > 20 ) {
		@words = @words[ 0 .. 19 ];
	}

	return ( length($prefix), @words );
}

sub newline_keep_column {
	my $self = shift;

	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);
	my $col    = $pos - $editor->PositionFromLine( $editor->LineFromPosition($pos) );

	$editor->AddText( $self->newline );
	print STDERR $self->get_newline_type . " " . length( $self->newline ) . "\n";

	$pos   = $editor->GetCurrentPos;
	$first = $editor->PositionFromLine( $editor->LineFromPosition($pos) );
	my $col2 = $pos - $first;
	$editor->AddText( ' ' x ( $col - $col2 ) );
	$editor->SetCurrentPos( $first + $col );

	return 1;
}

sub event_on_char {
	my ( $self, $editor, $event ) = @_;

	my $config = Padre->ide->config;

	$editor->Freeze;

	my $selection_exists = 0;
	my $text             = $editor->GetSelectedText;
	if ( defined($text) && length($text) > 0 ) {
		$selection_exists = 1;
	}

	my $key = $event->GetUnicodeKey;

	if ( Padre->ide->config->autocomplete_brackets ) {
		my %table = (
			34  => 34,  # " "
			39  => 39,  # ' '
			40  => 41,  # ( )
			60  => 62,  # < >
			91  => 93,  # [ ]
			123 => 125, # { }
		);
		my $pos = $editor->GetCurrentPos;
		if ( $table{$key} ) {
			if ($selection_exists) {
				my $start = $editor->GetSelectionStart;
				my $end   = $editor->GetSelectionEnd;
				$editor->GotoPos($end);
				$editor->AddText( chr( $table{$key} ) );
				$editor->GotoPos($start);
			} else {
				my $nextChar;
				if ( $editor->GetTextLength > $pos ) {
					$nextChar = $editor->GetTextRange( $pos, $pos + 1 );
				}
				unless ( defined($nextChar) && ord($nextChar) == $table{$key}
					and ( !$config->autocomplete_multiclosebracket ) )
				{
					$editor->AddText( chr( $table{$key} ) );
					$editor->CharLeft;
				}
			}
		}
	}

	$editor->Thaw;
	return;
}

# Our opportunity to implement a context-sensitive right-click menu
# This would be a lot more powerful if we used PPI, but since that would
# slow things down beyond recognition, we use heuristics for now.
sub event_on_right_down {
	my $self   = shift;
	my $editor = shift;
	my $menu   = shift;
	my $event  = shift;

	my $pos;
	if ( $event->isa("Wx::MouseEvent") ) {
		my $point = $event->GetPosition();
		$pos = $editor->PositionFromPoint($point);
	} else {

		# Fall back to the cursor position
		$editor->GetCurrentPos();
	}

	my $introduced_separator = 0;

	my ( $location, $token ) = _get_current_symbol( $self->editor, $pos );

	# Append variable specific menu items if it's a variable
	if ( defined $location and $token =~ /^[\$\*\@\%\&]/ ) {

		$menu->AppendSeparator if not $introduced_separator++;

		my $findDecl = $menu->Append( -1, Wx::gettext("Find Variable Declaration") );
		Wx::Event::EVT_MENU(
			$editor,
			$findDecl,
			sub {
				my $editor = shift;
				my $doc    = $self; # FIXME if Padre::Wx::Editor had a method to access its Document...
				return unless Params::Util::_INSTANCE( $doc, 'Padre::Document::Perl' );
				$doc->find_variable_declaration;
			},
		);

		my $lexRepl = $menu->Append( -1, Wx::gettext("Lexically Rename Variable") );
		Wx::Event::EVT_MENU(
			$editor, $lexRepl,
			sub {

				# FIXME near duplication of the code in Padre::Wx::Menu::Perl
				my $editor = shift;
				my $doc    = $self; # FIXME if Padre::Wx::Editor had a method to access its Document...
				return unless Params::Util::_INSTANCE( $doc, 'Padre::Document::Perl' );
				require Padre::Wx::History::TextEntryDialog;
				my $dialog = Padre::Wx::History::TextEntryDialog->new(
					$editor->main,
					Wx::gettext("Replacement"),
					Wx::gettext("Replacement"),
					'$foo',
				);
				return if $dialog->ShowModal == Wx::wxID_CANCEL;
				my $replacement = $dialog->GetValue;
				$dialog->Destroy;
				return unless defined $replacement;
				$doc->lexical_variable_replacement($replacement);
			},
		);
	} # end if it's a variable

	my $select_start = $editor->GetSelectionStart;
	my $select_end   = $editor->GetSelectionEnd;
	if ( $select_start != $select_end ) { # if something's selected
		$menu->AppendSeparator if not $introduced_separator++;

		my $intro_temp = $menu->Append( -1, Wx::gettext("Introduce Temporary Variable") );
		Wx::Event::EVT_MENU(
			$editor,
			$intro_temp,
			sub {

				# FIXME near duplication of the code in Padre::Wx::Menu::Perl
				my $editor = shift;
				my $doc    = $self;
				return unless _INSTANCE( $doc, 'Padre::Document::Perl' );
				require Padre::Wx::History::TextEntryDialog;
				my $dialog = Padre::Wx::History::TextEntryDialog->new(
					$editor->main,
					Wx::gettext("Variable Name"),
					Wx::gettext("Variable Name"),
					'$tmp',
				);
				return if $dialog->ShowModal == Wx::wxID_CANCEL;
				my $replacement = $dialog->GetValue;
				$dialog->Destroy;
				return unless defined $replacement;
				$doc->introduce_temporary_variable($replacement);
			},
		);
	} # end if something's selected
}

sub event_on_left_up {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;

	if ( $event->ControlDown ) {

		my $pos;
		if ( $event->isa("Wx::MouseEvent") ) {
			my $point = $event->GetPosition();
			$pos = $editor->PositionFromPoint($point);
		} else {

			# Fall back to the cursor position
			$editor->GetCurrentPos();
		}

		my ( $location, $token ) = _get_current_symbol( $self->editor, $pos );

		# Does it look like a variable?
		if ( defined $location and $token =~ /^[\$\*\@\%\&]/ ) {

			# FIXME editor document accessor?
			$editor->{Document}->find_variable_declaration();
		}

		# Does it look like a function?
		elsif ( defined $location ) {
			my ( $start, $end ) = Padre::Util::get_matches(
				$editor->GetText,
				$self->get_function_regex($token),
				$editor->GetSelection, # Provides two params
			);
			if ( defined $start ) {

				# Move the selection to the sub location
				$editor->goto_pos_centerize($start);
			}
		}
	} # end if control-click
}

#
# Render Perl 5 help xhtml for Padre's Help Search facility
#
sub on_help_render {
	my ( $self, $topic ) = @_;

	require Padre::DocBrowser::POD;
	
	my $pod = Padre::DocBrowser::POD->new;
	my $doc = $pod->resolve($topic);
	my $html = $pod->render($doc);
	return ($html->body,$topic);
}

#
# Render Perl 5 help list for Padre's Help Search facility
#
sub on_help_list {
	my @index = (
		'perlsyn',
		'perldata',
		'perlsub',
		'perlop',
		'perlfunc',
		'perlpod',
		'perlpodspec',
		'perldiag',
		'perllexwarn',
		'perldebug',
		'perlvar',
		'perlre',
		'perlreref',
		'perlref',
		'perlform',
		'perlobj',
		'perltie',
		'perldbmfilter',
		'perlipc',
		'perlfork',
		'perlnumber',
		'perlport',
		'perllocale',
		'perluniintro',
		'perlunicode',
		'perlebcdic',
		'perlsec',
		'perlmod',
		'perlmodlib',
		'perlmodstyle',
		'perlmodinstall',
		'perlnewmod',
		'perlcompile',
		'perlfilter',
		'perlglossary',
		'CORE',
	);
	return sort @index;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

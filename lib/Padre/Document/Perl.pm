package Padre::Document::Perl;

use 5.008;
use strict;
use warnings;

use Carp            ();
use Params::Util    '_INSTANCE';
use YAML::Tiny      ();
use Padre::Document ();
use Padre::Util     ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Document';





#####################################################################
# Padre::Document::Perl Methods

# TODO watch out! These PPI methods may be VERY expensive!
# (Ballpark: Around 1 second of *BLOCKING* CPU per 1000 lines)
# Check out Padre::Task::PPI and its subclasses instead!
sub ppi_get {
	my $self = shift;
	my $text = $self->text_get;
	require PPI::Document;
	PPI::Document->new( \$text );
}

sub ppi_set {
	my $self     = shift;
	my $document = _INSTANCE(shift, 'PPI::Document');
	unless ( $document ) {
		Carp::croak("Did not provide a PPI::Document");
	}

	# Serialize and overwrite the current text
	$self->text_set( $document->serialize );
}

sub ppi_find {
	my $self     = shift;
	my $document = $self->ppi_get;
	return $document->find( @_ );
}

sub ppi_find_first {
	my $self     = shift;
	my $document = $self->ppi_get;
	return $document->find_first( @_ );
}

sub ppi_transform {
	my $self      = shift;
	my $transform = _INSTANCE(shift, 'PPI::Transform');
	unless ( $transform ) {
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
	if ( _INSTANCE($location, 'PPI::Element') ) {
		$location = $location->location;
	}
	my $editor   = $self->editor or return;
	my $line     = $editor->PositionFromLine( $location->[0] - 1 );
	my $start    = $line + $location->[1] - 1;
	$editor->SetSelection( $start, $start + 1 );
}

my $keywords;

sub keywords {
	unless ( defined $keywords ) {
		$keywords = YAML::Tiny::LoadFile(
			Padre::Util::sharefile( 'languages', 'perl5', 'perl5.yml' )
		);
	}
	return $keywords;
}

sub get_functions {
	my $self = shift;
	my $text = $self->text_get;
	return $text =~ m{^sub\s+(\w+(?:::\w+)*)}gm;
}

sub get_function_regex {
	my ( $self, $sub ) = @_;
	return qr{(^|\n)sub\s+$sub\b};
}

sub get_command {
	my $self     = shift;

	# Check the file name
	my $filename = $self->filename;
#	unless ( $filename and $filename =~ /\.pl$/i ) {
#		die "Only .pl files can be executed\n";
#	}

	# Run with the same Perl that launched Padre
	# TODO: get preferred Perl from configuration
	my $perl = Padre->perl_interpreter;

	my $dir = File::Basename::dirname($filename);
	chdir $dir;
	return qq{"$perl" "$filename"};
}

sub colorize {
	my ($self) = @_;
	
	$self->remove_color;

	my $editor = $self->editor;
	my $text   = $self->text_get;

	require PPI::Document;
	my $ppi_doc = PPI::Document->new( \$text );
	if (not defined $ppi_doc) {
		Wx::LogMessage( 'PPI::Document Error %s', PPI::Document->errstr );
		Wx::LogMessage( 'Original text: %s', $text );
		return;
	}

	my %colors = (
		keyword         => 4, # dark green
		structure       => 6,
		core            => 1, # red
		pragma          => 7, # purple
		'Whitespace'    => 0,
		'Structure'     => 0,

		'Number'        => 1,
		'Float'         => 1,

		'HereDoc'       => 4,
		'Data'          => 4,
		'Operator'      => 6,
		'Comment'       => 2, # it's good, it's green
		'Pod'           => 2,
		'End'           => 2,
		'Label'         => 0,
		'Word'          => 0, # stay the black
		'Quote'         => 9,
		'Single'        => 9,
		'Double'        => 9,
		'Interpolate'   => 9,
		'QuoteLike'     => 7,
		'Regexp'        => 7,
		'Words'         => 7,
		'Readline'      => 7,
		'Match'         => 3,
		'Substitute'    => 5,
		'Transliterate' => 5,
		'Separator'     => 0,
		'Symbol'        => 0,
		'Prototype'     => 0,
		'ArrayIndex'    => 0,
		'Cast'          => 0,
		'Magic'         => 0,
    );

	my @tokens = $ppi_doc->tokens;
	$ppi_doc->index_locations;
	my $first = $editor->GetFirstVisibleLine();
	my $lines = $editor->LinesOnScreen();
	#print "First $first lines $lines\n";
	foreach my $t (@tokens) {
		#print $t->content;
		my ($row, $rowchar, $col) = @{ $t->location };
#		next if $row < $first;
#		next if $row > $first + $lines;
		my $css = $self->_css_class($t);
#		if ($row > $first and $row < $first + 5) {
#			print "$row, $rowchar, ", $t->length, "  ", $t->class, "  ", $css, "  ", $t->content, "\n";
#		}
#		last if $row > 10;
		my $color = $colors{$css};
		if (not defined $color) {
			Wx::LogMessage("Missing definition fir '$css'\n");
			next;
		}
		next if not $color;

		my $start  = $editor->PositionFromLine($row-1) + $rowchar-1;
		my $len = $t->length;

		$editor->StartStyling($start, $color);
		$editor->SetStyling($len, $color);
	}
}

sub _css_class {
	my ($self, $Token) = @_;
	if ( $Token->isa('PPI::Token::Word') ) {
		# There are some words we can be very confident are
		# being used as keywords
		unless ( $Token->snext_sibling and $Token->snext_sibling->content eq '=>' ) {
			if ( $Token->content =~ /^(?:sub|return)$/ ) {
				return 'keyword';
			} elsif ( $Token->content =~ /^(?:undef|shift|defined|bless)$/ ) {
				return 'core';
			}
		}
		
		if ( $Token->previous_sibling and $Token->previous_sibling->content eq '->' ) {
			if ( $Token->content =~ /^(?:new)$/ ) {
				return 'core';
			}
		}

		if ( $Token->parent->isa('PPI::Statement::Include') ) {
			if ( $Token->content =~ /^(?:use|no)$/ ) {
				return 'keyword';
			}
			if ( $Token->content eq $Token->parent->pragma ) {
				return 'pragma';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Variable') ) {
			if ( $Token->content =~ /^(?:my|local|our)$/ ) {
				return 'keyword';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Compond') ) {
			if ( $Token->content =~ /^(?:if|else|elsif|unless|for|foreach|while|my)$/ ) {
				return 'keyword';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Package') ) {
			if ( $Token->content eq 'package' ) {
				return 'keyword';
			}
		} elsif ( $Token->parent->isa('PPI::Statement::Scheduled') ) {
			return 'keyword';
		}
	}

	# Normal coloring
	my $css = ref $Token;
	$css =~ s/^.+:://;
	$css;
}

# Checks the syntax of a Perl document.
# Documented in Padre::Document!
sub check_syntax {
	my $self  = shift;
	my %args  = @_;

	my $text = $self->text_get;
	unless ( defined $text and $text ne '' ) {
		return [];
	}

	require Digest::MD5;
	my $md5 = Digest::MD5::md5($text);
	unless ( $args{force} ) {
		if ( defined( $self->{last_checked_md5} )
		     && $self->{last_checked_md5} eq $md5
		) {
			return;
		}
	}
	$self->{last_checked_md5} = $md5;

	# Execute the syntax check
	my $stderr = '';
	SCOPE: {
		require File::Temp;
		my $file = File::Temp->new;
		$file->print( $text );
		$file->close;
		require IPC::Run3;
		my @cmd = (
			Padre->perl_interpreter,
			'-Mdiagnostics',
			'-c',
			$file->filename,
		);
		IPC::Run3::run3( \@cmd, \undef, \undef, \$stderr );
	}

	# Don't really know where that comes from...
	my $i = index( $stderr, 'Uncaught exception from user code' );
	if ( $i > 0 ) {
		$stderr = substr( $stderr, 0, $i );
	}

	# Handle the "no errors or warnings" case
	if ( $stderr =~ /^\s+syntax OK\s+$/s ) {
		return [];
	}

	# Split into message paragraphs
	$stderr =~ s/\n\n/\n/go;
	$stderr =~ s/\n\s/\x1F /go;
	my @messages = split(/\n/, $stderr);

	my $issues = [];
	my @diag   = ();
	foreach my $message ( @messages ) {
		if (   index( $message, 'has too many errors' )    > 0
			or index( $message, 'had compilation errors' ) > 0
			or index( $message, 'syntax OK' ) > 0
		) {
			last;
		}

		my $cur = {};
		my $tmp = '';

		if ( $message =~ s/\s\(\#(\d+)\)\s*\Z//o ) {
			$cur->{diag} = $1 - 1;
		}

		if ( $message =~ m/\)\s*\Z/o ) {
			my $pos = rindex( $message, '(' );
			$tmp = substr( $message, $pos, length($message) - $pos, '' );
		}

		if ( $message =~ s/\s\(\#(\d+)\)(.+)//o ) {
			$cur->{diag} = $1 - 1;
			my $diagtext = $2;
			$diagtext =~ s/\x1F//go;
			push @diag, join( ' ', split( ' ', $diagtext ) );
		}

		if ( $message =~ s/\sat(?:\s|\x1F)+.+?(?:\s|\x1F)line(?:\s|\x1F)(\d+)//o ) {
			$cur->{line} = $1;
			$cur->{msg}  = $message;
		}

		if ($tmp) {
			$cur->{msg} .= "\n" . $tmp;
		}

		if (defined $cur->{msg}) {
			$cur->{msg} =~ s/\x1F/\n/go;
		}

		if ( defined $cur->{diag} ) {
			$cur->{desc} = $diag[ $cur->{diag} ];
			delete $cur->{diag};
		}
		if (   defined( $cur->{desc} )
			&& $cur->{desc} =~ /^\s*\([WD]/o
		) {
			$cur->{severity} = 'W';
		}
		else {
			$cur->{severity} = 'E';
		}
		delete $cur->{desc};

		push @{$issues}, $cur;
	}

	return $issues;
}

sub comment_lines_str { return '#' }

sub find_unmatched_brace {
	my ($self) = @_;

	# create a new object of the task class and schedule it
	Padre::Task::PPI::FindUnmatchedBrace->new(
		# for parsing
		text     => $self->text_get,
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
	my $pos          = $editor->GetCurrentPos;
	my $line         = $editor->LineFromPosition($pos);
	my $line_start   = $editor->PositionFromLine($line);
	my $cursor_col   = $pos-$line_start; # TODO: let's hope this is the physical column
	my $line_end     = $editor->GetLineEndPosition($line);
	my $line_content = $editor->GetTextRange($line_start, $line_end);
	my $col          = $cursor_col;
        
	# find start of symbol TODO: This could be more robust, no?
	while (1) {
		if ($col == 0 or substr($line_content, $col, 1) =~ /^[^\w:\']$/) {
			last;
		}
		$col--;
	}

	if ( $col == 0 or substr($line_content, $col+1, 1) !~ /^[\w:\']$/ ) {
		return ();
	}
	return [$line+1, $col+1];
}

sub find_variable_declaration {
	my ($self) = @_;

	my $location = _get_current_symbol($self->editor);
	unless ( defined $location ) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a variable"),
			Wx::gettext("Check cancelled"),
			Wx::wxOK,
			Padre->ide->wx->main_window
		);
		return ();
	}

	# create a new object of the task class and schedule it
	Padre::Task::PPI::FindVariableDeclaration->new(
		document => $self,
		location => $location,
	)->schedule;

	return ();
}

sub lexical_variable_replacement {
	my ($self, $replacement) = @_;

	my $location = _get_current_symbol($self->editor);
	if (not defined $location) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a variable"),
			Wx::gettext("Check cancelled"),
			Wx::wxOK,
			Padre->ide->wx->main_window
		);
		return ();
	}
	# create a new object of the task class and schedule it
	Padre::Task::PPI::LexicalReplaceVariable->new(
		document => $self,
		location => $location,
                replacement => $replacement,
	)->schedule;

	return ();
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

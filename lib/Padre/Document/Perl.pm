package Padre::Document::Perl;

use 5.008;
use strict;
use warnings;
use Carp              ();
use Encode            ();
use File::Spec        ();
use File::Basename    ();
use Params::Util      ();
use YAML::Tiny        ();
use Padre::Util       ();
use Padre::Perl       ();
use Padre::Document   ();
use Padre::File       ();
use Padre::Role::Task ();
use Padre::Feature    ();
use Padre::Logger;

our $VERSION    = '0.94';
our $COMPATIBLE = '0.93';
our @ISA        = qw{
	Padre::Role::Task
	Padre::Document
};





#####################################################################
# Padre::Document Task Integration

sub task_functions {
	return 'Padre::Document::Perl::FunctionList';
}

sub task_outline {
	return 'Padre::Document::Perl::Outline';
}

sub task_syntax {
	return 'Padre::Document::Perl::Syntax';
}





#####################################################################
# Padre::Document::Perl Methods

# Ticket #637:
# TO DO watch out! These PPI methods may be VERY expensive!
# (Ballpark: Around 1 Gigahertz-second of *BLOCKING* CPU per 1000 lines)
# Check out Padre::Task::PPI and children instead!
sub ppi_get {
	require PPI::Document;
	my $self = shift;
	my $text = $self->text_get;
	PPI::Document->new( \$text );
}

sub ppi_dump {
	require PPI::Dumper;
	my $self = shift;
	my $ppi  = $self->ppi_get;
	PPI::Dumper->new( $ppi, locations => 1, indent => 4 )->string;
}

sub ppi_set {
	my $self     = shift;
	my $document = Params::Util::_INSTANCE( shift, 'PPI::Document' );
	unless ($document) {
		Carp::croak('Did not provide a PPI::Document');
	}

	# Serialize and overwrite the current text
	$self->text_set( $document->serialize );
}

sub ppi_replace {
	my $self     = shift;
	my $document = Params::Util::_INSTANCE( shift, 'PPI::Document' );
	unless ($document) {
		Carp::croak('Did not provide a PPI::Document');
	}

	# Serialize and overwrite the current text
	$self->text_replace( $document->serialize );	
}

sub ppi_find {
	shift->ppi_get->find(@_);
}

sub ppi_find_first {
	shift->ppi_get->find_first(@_);
}

sub ppi_transform {
	my $self = shift;
	my $transform = Params::Util::_INSTANCE( shift, 'PPI::Transform' );
	unless ($transform) {
		Carp::croak("Did not provide a PPI::Transform");
	}

	# Apply the transform to the document
	my $document = $self->ppi_get;
	unless ( $transform->document($document) ) {
		Carp::croak("Transform failed");
	}
	$self->ppi_replace($document);

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
	if ( Params::Util::_INSTANCE( $location, 'PPI::Element' ) ) {
		$location = $location->location;
	}
	my $editor = $self->editor or return;
	my $line   = $editor->PositionFromLine( $location->[0] - 1 );
	my $start  = $line + $location->[1] - 1;
	return $start;
}

# Convert an absolute document offset to
# a ppi-style location [$line, $col, $apparent_col]
# FIX ME: Doesn't handle $apparent_col right
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
		$limit = $self->config->lang_perl5_lexer_ppi_limit;
	} elsif ( $module eq 'Padre::Document::Perl::Lexer' ) {
		$limit = 4000;
	} elsif ( $module eq 'Padre::Plugin::Kate' ) {
		$limit = 4000;
	}

	my $length = $self->{original_content} ? length $self->{original_content} : 0;
	my $editor = $self->editor;
	if ($editor) {
		$length = $editor->GetTextLength;
	}

	TRACE( "Setting highlighter for Perl 5 code. length: $length" . ( $limit ? " limit is $limit" : '' ) ) if DEBUG;

	if ( defined $limit and $length > $limit ) {
		TRACE("Forcing STC highlighting") if DEBUG;
		$module = '';
	}

	return $self->SUPER::set_highlighter($module);
}





#####################################################################
# Padre::Document Document Analysis

sub guess_filename {
	my $self = shift;

	# Don't attempt a content-based guess if the file already has a name.
	if ( $self->filename ) {
		return $self->SUPER::guess_filename;
	}

	my $text    = $self->text_get;
	my $project = $self->project;

	# Is this a test?
	if ( $text =~ /(?:use Test::|plan \=\>)/ ) {
		my $fn = eval {
			die unless defined($project);

			my $t_path = File::Spec->catfile( $project->root, 't' );

			die unless -d $t_path;

			opendir my $t_dh, $t_path or die;
			my %t_num;
			my $nulls = 1; # default
			for ( readdir($t_dh) ) {
				next unless /^(\d+)/;

				# Convert 1, 01 and 001 to 1 and mark the number as used:
				$t_num{ $1 + 0 } = 1;
				$nulls = length($1);
			}

			my $free_num = 0;
			while ( $t_num{ ++$free_num } ) { }

			my $t_format = '%0' . $nulls . 'd';

			# Return filename relative to project
			return sprintf( $t_format, $free_num ) . '_unnamed.t';

		};

		return 'unnamed_test.t' if $@;
		warn $fn;
		return $fn if defined($fn);
	}

	# Is this a script?
	if ( $text =~ /^\#\![^\n]*\bperl\b/s ) {

		# It's impossible to predict the name of a script in
		# advance, but lets default to a standard "script.pl"
		return 'script.pl';
	}

	# Is this a module
	if ( $text =~ /\bpackage\s*([\w\:]+)/s ) {

		# Take the last section of the package name, and use that
		# as the file.
		my $name = $1;
		$name =~ s/.*\://;
		return "$name.pm";
	}

	# Otherwise, no idea
	return undef;
}

sub guess_subpath {
	my $self = shift;

	# Don't attempt a content-based guess if the file already has a name.
	if ( $self->filename ) {
		return $self->SUPER::guess_subpath;
	}

	my $text = $self->text_get;

	# Is this a test?
	if ( $text =~ /(?:use Test::|plan \=\>)/ ) {
		return 't';
	}

	# Is this a script?
	if ( $text =~ /^\#\![^\n]*\bperl\b/s ) {

		return 'script';
	}

	# Is this a module?
	if ( $text =~ /\bpackage\s*([\w\:]+)/s ) {

		# Take all but the last section of the package name,
		# and use that as the file.
		my $name = $1;
		my @dirs = split /::/, $name;
		pop @dirs;

		# The use of a module name beginning with t:: is a common
		# pattern for declaring test-only classes.
		if ( $dirs[0] and $dirs[0] eq 't' ) {
			return @dirs;
		}

		return ( 'lib', @dirs );
	}

	# Otherwise, no idea
	return;
}

my $keywords;

sub get_calltip_keywords {
	$keywords
		or $keywords = YAML::Tiny::LoadFile( Padre::Util::sharefile( 'languages', 'perl5', 'perl5.yml' ) );
}

my $wordchars = join '', '$@%&_:[]{}', 0 .. 9, 'A' .. 'Z', 'a' .. 'z';

sub scintilla_word_chars {
	return $wordchars;
}

# This emulates qr/(?<=^|[\012\015])sub\s$name\b/ but without
# triggering a "Variable length lookbehind not implemented" error.
# return qr/(?:(?<=^)\s*sub\s+$_[1]|(?<=[\012\015])\s*sub\s+$_[1])\b/;
sub get_function_regex {
	my $name = quotemeta $_[1];
	return qr/(?:^|[^# \t-])[ \t]*((?:sub|func|method)\s+$name\b|\*$name\s*=\s*(?:sub\b|\\\&))/;
}

=pod

=head2 get_command

Returns the full command (interpreter, file name (maybe temporary) and arguments
for both of them) for running the current document.

Optionally accepts a hash reference with the following boolean arguments:
  'debug' - return a command where the debugger is started
  'trace' - activates diagnostic output

=cut

sub get_command {
	my $self    = shift;
	my $arg_ref = shift || {};
	my $debug   = exists $arg_ref->{debug} ? $arg_ref->{debug} : 0;
	my $trace   = exists $arg_ref->{trace} ? $arg_ref->{trace} : 0;
	my $config  = $self->config;

	# Use a temporary file if run_save is set to 'unsaved'
	my $filename =
		  $config->run_save eq 'unsaved' && !$self->is_saved
		? $self->store_in_tempfile
		: $self->filename;

	# Run with console Perl to prevent unexpected results under wxperl
	# The configuration values is cheaper to get compared to cperl(),
	# try it first.
	my $perl = $self->get_interpreter;

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

	# (Ticket #530) Pack args here, because adding the space later confuses the called Perls @ARGV
	my $script_args = '';
	$script_args = ' ' . $run_args{script} if defined( $run_args{script} ) and ( $run_args{script} ne '' );

	my $dir = File::Basename::dirname($filename);
	chdir $dir;
	my $shortname = File::Basename::basename($filename);

	my @commands = (qq{"$perl"});
	push @commands, '-d' if $debug;
	push @commands, '-Mdiagnostics(-traceonly)' if $trace;
	if (Padre::Feature::DEVEL_ENDSTATS) {
		my $devel_endstats_options = $config->feature_devel_endstats_options;
		push @commands, '-MDevel::EndStats' . ( $devel_endstats_options ne '' ? "=$devel_endstats_options" : '' );
	}
	if (Padre::Feature::DEVEL_TRACEUSE) {
		my $devel_traceuse_options = $config->feature_devel_traceuse_options;
		push @commands, '-d:TraceUse' . ( $devel_traceuse_options ne '' ? "=$devel_traceuse_options" : '' );
	}
	push @commands, "$run_args{interpreter}";
	if (Padre::Constant::WIN32) {
		push @commands, qq{"$shortname"$script_args};
	} else {

		# Use single quote to allow spaces in the shortname of the file #1219
		push @commands, qq{'$shortname'$script_args};
	}
	return join ' ', @commands;
}

=head2 get_inc

Returns the @INC of the designated perl interpreter - not necessarily our own

=cut

my %inc;

sub get_inc {
	my $self = shift;
	my $perl = $self->get_interpreter or return;

	unless ( $inc{$perl} ) {
		my $incs = qx{$perl -e "print join ';', \@INC"};
		chomp $incs;
		$inc{$perl} = [ split /;/, $incs ];
	}

	return @{ $inc{$perl} };
}

=head2 get_interpreter

Returns the Perl interpreter for running the current document.

=cut

sub get_interpreter {
	my $self    = shift;
	my $arg_ref = shift || {};
	my $debug   = exists $arg_ref->{debug} ? $arg_ref->{debug} : 0;
	my $trace   = exists $arg_ref->{trace} ? $arg_ref->{trace} : 0;
	my $config  = $self->config;

	# The configuration value is cheaper to get compared to cperl(),
	# try it first.
	my $perl = $config->run_perl_cmd;

	# warn if the Perl interpreter is not executable
	if ( defined $perl and $perl ne '' ) {
		if ( !-x $perl ) {
			Padre->ide->wx->main->message(
				Wx::gettext(
					sprintf(
						'%s seems to be no executable Perl interpreter, using the system default perl instead.', $perl
					)
				),
			);
			$perl = Padre::Perl::cperl();
		}
	} else {
		$perl = Padre::Perl::cperl();
	}

	return $perl;
}

sub pre_process {
	my $self = shift;

	if ( Padre->ide->config->lang_perl5_beginner ) {
		require Padre::Document::Perl::Beginner;
		my $b = Padre::Document::Perl::Beginner->new( document => $self );
		if ( $b->check( $self->text_get ) ) {
			return 1;
		} else {
			$self->set_errstr( $b->error );
			return;
		}
	}

	return 1;
}

=pod

=head2 beginner_check

Run the beginner error checks on the current document.

Shows a pop-up message for the first error.

Always returns 1 (true).

=cut

# Run the checks for common beginner errors
sub beginner_check {
	my $self = shift;

	# TO DO: Make this cool
	# It isn't, because it should show _all_ warnings instead of one and
	# it should at least go to the line it's complaining about.
	# Ticket #534

	require Padre::Document::Perl::Beginner;
	my $beginner = Padre::Document::Perl::Beginner->new(
		document => $self,
		editor   => $self->editor
	);
	$beginner->check( $self->text_get );

	# Report any errors
	my $error = $beginner->error;
	if ($error) {
		$self->current->main->error( Wx::gettext('Error: ') . $error );
	} else {
		$self->current->main->message( Wx::gettext('No errors found.') );
	}

	return 1;
}

sub find_unmatched_brace {
	TRACE("find_unmatched_brace") if DEBUG;
	my $self = shift;

	# Fire the task
	$self->task_request(
		task      => 'Padre::Task::FindUnmatchedBrace',
		document  => $self,
		on_finish => 'find_unmatched_brace_response',
	);

	return;
}

sub find_unmatched_brace_response {
	TRACE("find_unmatched_brace_response") if DEBUG;
	my $self = shift;
	my $task = shift;

	# Found what we were looking for
	if ( $task->{location} ) {
		$self->ppi_select( $task->{location} );
		return;
	}

	# Must have been a clean result
	# TO DO: Convert this to a call to ->main that doesn't require
	# us to use Wx directly.
	Wx::MessageBox(
		Wx::gettext("All braces appear to be matched"),
		Wx::gettext("Check Complete"),
		Wx::OK,
		$self->current->main,
	);
}

# finds the start of the current symbol.
# current symbol means in the context something remotely similar
# to what PPI considers a PPI::Token::Symbol, but since we're doing
# it the manual, stupid way, this may also work within quotelikes and regexes.
sub get_current_symbol {
	my $self   = shift;
	my $pos    = shift;
	my $editor = $self->editor;
	$pos = $editor->GetCurrentPos if not defined $pos;

	my $line       = $editor->LineFromPosition($pos);
	my $line_start = $editor->PositionFromLine($line);
	my $line_end   = $editor->GetLineEndPosition($line);

	my $cursor_col = $pos - $line_start;
	my $line_content = $editor->GetTextRange( $line_start, $line_end );
	$cursor_col = length($line_content) - 1 if $cursor_col >= length($line_content);
	my $col              = $cursor_col;
	my $symbol_start_pos = $pos;

	# find start of symbol
	# TO DO: This could be more robust, no?
	# Ticket #639
	# if we are at the end of a symbol (maybe we need better detection?), start counting on the previous letter. this should resolve #419 and #654
	$col-- if $col and substr( $line_content, $col - 1, 2 ) =~ /^\w\W$/;
	while (1) {
		last if $col <= 0 or substr( $line_content, $col, 1 ) =~ /^[^#\w:\']$/;
		$col--;
		$symbol_start_pos--;
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

	# remove garbage first character from the token in case it's
	# not a variable (Example: ->foo becomes >foo but should be foo)
	$token =~ s/^[^\w\$\@\%\*\&:]//;

	return ( [ $line + 1, $col + 1, $symbol_start_pos + 1 ], $token );
}

sub find_variable_declaration {
	my $self = shift;

	my ( $location, $token ) = $self->get_current_symbol;
	unless ( defined $location ) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a variable"),
			Wx::gettext("Check cancelled"),
			Wx::OK,
			$self->current->main,
		);
		return;
	}

	# Create a new object of the task class and schedule it
	$self->task_request(
		task      => 'Padre::Task::FindVariableDeclaration',
		document  => $self,
		location  => $location,
		on_finish => 'find_variable_declaration_response',
	);

	return;
}

sub find_variable_declaration_response {
	my $self = shift;
	my $task = shift;

	# Found what we were looking for
	if ( $task->{location} ) {
		$self->ppi_select( $task->{location} );
		return;
	}

	# Couldn't find the variable declaration.
	# TO DO: Convert this to a call to ->main that doesn't require
	# us to use Wx directly.
	my $text;
	if ( $self->{error} =~ /no token/ ) {
		$text = Wx::gettext("Current cursor does not seem to point at a variable");
	} elsif ( $self->{error} =~ /no declaration/ ) {
		$text = Wx::gettext("No declaration could be found for the specified (lexical?) variable");
	} else {
		$text = Wx::gettext("Unknown error");
	}
	Wx::MessageBox(
		$text,
		Wx::gettext("Search Canceled"),
		Wx::OK,
		$self->current->main,
	);
}

sub find_method_declaration {
	my $self   = shift;
	my $main   = $self->current->main;
	my $editor = $self->editor;

	my ( $location, $token ) = $self->get_current_symbol;
	unless ( defined $location ) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a method"),
			Wx::gettext("Check cancelled"),
			Wx::OK,
			$main
		);
		return ();
	}

	# Try to extract class methods' class name
	my $line         = $location->[0] - 1;
	my $col          = $location->[1] - 1;
	my $line_start   = $editor->PositionFromLine($line);
	my $token_end    = $line_start + $col + 1 + length($token);
	my $line_content = $editor->GetTextRange( $line_start, $token_end );
	my ($class) = $line_content =~ /(?:^|[^\w:\$])(\w+(?:::\w+)*)\s*->\s*\Q$token\E$/;

	my ( $found, $filename ) = $self->_find_method( $token, $class );
	unless ($found) {
		Wx::MessageBox(
			sprintf( Wx::gettext("Current '%s' not found"), $token ),
			Wx::gettext("Check cancelled"),
			Wx::OK,
			$main
		);
		return;
	}

	require Padre::Wx::Dialog::Positions;
	Padre::Wx::Dialog::Positions->set_position;

	# Go to function in current file
	unless ($filename) {
		$editor->goto_function($token);
		return ();
	}

	# Open or switch to file
	my $id = $main->editor_of_file($filename);
	unless ( defined $id ) {
		$id = $main->setup_editor($filename);
	}
	return unless defined $id;

	SCOPE: {
		my $editor = $main->notebook->GetPage($id) or return;
		$editor->goto_function($token);
	}

	return ();
}

# Arguments: A method name, optionally a class name
# Returns: Success-Bit, Filename
sub _find_method {
	my $self  = shift;
	my $name  = shift;
	my $class = shift;

	# Use tags parser if it's configured, return a match
	my $parser = $self->perltags_parser;
	if ( defined($parser) ) {
		my $tag = $parser->findTag($name);

		# Try to match tag AND class first
		if ( defined $class ) {
			while (1) {
				last if not defined $tag;
				next
					if not defined $tag->{extension}{class}
						or not $tag->{extension}{class} eq $class;
				last;
			} continue {
				$tag = $parser->findNextTag;
			}

			# fall back to the first method name match (bad idea?)
			$tag = $parser->findTag($name)
				if not defined $tag;
		}

		return ( 1, $tag->{file} ) if defined $tag;
	}

	# Fallback: Search for methods in source
	# TO DO: unify with code in Padre::Wx::FunctionList
	# TO DO: lots of improvement needed here
	unless ( $self->{_methods_}->{$name} ) {

		# Consume the basic function list
		my $filename = $self->filename;
		$self->{_methods_}->{$_} = $filename foreach $self->functions;

		# Scan for declarations in all module files.
		# TODO: This is horrendously slow to be running in the foreground.
		# TODO: This is pretty crude and doesn't integrate with the project system.
		my $project = $self->project;
		if ($project) {
			require File::Find::Rule;
			my @files = File::Find::Rule->file->name('*.pm')->in( File::Spec->catfile( $project->root, 'lib' ) );
			foreach my $f (@files) {
				if ( open my $fh, '<', $f ) {
					my $lines = do { local $/ = undef; <$fh> };
					close $fh;
					my @subs = $lines =~ /sub\s+(\w+)/g;
					if ( $lines =~ /use MooseX::Declare;/ ) {
						push @subs, ( $lines =~ /\bmethod\s+(\w+)/g );
					}

					if ( $lines =~ /use (?:MooseX::)?Method::Signatures;/ ) {
						my @subs = $lines =~ /\b(?:method|func)\s+(\w+)/g;
					}

					$self->{_methods_}->{$_} = $f for @subs;
				}
			}

		}
	}

	if ( $self->{_methods_}{$name} ) {
		return ( 1, $self->{_methods_}{$name} );
	}

	return;
}





#####################################################################
# Padre::Document Document Manipulation

sub rename_variable {
	my $self = shift;

	# Can we find something to replace?
	my ( $location, $token ) = $self->get_current_symbol;
	if ( not defined $location ) {
		Wx::MessageBox(
			Wx::gettext('Current cursor does not seem to point at a variable.'),
			Wx::gettext('Rename variable'),
			Wx::OK,
			$self->current->main,
		);
		return;
	}

	my $dialog = Wx::TextEntryDialog->new(
		$self->current->main,
		Wx::gettext('New name'),
		Wx::gettext('Rename variable'),
		$token,
	);
	return if $dialog->ShowModal == Wx::ID_CANCEL;
	my $replacement = $dialog->GetValue;
	$dialog->Destroy;

	# Launch the background task
	$self->task_request(
		task        => 'Padre::Task::LexicalReplaceVariable',
		document    => $self,
		location    => $location,
		replacement => $replacement,
		on_finish   => 'rename_variable_response',
	);

	return;
}

sub change_variable_style {
	my $self = shift;
	my %opt  = @_;
	if ( 0 == grep { defined $_ } @opt{qw(to_camel_case from_camel_case)} ) {
		warn "Need either 'to_camel_case' or 'from_camel_case' options";
		return;
	} elsif (
		2 == grep {
			defined $_
		} @opt{qw(to_camel_case from_camel_case)}
		)
	{
		warn "Need either 'to_camel_case' or 'from_camel_case' options, not both";
		return;
	}

	# Can we find something to replace?
	my ( $location, $token ) = $self->get_current_symbol;
	if ( not defined $location ) {
		Wx::MessageBox(
			Wx::gettext('Current cursor does not seem to point at a variable.'),
			Wx::gettext('Variable case change'),
			Wx::OK,
			$self->current->main,
		);
		return;
	}

	# Launch the background task
	$self->task_request(
		%opt, # should contain only keys to_camel_case or from_camel_case and optionally ucfirst
		task      => 'Padre::Task::LexicalReplaceVariable',
		document  => $self,
		location  => $location,
		on_finish => 'rename_variable_response',
	);

	return;
}

sub rename_variable_response {
	my $self = shift;
	my $task = shift;

	if ( defined $task->{munged} ) {

		# GUI update
		# TO DO: What if the document changed? Bad luck for now.
		$self->editor->SetText( $task->{munged} );
		$self->ppi_select( $task->{location} );
		return;
	}

	# Explain why it didn't work
	my $text;
	my $error = $self->{error} || '';
	if ( $error =~ /no token/ ) {
		$text = Wx::gettext("Current cursor does not seem to point at a variable.");
	} elsif ( $error =~ /no declaration/ ) {
		$text = Wx::gettext("No declaration could be found for the specified (lexical?) variable.");
	} else {
		$text = Wx::gettext("Unknown error") . "\n$error";
	}
	Wx::MessageBox(
		$text,
		Wx::gettext("Replace Operation Canceled"),
		Wx::OK,
		$self->current->main,
	);
}

sub introduce_temporary_variable {
	my $self   = shift;
	my $name   = shift;
	my $editor = $self->editor;

	# Run the replacement in the background
	$self->task_request(
		task           => 'Padre::Task::IntroduceTemporaryVariable',
		document       => $self,
		varname        => $name,
		start_location => $editor->GetSelectionStart,
		end_location   => $editor->GetSelectionEnd - 1,
		on_finish      => 'introduce_temporary_variable_response',
	);

	return;
}

sub introduce_temporary_variable_response {
	my $self = shift;
	my $task = shift;

	if ( defined $task->{munged} ) {

		# GUI update
		# TO DO: What if the document changed? Bad luck for now.
		$self->editor->SetText( $task->{munged} );
		$self->ppi_select( $task->{location} );
		return;
	}

	# Explain why it didn't work
	my $text;
	my $error = $self->{error} || '';
	if ( $error =~ /no token/ ) {
		$text = Wx::gettext("First character of selection does not seem to point at a token.");
	} elsif ( $error =~ /no statement/ ) {
		$text = Wx::gettext("Selection not part of a Perl statement?");
	} else {
		$text = Wx::gettext("Unknown error");
	}
	Wx::MessageBox(
		$text,
		Wx::gettext("Replace Operation Canceled"),
		Wx::OK,
		$self->current->main,
	);
}

# this method takes the new subroutine name
# and extracts the name and sets a call to it
# Uses Devel::Refactor to get the code and create the new subroutine code.
# Uses PPIx::EditorTools when no functions are in the script
# Otherwise locates the entry point after a user has
# provided a function name to insert the new code before.
sub extract_subroutine {
	my ( $self, $newname ) = @_;

	my $editor = $self->editor;

	# get the selected code
	my $code = $editor->GetSelectedText;

	#print "startlocation: " . join(", ", @$start_position) . "\n";
	# this could be configurable
	my $now         = localtime;
	my $sub_comment = <<EOC;
#
# New subroutine "$newname" extracted - $now.
#
EOC

	# get the new code
	require Devel::Refactor;
	my $refactory = Devel::Refactor->new;
	my ( $new_sub_call, $new_code ) = $refactory->extract_subroutine( $newname, $code, 1 );
	my $data = Wx::TextDataObject->new;
	$data->SetText( $sub_comment . $new_code . "\n\n" );

	# we want to get a list of the subroutines to pick where to place
	# the new sub
	my @functions = $self->functions;

	# need to check there are functions already defined
	if ( scalar(@functions) == 0 ) {

		# get the current position of the selected text as we need it for PPI
		my $start_position = $self->character_position_to_ppi_location( $editor->GetSelectionStart );
		my $end_position   = $self->character_position_to_ppi_location( $editor->GetSelectionEnd - 1 );

		# use PPI to find the right place to put the new subroutine
		require PPI::Document;
		my $text    = $editor->GetText;
		my $ppi_doc = PPI::Document->new( \$text );

		# /usr/local/share/perl/5.10.0/PPIx/EditorTools/IntroduceTemporaryVariable.pm
		# we have no subroutines to put before, so we
		# really just need to make sure we aren't in a block of any sort
		# and then stick the new subroutine in above where we are.
		# being above the selected text also means we won't
		# lose the location when the change is made to the document
		require PPIx::EditorTools;
		my $token = PPIx::EditorTools::find_token_at_location( $ppi_doc, $start_position );
		return unless $token;
		my $statement = $token->statement;
		my $parent    = $statement;

		#print "The statement is: " . $statement->statement . "\n";
		my $last_location; # use this to get the last point before the PPI::Document
		while ( !$parent->isa('PPI::Document') ) {

			#print "parent currently: " . ref($parent) . "\n";
			#print "location: " . join(', ', @{$parent->location} ) . "\n";

			$last_location = $parent->location;
			$parent        = $parent->parent;
		}

		#print "location: " . join(', ', @{$parent->location} ) . "\n";
		#print "last location: " . join(', ' ,@$last_location) . "\n";

		my $insert_start_location = $self->ppi_location_to_character_position($last_location);

		#print "Document start location is: $doc_start_location\n";

		# make the change to the selected text
		$editor->BeginUndoAction; # do the edit atomically
		$editor->ReplaceSelection($new_sub_call);
		$editor->InsertText( $insert_start_location, $data->GetText );
		$editor->EndUndoAction;

		return;
	}

	# Show a list of functions
	require Padre::Wx::Dialog::RefactorSelectFunction;
	my $dialog = Padre::Wx::Dialog::RefactorSelectFunction->new( $editor->main, \@functions );
	$dialog->show;
	if ( $dialog->{cancelled} ) {
		return ();
	}

	my $subname = $dialog->get_function_name;

	# make the change to the selected text
	$editor->BeginUndoAction; # do the edit atomically
	$editor->ReplaceSelection($new_sub_call);

	# with the change made
	# locate the function:
	require Padre::Search;
	my ( $start, $end ) = Padre::Search->matches(
		text     => $editor->GetText,
		regex    => $self->get_function_regex($subname),
		submatch => 1,
		from     => $editor->GetSelectionStart,
		to       => $editor->GetSelectionEnd,
	);
	unless ( defined $start ) {

		# This needs to now rollback the
		# the changes made with the editor
		$editor->Undo;
		$editor->EndUndoAction;

		# Couldn't find it
		# should be dialog
		#print "Couldn't find the sub: $subname\n";
		return;
	}

	# now insert the text into the right location
	$editor->InsertText( $start, $data->GetText );
	$editor->EndUndoAction;

	return ();

}

# This sub handles a cached C-Tags - Parser object which is much faster
# than recreating it on every autocomplete
sub perltags_parser {
	my $self = shift;

	# Don't scan on every char if there is no file
	return if $self->{_perltags_file_none};
	my $perltags_file = $self->{_perltags_file};

	require Parse::ExuberantCTags;
	my $config = Padre->ide->config;

	# Use the configured file (if any) or the old default, reset on config change
	if (   not defined $perltags_file
		or not defined $self->{_perltags_config}
		or $self->{_perltags_config} ne $config->lang_perl5_tags_file )
	{

		foreach my $candidate (
			$self->project_tagsfile, $config->lang_perl5_tags_file,
			File::Spec->catfile( $ENV{PADRE_HOME}, 'perltags' )
			)
		{

			# project_tagsfile and config value may be undef
			next if !defined($candidate);

			# config value may be defined but empty
			next if $candidate eq '';

			# Check if the tagsfile exists using Padre::File
			# to allow "ftp://my.server/~myself/perltags" in config
			# and remote projects
			my $tagsfile = Padre::File->new($candidate);
			next if !defined($tagsfile);

			next if !$tagsfile->exists;

			# For non-local perltags-files, copy the file to a local tempfile,
			# otherwise the parser won't work or will be very slow.
			if ( $tagsfile->{protocol} ne 'local' ) {

				# Create temporary local file
				require File::Temp;
				$self->{_perltags_temp} = File::Temp->new( UNLINK => 1 );

				# Flush tagsfile content to temporary file
				my $FH = $self->{_perltags_temp};
				$FH->autoflush(1);
				print $FH $tagsfile->read;

				# File should not be closed - it may get deleted on close!

				# Use the local temporary file as tagsfile
				$self->{_perltags_file} = $self->{_perltags_temp}->filename;
			} else {
				$self->{_perltags_file} = $candidate;
			}

			# Use first existing file
			last;
		}

		# Remember current value for later checks
		$self->{_perltags_config} = $config->lang_perl5_tags_file;

		$perltags_file = $self->{_perltags_file};

		# Remember that we don't have a file if we don't have one
		if ( defined($perltags_file) ) {
			$self->{_perltags_file_none} = 0;
		} else {
			$self->{_perltags_file_none} = 1;
		}

		# Reset timer for new file
		delete $self->{_perltags_parser_time};

	}

	# If we don't have a file (none specified in config, for example), return undef
	# as the object and noone will try to use it
	return if not defined $perltags_file;

	my $parser;

	# Use the cached parser if
	#  - there is one
	#  - the last check is younger than 5 seconds (don't check the file again)
	#    or the file's mtime matches our cached mtime
	if (    defined $self->{_perltags_parser}
		and defined $self->{_perltags_parser_time}
		and (  $self->{_perltags_parser_last} > time - 5
			or $self->{_perltags_parser_time} == ( stat $perltags_file )[9] )
		)
	{
		$parser = $self->{_perltags_parser};
		$self->{_perltags_parser_last} = time;
	} else {
		$parser                        = Parse::ExuberantCTags->new($perltags_file);
		$self->{_perltags_parser}      = $parser;
		$self->{_perltags_parser_time} = ( stat $perltags_file )[9];
		$self->{_perltags_parser_last} = time;
	}

	return $parser;
}

=pod

=head2 autocomplete

This method is called on two events:

=over

=item Manually using the C<autocomplete-action> (via menu, toolbar, hot key)

=item on every char typed by the user if the C<autocomplete-always> configuration option is active

=back

Arguments: The event object (optional)

Returns the prefix length and an array of suggestions. C<prefix_length> is the
number of characters left to the cursor position which need to be replaced if
a suggestion is accepted.

If there are no suggestions, the functions returns an empty list.

In case of error the function returns the error string as the first parameter.
Hence users of this subroution need to check if the value returned in the first
position is undef meaning no result or a string (including non digits) which
means a failure or a number which means the prefix length.

WARNING: This method runs very often (on each keypress), keep it as efficient
         and fast as possible!

=cut

sub autocomplete {
	my $self  = shift;
	my $event = shift;

	my $config    = Padre->ide->config;
	my $min_chars = $config->lang_perl5_autocomplete_min_chars;

	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);

	# This function is called very often, return asap
	return if ( $pos - $first ) < ( $min_chars - 1 );

	# line from beginning to current position
	my $prefix = $editor->GetTextRange( $first, $pos );

	# Remove any ident from the beginning of the prefix
	$prefix =~ s/^[\r\t]+//;
	return if length($prefix) == 0;

	# One char may be added by the current event
	return if length($prefix) < ( $min_chars - 1 );

	# The second parameter may be a reference to the current event or the next
	# char which will be added to the editor:
	my $nextchar = ''; # Use empty instead of undef
	if ( defined($event) and ( ref($event) eq 'Wx::KeyEvent' ) ) {
		my $key = $event->GetUnicodeKey;
		$nextchar = chr($key);
	} elsif ( defined($event) and ( !ref($event) ) ) {
		$nextchar = $event;
	}
	return if ord($nextchar) == 27; # Close on escape
	$nextchar = '' if ord($nextchar) < 32;

	# check for variables
	my $parser = $self->perltags_parser;

	my $last = $editor->GetLength;

	my $pre_text  = $editor->GetTextRange( 0,    $first );
	my $post_text = $editor->GetTextRange( $pos, $last );

	require Padre::Document::Perl::Autocomplete;
	my $ac = Padre::Document::Perl::Autocomplete->new(
		minimum_prefix_length        => $min_chars,
		maximum_number_of_choices    => $config->lang_perl5_autocomplete_max_suggestions,
		minimum_length_of_suggestion => $config->lang_perl5_autocomplete_min_suggestion_len,

		prefix    => $prefix,
		nextchar  => $nextchar,
		pre_text  => $pre_text,
		post_text => $post_text,
	);

	my @ret = $ac->run($parser);
	return @ret if @ret;

	return $ac->auto;
}

sub newline_keep_column {
	my $self   = shift;
	my $editor = $self->editor or return;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);
	my $col    = $pos - $first;
	my $text   = $editor->GetTextRange( $first, $pos );

	$editor->AddText( $self->newline );

	$text =~ s/\S/ /g;
	$editor->AddText($text);

	$editor->SetCurrentPos( $pos + $col + 1 );

	return 1;
}

=pod

=head2 event_on_char

This event fires once for every char which should be added to the editor window.

Typing this line fired it about 41 times!

Arguments: Current editor object, current event object

Returns nothing useful.

Notice: The char being typed has not been inserted into the editor at the run
        time of this method. It could be read using C<< $event->GetUnicodeKey >>

WARNING: This method runs very often (on each keypress), keep it as efficient
         and fast as possible!

=cut

sub event_on_char {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;
	my $config = $editor->config;
	my $main   = $editor->main;

	if ( $config->autocomplete_brackets ) {
		$self->autocomplete_matching_char(
			$editor,
			$event,
			34  => 34,  # " "
			39  => 39,  # ' '
			40  => 41,  # ( )
			60  => 62,  # < >
			91  => 93,  # [ ]
			123 => 125, # { }
		);
	}

	my $selection_exists = 0;
	my $text             = $editor->GetSelectedText;
	if ( defined($text) && length($text) > 0 ) {
		$selection_exists = 1;
	}

	my $key   = $event->GetUnicodeKey;
	my $pos   = $editor->GetCurrentPos;
	my $line  = $editor->LineFromPosition($pos);
	my $first = $editor->PositionFromLine($line);

	# removed the - 1 at the end
	#my $last = $editor->PositionFromLine( $line + 1 );

	my $last = $editor->GetLineEndPosition($line);

	#print "pos,line,first,last: $pos,$line,$first,$last\n";
	#print "$pos == $last\n";
	# This only matches if all conditions are met:
	#  - config option enabled
	#  - none of the following keys pressed: a-z, A-Z, 0-9, _
	#  - cursor position is at end of line
	if (( $config->autocomplete_method or $config->autocomplete_subroutine )
		and (  ( $key < 48 )
			or ( ( $key > 57 ) and ( $key < 65 ) )
			or ( ( $key > 90 ) and ( $key < 95 ) )
			or ( $key == 96 )
			or ( $key > 122 ) )
		and ( $pos == $last )
		)
	{

		# from beginning to current position
		my $prefix = $editor->GetTextRange( 0, $pos );

		# methods can't live outside packages, so ignore them
		my $linetext = $editor->GetTextRange( $first, $last );

		# TODO: Fix picking up the space char so that
		# 	when indenting the cursor isn't one space 'in'.
		if ( $prefix =~ /package / ) {

			# we only match "sub foo" at the beginning of a line
			# but no inline subs (eval, anonymus, etc.)
			# The end-of-subname match is included in the first if
			# which match the last key pressed (which is not part of
			# $linetext at this moment:

			if ( $linetext =~ /^sub[\s\t]+(\w+)$/ ) {
				my $subname = $1;

				my $indent_string = $self->get_indentation_level_string(1);

				# Add the default skeleton of a method
				my $newline            = $self->newline;
				my $text_before_cursor = " {$newline${indent_string}my \$self = shift;$newline$indent_string";
				$text_before_cursor =
					  " {$newline${indent_string}my \$class = shift;$newline$newline"
					. $indent_string
					. "my \$self = bless {\@_}, \$class;$newline$newline"
					. $indent_string
					if $subname eq 'new';
				my $text_after_cursor = "$newline}$newline";
				$text_after_cursor = $newline . $indent_string . "return \$self;" . $text_after_cursor
					if $subname eq 'new';
				$editor->AddText( $text_before_cursor . $text_after_cursor );

				# Ready for typing in the new method:
				$editor->GotoPos( $last + length($text_before_cursor) );
			}
		} elsif ( $linetext =~ /^sub[\s\t]+(\w+)$/ && $config->autocomplete_subroutine ) {

			my $subName       = $1;
			my $indent_string = $self->get_indentation_level_string(1);

			# Add the default skeleton of a subroutine,
			my $newline = $self->newline;
			$editor->AddText(" {$newline$indent_string$newline}");

			# $line is where it starts
			my $starting_line = $line - 1;
			if ( $starting_line < 0 ) {
				$starting_line = 0;
			}

			#print "starting_line: $starting_line\n";
			$editor->GotoPos( $editor->PositionFromLine($starting_line) );

			# TODO Add option for auto pod
			#$editor->AddText( $self->_pod($subName) );

			# $editor->GetLineEndPosition($editor->PositionFromLine(
			# TODO For pod this was 10
			my $end_line = $starting_line + 2;
			$editor->GotoLine($end_line);

			#print "end_line: $end_line\n";
			my $line_end_pos = $editor->GetLineEndPosition($end_line);

			#print "Line_end_pos: " . $line_end_pos . "\n";
			my $last_pos = $editor->GetLineEndPosition($end_line);

			#print "Last pos: $last_pos\n";
			# Ready for typing in the new function:

			$editor->GotoPos($last_pos);

		}
	}

	# Auto complete only when the user selected 'always'
	# and no ALT key is pressed
	if ( $config->autocomplete_always && ( not $event->AltDown ) ) {
		$main->on_autocompletion($event);
	}

	return;
}

sub _pod {
	my ( $self, $method ) = @_;
	my $pod = "\n=pod\n\n=head2 $method\n\n\tTODO: Document $method\n\n=cut\n";
	return $pod;
}


# Our opportunity to implement a context-sensitive right-click menu
# This would be a lot more powerful if we used PPI, but since that would
# slow things down beyond recognition, we use heuristics for now.
sub event_on_context_menu {
	my $self   = shift;
	my $editor = shift;
	my $menu   = shift;
	my $event  = shift;

	# Use the editor's current cursor position
	# PLEASE DO NOT use the mouse event position
	# You will get inconsistent results regarding refactor tools
	# when pressing Windows context "right click" key
	my $pos = $editor->GetCurrentPos;

	my $separator = 0;

	my ( $location, $token ) = $self->get_current_symbol($pos);

	# Append variable specific menu items if it's a variable
	if ( defined $location and $token =~ /^[\$\*\@\%\&]/ ) {
		$menu->AppendSeparator unless $separator++;

		$menu->add_menu_action(
			'perl.find_variable',
		);

		$menu->add_menu_action(
			'perl.rename_variable',
		);

		# Start variable style sub-menu
		my $style      = Wx::Menu->new;
		my $style_menu = $menu->Append(
			-1,
			Wx::gettext('Change variable style'),
			$style,
		);

		$menu->add_menu_action(
			$style,
			'perl.variable_to_camel_case',
		);

		$menu->add_menu_action(
			$style,
			'perl.variable_to_camel_case_ucfirst',
		);

		$menu->add_menu_action(
			$style,
			'perl.variable_from_camel_case',
		);

		$menu->add_menu_action(
			$style,
			'perl.variable_from_camel_case_ucfirst',
		);
	}

	if ( defined $location and $token =~ /^\w+$/ ) {
		$menu->AppendSeparator unless $separator++;

		$menu->add_menu_action(
			'perl.find_method',
		);
	}

	# Is something selected
	if ( $editor->GetSelectionLength ) {
		$menu->AppendSeparator unless $separator++;

		$menu->add_menu_action(
			'perl.introduce_temporary',
		);

		$menu->add_menu_action(
			'perl.edit_with_regex_editor',
		);
	}
}

sub event_on_left_up {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;

	if ( $event->ControlDown ) {
		my ( $location, $token ) = $self->get_current_symbol;

		# Does it look like a variable?
		if ( defined $location and $token =~ /^[\$\*\@\%\&]/ ) {
			$self->find_variable_declaration;
		}

		# Does it look like a function?
		elsif ( defined $location and $editor->has_function($token) ) {
			$editor->goto_function($token);
		}

		# Does it look like a path or module?
		elsif ( defined $token and $token =~ /(?:\/|\:\:)/ ) {
			$self->current->main->on_open_selection($token);
		}
	}
}

sub event_mouse_moving {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;

	if ( $event->Moving and $event->ControlDown ) {

		# Mouse is moving with ctrl pressed. If anything under the
		# cursor looks like it can be clicked on to take us somewhere,
		# highlight it.
		# TODO: Currently only supports subs/methods in the same file
		my $point = $event->GetPosition;
		my $pos   = $editor->PositionFromPoint($point);
		my ( $location, $token ) = $self->get_current_symbol($pos);

		$token ||= '';

		if ( $self->{last_highlight} and $token ne $self->{last_highlight}->{token} ) {

			# No longer mousing over the same token so un-highlight it
			$self->_clear_highlight($editor);
			$self->{last_highlight} = undef;
		}

		return unless length $token;
		return unless $editor->has_function($token);

		$editor->manual_highlight_show(
			$location->[2], # Position
			length($token), # Characters
		);

		$self->{last_highlight} = {
			token => $token,
			pos   => $location->[2],
		};
	}
}

sub event_key_up {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;

	if ( $event->GetKeyCode == Wx::K_CONTROL ) {

		# Ctrl key has been released, clear any highlighting
		$self->_clear_highlight($editor);
	}
}

sub _clear_highlight {
	my $self = shift;
	return unless $self->{last_highlight};

	# Remove the last highlight
	my $editor = shift;
	$editor->manual_highlight_hide(
		$self->{last_highlight}->{pos},
		length $self->{last_highlight}->{token},
	);
	undef $self->{last_highlight};
}

#
# Returns Perl's Help Provider
#
sub get_help_provider {
	require Padre::Document::Perl::Help;
	return Padre::Document::Perl::Help->new;
}

#
# Returns Perl's Quick Fix Provider
#
sub get_quick_fix_provider {
	require Padre::Document::Perl::QuickFix;
	return Padre::Document::Perl::QuickFix->new;
}

sub autoclean {
	my $self = shift;

	my $editor = $self->editor;
	my $text   = $editor->GetText;

	$text =~ s/[\s\t]+([\r\n]*?)$/$1/mg;
	$text .= "\n" if $text !~ /\n$/;

	$editor->SetText($text);

	return 1;

}

sub menu {
	my $self = shift;

	return [ 'menu.Perl', 'menu.Refactor' ];
}

=pod

=head2 project_tagsfile

No arguments.

Returns the full path and file name of the Perl tags file for the current
document.

=cut

sub project_tagsfile {
	my $self = shift;
	my $project = $self->project or return;
	return File::Spec->catfile( $project->root, 'perltags' );
}

=pod

=head2 project_create_tagsfile

Creates a tags file for the project of the current document. Includes all Perl
source files within the project excluding F<blib>.

=cut

sub project_create_tagsfile {
	my $self = shift;

	# First try is using the perl-tags command, next version should so this
	# internal using Padre::File and should skip at least the "blip" dir.
	system 'perl-tags', '-o', $self->project_tagsfile, $self->project_dir;

}

sub find_help_topic {
	my $self   = shift;
	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;

	require PPI;
	my $text = $editor->GetText;
	my $doc  = PPI::Document->new( \$text );

	# Find token under the cursor!
	my $line       = $editor->LineFromPosition($pos);
	my $line_start = $editor->PositionFromLine($line);
	my $line_end   = $editor->GetLineEndPosition($line);
	my $col        = $pos - $line_start;

	require Padre::PPI;
	my $token = Padre::PPI::find_token_at_location(
		$doc, [ $line + 1, $col + 1 ],
	);

	return $token->content if defined($token);

	#TODO enable once we figure out what we actually need to accomplish here :)
	#	if ($token) {
	#
	#		#print $token->class . "\n";
	#		if ( $token->isa('PPI::Token::Symbol') ) {
	#			if ( $token->content =~ /^[\$\@\%].+?$/ ) {
	#				return 'perldata';
	#			}
	#		} elsif ( $token->isa('PPI::Token::Operator') ) {
	#			return $token->content;
	#		}
	#	}
	#
	# 	return;
}

sub guess_filename_to_open {
	my $self = shift;
	my $text = shift;

	# Convert a module name to a file name
	my $module = $text;
	$module =~ s{::}{/}g;
	$module .= ".pm";

	# Check within our original startup directory
	SCOPE: {
		my $file = File::Spec->catfile(
			Padre->ide->{original_cwd},
			$module,
		);
		return $file if -e $file;
	}

	# If the file exists somewhere within our project, shortcut to it
	foreach my $dirs ( ['lib'], [] ) {
		my $file = File::Spec->catfile(
			$self->project_dir,
			@$dirs, $module,
		);
		return $file if -e $file;
	}

	# Search for a list of possible module locations in the @INC path
	my @files = grep { -e $_ } map { File::Spec->catfile( $_, $module ) } (
		File::Spec->catdir( $self->project_dir, 'inc' ),
		$self->get_inc,
	);
	return @files if @files;

	# Is this an executable in the current PATH
	require File::Which;
	my $filename = File::Which::which($text);
	return $filename if defined $filename;
	return;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

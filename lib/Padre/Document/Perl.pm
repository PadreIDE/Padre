package Padre::Document::Perl;

use 5.008;
use strict;
use warnings;
use Carp   ();
use Encode ();
use Params::Util '_INSTANCE';
use YAML::Tiny                      ();
use Padre::Document                 ();
use Padre::Util                     ();
use Padre::Perl                     ();
use Padre::Document::Perl::Beginner ();

our $VERSION = '0.49';
our @ISA     = 'Padre::Document';

#####################################################################
# Padre::Document::Perl Methods

# Ticket #637:
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
		$limit = 4000;
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

	Padre::Util::debug( "Setting highlighter for Perl 5 code. length: $length" . ( $limit ? " limit is $limit" : '' ) );

	if ( defined $limit and $length > $limit ) {
		Padre::Util::debug("Forcing STC highlighting");
		$module = 'stc';
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

	# Is this a script?
	my $text = $self->text_get;
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

	# Removes double \
	$text =~ s/\\{2}//sg;

	# Removes substitution functions
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)s(\W)(?:.*?)(?<!\\)\1(?:.*?)(?<!\\)\1\w*\s*(?<!;)?//g;
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)s\{(?:.*?)(?<!\\)\}\{(?:.*?)(?<!\\)\}\w*\s*(?<!;)?//sg;
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)s\((?:.*?)(?<!\\)\)\((?:.*?)(?<!\\)\)\w*\s*(?<!;)?//sg;

	# Removes translate functions
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)tr(\W)(?:.*?)(?<!\\)\1(?:.*?)(?<!\\)\1\w*\s*//sg;

	# Removes matches functions
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)m(\W)(?:.*?)(?<!\\)\1\w*\s*//sg;
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)m\{(?:.*?)(?<!\\)\}\w*\s*//sg;
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)m\((?:.*?)(?<!\\)\)\w*\s*//sg;
	$text =~ s/(?:[\$\@\%]\w+\s*[!=]~\s*)?(?<!\w)\/(?:.*?)(?<!\\)\/\w*\s*//sg;

	# Remove quoted strings, attributions and comparations
	$text =~ s/(?:[\$\@\%]\w+\s*=+\s*|\w+\s*)?(?<![\w\\])(["']).*?(?<!\\)\1//sg;

	# Removes everything after # in each line
	$text =~ s/#.*$//mg;

	#	return $text =~ m/\n\s*sub\s+(\w+(?:::\w+)*)/g;
	#	return $text =~ m/(?:(?:^[^#]*?)sub\s+(\w+(?:::\w+)*))+?/mg;
	return $text =~ m/(?:^|[};])\s*sub\s+(\w+(?:::\w+)*)/mg;
}

sub get_function_regex {

	# This emulates qr/(?<=^|[\012\015])sub\s$name\b/ but without
	# triggering a "Variable length lookbehind not implemented" error.
	#return qr/(?:(?<=^)\s*sub\s+$_[1]|(?<=[\012\015])\s*sub\s+$_[1])\b/;
	return qr/(?:^|[^#\s])\s*(sub\s+$_[1])\b/;
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

	# Run with console Perl to prevent unexpected results under wperl
	# The configuration values is cheaper to get compared to cperl(),
	# try it first.
	my $perl = $config->run_perl_cmd;

	# Warn if the Perl interpreter is not executable:
	if ( defined($perl) and ( $perl ne '' ) and ( !-x $perl ) ) {
		my $ret = Wx::MessageBox(
			Wx::gettext(
				sprintf( '%s seems to be no executable Perl interpreter, use the system default perl instead?', $perl )
			),
			Wx::gettext('Run'),
			Wx::wxYES_NO | Wx::wxCENTRE,
			Padre->ide->wx->main,
		);
		$perl = Padre::Perl::cperl()
			if $ret == Wx::wxYES;

	} else {
		$perl = Padre::Perl::cperl();
	}

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
	my $Script_Args = '';
	$Script_Args = ' ' . $run_args{script} if defined( $run_args{script} ) and ( $run_args{script} ne '' );

	my $dir = File::Basename::dirname($filename);
	chdir $dir;
	return $debug
		? qq{"$perl" -Mdiagnostics(-traceonly) $run_args{interpreter} "$filename"$Script_Args}
		: qq{"$perl" $run_args{interpreter} "$filename"$Script_Args};
}

sub pre_process {
	my $self = shift;

	if ( Padre->ide->config->editor_beginner ) {
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

# Run the checks for common beginner errors
sub beginner_check {
	my $self = shift;

	# TODO: Make this cool
	# It isn't, because it should show _all_ warnings instead of one and
	# it should at least go to the line it's complaining about.
	# Ticket #534

	my $Beginner = Padre::Document::Perl::Beginner->new(
		document => $self,
		editor   => $self->editor
	);

	$Beginner->check( $self->text_get );

	my $error = $Beginner->error;

	if ($error) {
		Padre->ide->wx->main->error( Wx::gettext("Error:\n") . $error );
	} else {
		Padre->ide->wx->main->message( Wx::gettext('No errors found.') );
	}

	return 1;
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

	# find start of symbol
	# TODO: This could be more robust, no?
	# Ticket #639
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

sub find_method_declaration {
	my ($self) = @_;

	my ( $location, $token ) = _get_current_symbol( $self->editor );
	unless ( defined $location ) {
		Wx::MessageBox(
			Wx::gettext("Current cursor does not seem to point at a method"),
			Wx::gettext("Check cancelled"),
			Wx::wxOK,
			Padre->ide->wx->main
		);
		return ();
	}
	if ($token =~ /^\w+$/) {
		# check if there is -> before or (  after or shall we look it up in the list of existing methods?
		# search for sub someting in
		#    current file
		#    all the files in the project directory (if in project)
		# cache the list of methods found
	}

	Wx::MessageBox(
		Wx::gettext("Current '$token' $location"),
		Wx::gettext("Check cancelled"),
		Wx::wxOK,
		Padre->ide->wx->main
	);
	my ($found, $filename) = $self->_find_method($token);
	if (not $found) {
		Wx::MessageBox(
			Wx::gettext("Current '$token' not found"),
			Wx::gettext("Check cancelled"),
			Wx::wxOK,
			Padre->ide->wx->main
		);
		return;
	}
	if (not $filename) {
		#print "No filename\n";
		# goto $line in current file
		$self->goto_sub($token);
	} else {
		my $main = Padre->ide->wx->main;
		# open or switch to file
		my $id = $main->find_editor_of_file($filename);
		if (not defined $id) {
			my $id = $main->setup_editor($filename);
		}
		#print "Filename '$filename' id '$id'\n";
		# goto $line in that file
		return if not defined $id;
		my $editor = $main->notebook->GetPage($id);
		$editor->{Document}->goto_sub($token);
	}
	

	return ();
}

sub _find_method {
	my ($self, $name) = @_;
	# TODO unify with code in Padre::Wx::FunctionList
	if (not $self->{_methods_}{$name}) {
		$self->{_methods_}{$_} = $self->filename for $self->get_functions;
		# search also in other files
	}
	#use Data::Dumper;
	#print Dumper $self->{_methods_};

	if ($self->{_methods_}{$name}) {
		return 1, $self->{_methods_}{$name};
	}
	return;

}
# TODO temp function given a name of a subroutine and move the cursor 
# to its develaration, need to be improved ~ szabgab
sub goto_sub {
	my ($self, $name) = @_;
	my $text = $self->text_get;
	my @lines = split /\n/, $text;
	#print "Name '$name'\n";
	for my $i (0..@lines-1) {
		#print "L: $lines[$i]\n";
		if ($lines[$i] =~ /sub \s+ $name/x) {
			$self->editor->goto_line_centerize($i);
			return 1;
		}
	}
	return;
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
	my $code = $editor->GetSelectedText();

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
	my @functions = $self->get_functions;

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
		#require PPI::Dumper;
		#my $dumper = PPI::Dumper->new( $ppi_doc );
		#$dumper->print;
		require PPIx::EditorTools;
		my $token     = PPIx::EditorTools::find_token_at_location( $ppi_doc, $start_position );
		my $statement = $token->statement();
		my $parent    = $statement;

		#print "The statement is: " . $statement->statement() . "\n";
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
		$editor->BeginUndoAction(); # do the edit atomically
		$editor->ReplaceSelection($new_sub_call);
		$editor->InsertText( $insert_start_location, $data->GetText );
		$editor->EndUndoAction();

		return;
	}

	# Show a list of functions
	require Padre::Wx::Dialog::RefactorSelectFunction;
	my $dialog = Padre::Wx::Dialog::RefactorSelectFunction->new( $editor->main, \@functions );
	$dialog->show();
	if ( $dialog->{cancelled} ) {

		#$dialog->Destroy();
		return ();
	}

	my $subname = $dialog->get_function_name;

	#$dialog->Destroy();

	# make the change to the selected text
	$editor->BeginUndoAction(); # do the edit atomically
	$editor->ReplaceSelection($new_sub_call);

	# with the change made
	# locate the function:
	my ( $start, $end ) = Padre::Util::get_matches(
		$editor->GetText,
		$self->get_function_regex($subname),
		$editor->GetSelection,  # Provides two params
	);
	unless ( defined $start ) {

		# This needs to now rollback the
		# the changes made with the editor
		$editor->Undo();
		$editor->EndUndoAction();

		# Couldn't find it
		# should be dialog
		#print "Couldn't find the sub: $subname\n";
		return;
	}

	# now insert the text into the right location
	$editor->InsertText( $start, $data->GetText );
	$editor->EndUndoAction();

	return ();

}

# This sub handles a cached C-Tags - Parser object which is much faster
# than recreating it on every autocomplete

sub _perltags_parser {
	my $self = shift;

	require Parse::ExuberantCTags;

	my $perltags_file = $self->{_perltags_file};

	# Temporary until this is configurable:
	if ( !defined($perltags_file) ) {
		$self->{_perltags_file} = File::Spec->catfile( $ENV{PADRE_HOME}, 'perltags' );
		$perltags_file = $self->{_perltags_file};
	}

	# If we don't have a file (none specified in config, for example), return undef
	# as the object and noone will try to use it
	return undef if !defined($perltags_file);

	my $parser;

	# Use the cached parser if
	#  - there is one
	#  - the last check is younger than 5 seconds (don't check the file again)
	#    or the file's mtime matches our cached mtime
	if (    defined( $self->{_perltags_parser} )
		and defined( $self->{_perltags_parser_time} )
		and (  ( $self->{_perltags_parser_last} > ( time - 5 ) )
			or ( $self->{_perltags_parser_time} == ( stat($perltags_file) )[9] ) )
		)
	{
		$parser = $self->{_perltags_parser};
		$self->{_perltags_parser_last} = time;
	} else {
		$parser                        = Parse::ExuberantCTags->new($perltags_file);
		$self->{_perltags_parser}      = $parser;
		$self->{_perltags_parser_time} = ( stat($perltags_file) )[9];
		$self->{_perltags_parser_last} = time;
	}

	return $parser;
}

sub autocomplete {
	my $self  = shift;
	my $event = shift;

	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);

	# line from beginning to current position
	my $prefix = $editor->GetTextRange( $first, $pos );
	my $suffix = $editor->GetTextRange( $pos,   $pos + 15 );
	$suffix = $1 if $suffix =~ /^(\w*)/; # Cut away any non-word chars

	# The second parameter may be a reference to the current event or the next
	# char which will be added to the editor:
	my $nextchar;
	if ( defined($event) and ( ref($event) eq 'Wx::KeyEvent' ) ) {
		my $key = $event->GetUnicodeKey;
		$nextchar = chr($key);
	} elsif ( defined($event) and ( !ref($event) ) ) {
		$nextchar = $event;
	}

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
	# (Ticket #676)

	# check for variables

	if ( $prefix =~ /([\$\@\%\*])(\w+(?:::\w+)*)$/ ) {
		my $prefix = $2;
		my $type   = $1;
		my $parser = $self->_perltags_parser;
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
		my $parser = $self->_perltags_parser;
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
		my $parser = $self->_perltags_parser;

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
	eval { $regex = qr{\b(\Q$prefix\E\w+(?:::\w+)*)\b} };
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

	# Suggesting the current word as the only solution doesn't help
	# anything, but your need to close the suggestions window before
	# you may press ENTER/RETURN.
	if ( ( $#words == 0 ) and ( $prefix eq $words[0] ) ) {
		return;
	}

	# While typing within a word, the rest of the word shouldn't be
	# inserted.
	if ( defined($suffix) ) {
		for ( 0 .. $#words ) {
			$words[$_] =~ s/\Q$suffix\E$//;
		}
	}

	# This is the final result if there is no char which hasn't been
	# saved to the editor buffer until now
	return ( length($prefix), @words ) if !defined($nextchar);

	# Finally cut out all words which do not match the next char
	# which will be inserted into the editor (by the current event)
	my @final_words;
	for (@words) {

		# Accept everything which has prefix + next char + at least one other char
		next if !/^\Q$prefix$nextchar\E./;
		push @final_words, $_;
	}

	return ( length($prefix), @final_words );
}

sub newline_keep_column {
	my $self = shift;

	my $editor = $self->editor or return;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);
	my $col    = $pos - $editor->PositionFromLine( $editor->LineFromPosition($pos) );
	my $text   = $editor->GetTextRange( $first, ( $pos - $first ) );

	$editor->AddText( $self->newline );

	$pos   = $editor->GetCurrentPos;
	$first = $editor->PositionFromLine( $editor->LineFromPosition($pos) );

	#	my $col2 = $pos - $first;
	#	$editor->AddText( ' ' x ( $col - $col2 ) );

	# TODO: Remove the part made by auto-ident before addtext:
	$text =~ s/[^\s\t\r\n]/ /g;
	$editor->AddText($text);

	$editor->SetCurrentPos( $first + $col );

	return 1;
}

sub event_on_char {
	my ( $self, $editor, $event ) = @_;

	my $config = Padre->ide->config;
	my $main   = Padre->ide->wx->main;

	$editor->Freeze;

	$self->autocomplete_matching_char(
		$editor, $event,
		34  => 34,  # " "
		39  => 39,  # ' '
		40  => 41,  # ( )
		60  => 62,  # < >
		91  => 93,  # [ ]
		123 => 125, # { }
	);

	my $selection_exists = 0;
	my $text             = $editor->GetSelectedText;
	if ( defined($text) && length($text) > 0 ) {
		$selection_exists = 1;
	}

	my $key = $event->GetUnicodeKey;

	my $pos   = $editor->GetCurrentPos;
	my $line  = $editor->LineFromPosition($pos);
	my $first = $editor->PositionFromLine($line);
	my $last  = $editor->PositionFromLine( $line + 1 ) - 1;

	# This only matches if all conditions are met:
	#  - config option enabled
	#  - none of the following keys pressed: a-z, A-Z, 0-9, _
	#  - cursor position is at end of line
	if ($config->autocomplete_method
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
		if ( $prefix =~ /package / ) {
			my $linetext = $editor->GetTextRange( $first, $last );

			# we only match "sub foo" at the beginning of a line
			# but no inline subs (eval, anonymus, etc.)
			# The end-of-subname match is included in the first if
			# which match the last key pressed (which is not part of
			# $linetext at this moment:
			if ( $linetext =~ /^sub[\s\t]+\w+$/ ) {

				# Add the default skeleton of a method,
				# the \t should be replaced by
				# (space * current_indent_width)
				$editor->AddText( ' {'
						. $self->newline . "\t"
						. 'my $self = shift;'
						. $self->newline . "\t"
						. $self->newline . '}'
						. $self->newline
						. $self->newline );

				# Ready for typing in the new method:
				$editor->GotoPos( $last + 23 );

			}
		}
	}

	$editor->Thaw;

	# Auto complete only when the user selected 'always'
	# and no ALT key is pressed
	if ( $config->autocomplete_always && ( not $event->AltDown ) ) {
		$main->on_autocompletion($event);
	}

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
		if ( $point != Wx::wxDefaultPosition ) {

			# Then it is really a mouse event...
			# On Windows, context menu is faked
			# as a Mouse event
			$pos = $editor->PositionFromPoint($point);
		}
	}

	unless ($pos) {

		# Fall back to the cursor position
		$pos = $editor->GetCurrentPos();
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
# Returns Perl's Help Provider
#
sub get_help_provider {
	require Padre::HelpProvider::Perl;
	return Padre::HelpProvider::Perl->new;
}

#
# Returns Perl's Quick Fix Provider
#
sub get_quick_fix_provider {
	require Padre::QuickFixProvider::Perl;
	return Padre::QuickFixProvider::Perl->new;
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



1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

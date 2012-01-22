package Padre::Document::Perl::Syntax;

use 5.008;
use strict;
use warnings;
use Padre::Constant          ();
use Padre::Util              ();
use Padre::Task::Syntax      ();
use Parse::ErrorString::Perl ();

our $VERSION = '0.94';
our @ISA     = 'Padre::Task::Syntax';

sub new {
	my $class = shift;
	my %args  = @_;

	if ( defined $ENV{PADRE_IS_TEST} ) {

		# Note: $ENV{PADRE_IS_TEST} is defined in t/44-perl-syntax.t
		# Run with console Perl to prevent failures while testing
		require Padre::Perl;
		$args{perl} = Padre::Perl::cperl();
	} else {

		# Otherwise run with user-preferred interpreter
		$args{perl} = $args{document}->get_interpreter;
	}

	$class->SUPER::new(%args);
}

sub syntax {
	my $self = shift;
	my $text = shift;

	# Localise newlines using Adam's magic "Universal Newline"
	# regex conveniently stolen from File::LocalizeNewlines.
	# (i.e. "conveniently" avoiding a bunch of dependencies)
	$text =~ s/(?:\015{1,2}\012|\015|\012)/\n/sg;

	# Execute the syntax check
	my $stderr   = '';
	my $filename = undef;
	SCOPE: {

		# Create a temporary file with the Perl text
		require File::Temp;
		my $file = File::Temp->new( UNLINK => 1 );
		$filename = $file->filename;
		binmode( $file, ':encoding(UTF-8)' );

		# If this is a module, we will need to overwrite %INC to avoid the module
		# loading another module, which loads the system installed equivalent
		# of the package we are currently compile-testing.
		if ( $text =~ /^\s*package ([\w:]+)/ ) {
			my $module_file = $1 . '.pm';
			$module_file =~ s/::/\//g;
			$file->print("BEGIN {\n");
			$file->print("\t\$INC{'$module_file'} = '$file';\n");
			$file->print("}\n");
			$file->print("#line 1\n");
		}

		# Toggle syntax checking for certain regions
		$file->print( $self->_parse_comment_pragmas($text) );
		$file->close;

		my @cmd = ( $self->{perl} );

		# Append Perl command line options
		if ( $self->{project} ) {
			push @cmd, '-Ilib';
		}

		# Open a temporary file for standard error redirection
		my $err = File::Temp->new( UNLINK => 1 );
		$err->close;

		# Redirect perl's output to temporary file
		# NOTE: Please DO NOT use -Mdiagnostics since it will wrap
		# error messages on multiple lines and that would
		# complicate parsing (azawawi)
		push @cmd,
			(
			'-c',
			'<' . $file->filename,
			'2>' . $err->filename,
			);

		# We need shell redirection (list context does not give that)
		# Run command in directory
		Padre::Util::run_in_directory( join( ' ', @cmd ), $self->{project} );

		# Slurp Perl's stderr...
		open my $fh, '<', $err->filename or die $!;
		local $/ = undef;
		$stderr = <$fh>;
		close $fh;
	}

	# Short circuit if the syntax is OK and no other errors/warnings are present
	return [] if $stderr eq "- syntax OK\n";

	# Since we're not going to use -Mdiagnostics,
	# we will simply reuse Padre::ErrorString::Perl for Perl error parsing
	my @issues = Parse::ErrorString::Perl->new->parse_string($stderr);

	# We need the 'at' or 'near' clauses appended to the issue because
	# it is more meaningful
	for my $issue (@issues) {
		if ( defined( $issue->{at} ) ) {
			$issue->{message} .= ', at ' . $issue->{at};
		} elsif ( defined( $issue->{near} ) ) {
			$issue->{message} .= ', near "' . $issue->{near} . '"';
		}
	}

	return {
		issues => \@issues,
		stderr => $stderr,
	};
}

#
# Parses syntax checking comments blocks
# To disable Padre syntax check, please use:
# 	## no padre_syntax_check
# To enable again:
# 	## use padre_syntax_check
#
sub _parse_comment_pragmas {
	my $self = shift;
	my $text = shift;
	my $n    = "\\cM?\\cJ";

	if ( $text =~ /$n\s*\#\#\s+(use|no)\s+padre_syntax_check\s*/ ) {

		# Only process when there is 'use|no padre_syntax_check'
		# comment pragmas
		my $ignore = 0;
		my $output = '';
		for my $line ( split /^/, $text ) {
			if ( $line =~ /^\s*\#\#\s+(use|no)\s+padre_syntax_check\s*$/ ) {
				$ignore = ( $1 eq 'no' ) ? 1 : 0;
			} else {
				$output .= $ignore ? "# $line" : $line;
			}
		}

		# Return processed text
		return $output;
	}

	return $text;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

package Padre::Document::Perl::Syntax;

use 5.008;
use strict;
use warnings;
use Padre::Constant      ();
use Padre::Task::Syntax ();

our $VERSION = '0.64';
our @ISA     = 'Padre::Task::Syntax';

sub syntax {
	my $self = shift;
	my $text = shift;

	# Localise newlines using Adam's magic "Universal Newline"
	# regex conveniently stolen from File::LocalizeNewlines.
	# (Conveniently adding a bunch of dependencies for one regex)
	$text =~ s/(?:\015{1,2}\012|\015|\012)/\n/sg;

	# Execute the syntax check
	my $stderr   = '';
	my $filename = undef;
	SCOPE: {

		# Create a temporary file with the Perl text
		require File::Temp;
		my $file = File::Temp->new( UNLINK => 1 );
		binmode( $file, ":utf8" );
		$file->print( $text );
		$file->close;
		$filename = $file->filename;

		# Run with console Perl to prevent unexpected results under wperl
		require Padre::Perl;
		my @cmd = ( Padre::Perl::cperl() );

		# Append Perl command line options
		if ( $self->{project} ) {
			push @cmd, '-Ilib';
		}

		# Open a temporary file for standard error redirection
		my $err = File::Temp->new( UNLINK => 1 );
		$err->close;

		# Redirect perl's output to temporary file
		push @cmd, (
			'-Mdiagnostics',
			'-c',
			$file->filename,
			'2>' . $err->filename,
		);

		# We need shell redirection (list context does not give that)
		my $cmd = join ' ', @cmd;

		# Make sure we execute from the correct directory
		if ( Padre::Constant::WIN32 ) {
			require Padre::Util::Win32;
			Padre::Util::Win32::ExecuteProcessAndWait(
				directory  => $self->{project},
				file       => 'cmd.exe',
				parameters => "/C $cmd",
			);
		} else {
			require File::pushd;
			my $pushd = File::pushd::pushd( $self->{project} );
			system $cmd;
		}

		# Slurp Perl's stderr...
		open my $fh, '<', $err->filename or die $!;
		local $/ = undef;
		$stderr = <$fh>;
		close $fh;

		# ...and delete it
		require File::Remove;
		File::Remove::remove( $err->filename );
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
	my @messages = split( /\n/, $stderr );

	my @issues = ();
	my @diag   = ();
	foreach my $message (@messages) {
		last if index( $message, 'has too many errors' ) > 0;
		last if index( $message, 'had compilation errors' ) > 0;
		last if index( $message, 'syntax OK' ) > 0;

		my $error = {};
		my $tmp   = '';

		if ( $message =~ s/\s\(\#(\d+)\)\s*\Z//o ) {
			$error->{diag} = $1 - 1;
		}

		if ( $message =~ m/\)\s*\Z/o ) {
			my $pos = rindex( $message, '(' );
			$tmp = substr( $message, $pos, length($message) - $pos, '' );
		}

		if ( $message =~ s/\s\(\#(\d+)\)(.+)//o ) {
			$error->{diag} = $1 - 1;
			my $diagtext = $2;
			$diagtext =~ s/\x1F//go;
			push @diag, join( ' ', split( ' ', $diagtext ) );
		}

		if ( $message =~ s/\sat(?:\s|\x1F)+(.+?)(?:\s|\x1F)line(?:\s|\x1F)(\d+)//o ) {
			next if $1 ne $filename;
			$error->{line} = $2;
			$error->{msg}  = $message;
		}

		if ($tmp) {
			$error->{msg} .= "\n" . $tmp;
		}

		if ( defined $error->{msg} ) {
			$error->{msg} =~ s/\x1F/\n/go;
		}

		if ( defined $error->{diag} ) {
			$error->{desc} = $diag[ $error->{diag} ];
			delete $error->{diag};
		}
		if ( defined( $error->{desc} )
			&& $error->{desc} =~ /^\s*\([WD]/o )
		{
			$error->{severity} = 1;
		} else {
			$error->{severity} = 0;
		}
		delete $error->{desc};

		push @issues, $error;
	}

	return \@issues;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

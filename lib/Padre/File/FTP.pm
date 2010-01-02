package Padre::File::FTP;

use 5.008;
use strict;
use warnings;

use Padre::File;
use File::Temp;

our $VERSION = '0.53';
our @ISA     = 'Padre::File';

use Class::XSAccessor {
	false => [qw/can_run/],
};

sub new {
	my $class = shift;
	my $url   = shift;

	# Create myself
	my $self = bless { filename => $url }, $class;

	# Using the config is optional, tests and other usages should run without
	my $config = eval { return Padre->ide->config; };
	if ( defined($config) ) {
		$self->{_timeout} = $config->file_ftp_timeout;
		$self->{_passive} = $config->file_ftp_passive;
	} else {

		# Use defaults if we have no config
		$self->{_timeout} = 60;
		$self->{_passive} = 1;
	}

	# Don't add a new overall-dependency to Padre:
	eval { require Net::FTP; };
	if ($@) {

		$self->{error} = 'Net::FTP is not installed, Padre::File::FTP currently depends on it.';
		return $self;
	}

##### START URL parsing #####

##### NO REGEX's below this line (except the parser)! #####

	# TO DO: Improve URL parsing
	if ( $url !~ /ftp\:\/?\/?((.+?)(\:(.+?))?\@)?([a-z0-9\-\.]+)(\:(\d+))?(\/.+)$/i ) {

		# URL parsing failed
		# TO DO: Warning should go to a user popup not to the text console
		$self->{error} = 'Unable to parse ' . $url;
		return $self;
	}

	# Login data
	if ( defined($2) ) {
		$self->{_user} = $2;
		$self->{_pass} = $4 if defined($4);
	} else {
		$self->{_user} = 'ftp';
		$self->{_pass} = 'padre_user@devnull.perlide.org';
	}

	# Host & port
	$self->{_host} = $5;
	$self->{_port} = $7 || 21;

	# Path & filename
	$self->{_file} = $8;

##### END URL parsing, regex is allowed again #####

	if ( !defined( $self->{_pass} ) ) {

		# TO DO: Ask the user for a password
	}

	# TO DO: Handle aborted/timed out connections

	# Create FTP object and connection
	$self->{_ftp} = Net::FTP->new(
		Host    => $self->{_host},
		Port    => $self->{_port},
		Timeout => $self->{_timeout},
		Passive => $self->{_passive},

		# Debug => 3, # Enable for FTP-debugging to STDERR
	);

	if ( !defined( $self->{_ftp} ) ) {

		$self->{error} = 'Error connecting to ' . $self->{_host} . ':' . $self->{_port} . ': ' . $@;
		return $self;
	}

	if ( !$self->{_ftp}->login( $self->{_user}, $self->{_pass} ) ) {

		$self->{error} = 'Error logging in on ' . $self->{_host} . ':' . $self->{_port} . ': ' . $@;
		return $self;
	}

	$self->{_ftp}->binary;

	$self->{protocol} = 'ftp'; # Should not be overridden

	$self->{_file_temp} = File::Temp->new( UNLINK => 1 );
	$self->{_tmpfile} = $self->{_file_temp}->filename;

	return $self;
}

sub clone {
	my $origin = shift;

	my $url = shift;

	# Create myself
	my $self = bless { filename => $url }, ref($origin);

	# Copy the common values
	for ( '_timeout', '_passive', '_user', '_pass', '_port', '_host', '_ftp' ) {
		$self->{$_} = $origin->{$_};
	}

##### START URL parsing #####

##### NO REGEX's below this line (except the parser)! #####

	# TO DO: Improve URL parsing
	if ( $url !~ /ftp\:\/?\/?((.+?)(\:(.+?))?\@)?([a-z0-9\-\.]+)(\:(\d+))?(\/.+)$/i ) {

		# URL parsing failed
		# TO DO: Warning should go to a user popup not to the text console
		$self->{error} = 'Unable to parse ' . $url;
		return $self;
	}

	# Path & filename
	$self->{_file} = $8;

##### END URL parsing, regex is allowed again #####

	$self->{protocol} = 'ftp'; # Should not be overridden

	$self->{_file_temp} = File::Temp->new( UNLINK => 1 );
	$self->{_tmpfile} = $self->{_file_temp}->filename;

	return $self;
}

sub size {
	my $self = shift;
	return if !defined( $self->{_ftp} );
	return $self->{_ftp}->size( $self->{_file} );
}

sub _todo_mode {
	my $self = shift;
	return 33024; # Currently fixed: read-only textfile
}

sub mtime {
	my $self = shift;

	# The file-changed-on-disk - function requests this frequently:
	if ( defined( $self->{_cached_mtime_time} ) and ( $self->{_cached_mtime_time} > ( time - 60 ) ) ) {
		return $self->{_cached_mtime_value};
	}

	$self->{_cached_mtime_value} = $self->{_ftp}->mdtm( $self->{_file} );
	$self->{_cached_mtime_time}  = time;

	return $self->{_cached_mtime_value};
}

sub browse_mtime {
	my $self     = shift;
	my $filename = shift;

	return $self->{_ftp}->mdtm($filename);
}

sub exists {
	my $self = shift;
	return if !defined( $self->{_ftp} );

	# Cache basename value
	my $basename = $self->basename;

	for ( $self->{_ftp}->ls( $self->{_file} ) ) {
		return 1 if $_ eq $self->{_file};
		return 1 if $_ eq $basename;
	}

	# Fallback if ->ls didn't help. A file heaving a size should exist.
	return 1 if $self->size;

	return ();
}

sub basename {
	my $self = shift;

	my $name = $self->{_file};
	$name =~ s/^.*\///;

	return $name;
}

# This method should return the dirname to be used inside Padre, not the one
# used on the FTP-server.
sub dirname {
	my $self = shift;

	my $dir = $self->{filename};
	$dir =~ s/\/[^\/]*$//;

	return $dir;
}

sub servername {
	my $self = shift;

	# Don't explicit return ftp default port
	return $self->{_host} if $self->{_port} == 21;

	return $self->{_host} . ':' . $self->{_port};
}

sub read {
	my $self = shift;

	return if !defined( $self->{_ftp} );

	# TO DO: Better error handling
	$self->{_ftp}->get( $self->{_file}, $self->{_tmpfile} ) or $self->{error} = $@;
	open my $tmpfh, '<', $self->{_tmpfile};
	my $rv = join( '', <$tmpfh> );
	close $tmpfh;
	return $rv;
}

sub readonly {

	# TO DO: Check file access
	return ();
}

sub write {
	my $self    = shift;
	my $content = shift;
	my $encode  = shift || ''; # undef encode = default, but undef will trigger a warning

	return unless defined $self->{_ftp};

	if ( open my $fh, ">$encode", $self->{_tmpfile} ) {
		print {$fh} $content;
		close $fh;

		# TO DO: Better error handling
		$self->{_ftp}->put( $self->{_tmpfile}, $self->{_file} ) or warn $@;

		return 1;
	}

	$self->{error} = $!;
	return ();
}

###############################################################################
### Internal FTP helper functions

sub _ftp_dirname {
	my $self = shift;

	my $dir = $self->{_file};
	$dir =~ s/\/[^\/]*$//;

	return $dir;
}

sub can_clone {
	return 1;
}

1;

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

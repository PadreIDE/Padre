package Padre::File::FTP;

use 5.008;
use strict;
use warnings;
use File::Temp     ();
use Padre::File    ();
use Padre::Current ();

our $VERSION = '0.94';
our @ISA     = 'Padre::File';

my %connection_cache;

use Class::XSAccessor {
	false => [
		'can_run',
	],
};

sub new {
	my $class = shift;
	my $url   = shift;

	# Create myself
	my $self = bless {
		filename => $url,
	}, $class;

	# Using the config is optional, tests and other usages should run without
	my $config = Padre::Current->config;
	if ( defined($config) ) {
		$self->{_timeout} = $config->file_ftp_timeout;
		$self->{_passive} = $config->file_ftp_passive;
	} else {

		# Use defaults if we have no config
		$self->{_timeout} = 60;
		$self->{_passive} = 1;
	}

	# Don't add a new overall-dependency to Padre:
	$self->_info( Wx::gettext('Looking for Net::FTP...') );
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

	$self->{protocol} = 'ftp'; # Should not be overridden

	$self->{_file_temp} = File::Temp->new( UNLINK => 1 );
	$self->{_tmpfile} = $self->{_file_temp}->filename;

	return $self;
}

sub _ftp {
	my $self = shift;

	my $cache_key = join( "\x00", $self->{_host}, $self->{_port}, $self->{_user} );

	# NOOP is used to check if the connection is alive, the server will return
	# 200 if the command is successful
	if ( defined( $connection_cache{$cache_key} ) ) {
		if ( ( $self->{_last_noop} || 0 ) == time ) {
			return $connection_cache{$cache_key};
		} elsif ( $self->{_no_noop} ) {
			$self->{_last_noop} = time;

			# NOOP is not supported
			return $connection_cache{$cache_key} if $connection_cache{$cache_key}->quot('PWD');
		} else {
			$self->{_last_noop} = time;

			# NOOP is supported
			return $connection_cache{$cache_key} if $connection_cache{$cache_key}->quot('NOOP') == 2;
		}
	}

	# Create FTP object and connection
	$self->_info( sprintf( Wx::gettext('Connecting to FTP server %s...'), $self->{_host} . ':' . $self->{_port} ) );
	my $ftp = Net::FTP->new(
		Host => $self->{_host},
		Port => $self->{_port},
		exists $self->{_timeout} ? ( Timeout => $self->{_timeout} ) : (),
		exists $self->{_passive} ? ( Passive => $self->{_passive} ) : (),

		#		Debug => 3, # Enable for FTP-debugging to STDERR
	);

	if ( !defined($ftp) ) {
		$self->{error} = sprintf( Wx::gettext('Error connecting to %s:%s: %s'), $self->{_host}, $self->{_port}, $@ );
		return;
	}

	if ( !defined( $self->{_pass} ) ) {
		$self->{_pass} = Padre::Current->main->password(
			sprintf(
				Wx::gettext("Password for user '%s' at %s:"),
				$self->{_user},
				$self->{_host},
			),
			Wx::gettext('FTP Password'),
		) || ''; # Use empty password (not undef) if nothing was entered
		         # TODO: offer an option to store the password
	}

	# Log into the FTP server
	$self->_info( sprintf( Wx::gettext('Logging into FTP server as %s...'), $self->{_user} ) );
	if ( !$ftp->login( $self->{_user}, $self->{_pass} ) ) {
		$self->{error} = sprintf(
			Wx::gettext('Error logging in on %s:%s: %s'), $self->{_host}, $self->{_port},
			defined $@ ? $@ : Wx::gettext('Unknown error')
		);
		return;
	}

	$self->{_no_noop} = 1 unless $ftp->quot('NOOP') == 2;

	$ftp->binary;

	$connection_cache{$cache_key} = $ftp;

	$self->_info( Wx::gettext('Connection to FTP server successful.') );

	$self->{_last_noop} = time;

	return $ftp;
}


sub clone {
	my $origin = shift;

	my $url = shift;

	# Create myself
	my $self = bless { filename => $url }, ref($origin);

	# Copy the common values
	for ( '_timeout', '_passive', '_user', '_pass', '_port', '_host' ) {
		$self->{$_} = $origin->{$_};
	}

##### START URL parsing #####

##### NO REGEX's below this line (except the parser)! #####

	# TO DO: Improve URL parsing
	if ( $url !~ /ftp\:\/?\/?((.+?)(\:(.+?))?\@)?([a-z0-9\-\.]+)(\:(\d+))?(\/.+)$/i ) {

		# URL parsing failed
		# TO DO: Warning should go to a user popup not to the text console
		$self->{error} = sprintf( Wx::gettext('Unable to parse %s'), $url );
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
	return if !defined( $self->_ftp );
	return $self->_ftp->size( $self->{_file} );
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

	$self->{_cached_mtime_value} = $self->_ftp->mdtm( $self->{_file} );
	$self->{_cached_mtime_time}  = time;

	return $self->{_cached_mtime_value};
}

sub browse_mtime {
	my $self     = shift;
	my $filename = shift;

	return $self->_ftp->mdtm($filename);
}

sub exists {
	my $self = shift;

	my $ftp = $self->_ftp;
	return if !defined $ftp;

	# Cache basename value
	my $basename = $self->basename;

	for ( $ftp->ls( $self->{_file} ) ) {
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

	return if !defined( $self->_ftp );

	$self->_info( Wx::gettext('Reading file from FTP server...') );

	# TO DO: Better error handling
	$self->_ftp->get( $self->{_file}, $self->{_tmpfile} ) or $self->{error} = $@;
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

	return unless defined $self->_ftp;

	$self->_info( Wx::gettext('Writing file to FTP server...') );
	if ( open my $fh, ">$encode", $self->{_tmpfile} ) {
		print {$fh} $content;
		close $fh;

		# TO DO: Better error handling
		$self->_ftp->put( $self->{_tmpfile}, $self->{_file} ) or warn $@;

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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

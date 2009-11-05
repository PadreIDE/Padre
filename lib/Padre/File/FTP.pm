package Padre::File::FTP;

use 5.008;
use strict;
use warnings;

use Padre::File;
use File::Temp;

our $VERSION = '0.49';
our @ISA     = 'Padre::File';

sub new {
	my $class = shift;

	my $url = shift;

	# Don't add a new overall-dependency to Padre:
	eval { require Net::FTP; };
	if ($@) {
		# TODO: Warning should go to a user popup not to the text console
		warn 'Net::FTP is not installed, Padre::File::FTP currently depends on it.';
		return;
	}

	# Create myself
		my $self = bless {
		filename => $url }, $class;

##### START URL parsing #####

##### NO REGEX's below this line! #####

	# TODO: Improve URL parsing
	if ($url !~ /ftp\:\/?\/?((.+?)(\:(.+?))?\@)?([a-z0-9\-\.]+)(\:(\d+))?(\/.+)$/i) {
		# URL parsing failed
		# TODO: Warning should go to a user popup not to the text console
		warn 'Unable to parse '.$url;
		return;
	}


	# Login data
	if (defined($2)) {
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

	if (! defined($self->{_pass})) {
		# TODO: Ask the user for a password
	}

	# TODO: Handle aborted/timed out connections

	# Create FTP object and connection
	$self->{_ftp} = Net::FTP->new(
		Host => $self->{_host},
		Port => $self->{_port},
		Timeout => 120, # TODO: Make this configurable
		Passive => 1, # TODO: Make this configurable
#		Debug => 3, # Enable for FTP-debugging to STDERR
	);

	if (!defined($self->{_ftp})) {
		# TODO: Warning should go to a user popup not to the text console
		warn 'Error connecting to '.$self->{_host}.':'.$self->{_port}.': '.$@;
		return;
	}

	if ( ! $self->{_ftp}->login($self->{_user},$self->{_pass})) {
		# TODO: Warning should go to a user popup not to the text console
		warn 'Error logging in on '.$self->{_host}.':'.$self->{_port}.': '.$@;
		return;
	}

	$self->{_ftp}->binary;

	$self->{protocol} = 'ftp'; # Should not be overridden

	$self->{_file_temp} = File::Temp->new( UNLINK => 1 );
	$self->{_tmpfile} = $self->{_file_temp}->filename;


	return $self;
}

sub can_run {
	return 0;
}

sub size {
	my $self = shift;
	return $self->{_ftp}->size($self->{_file});
}

sub _todo_mode {
	my $self = shift;
	return 33024; # Currently fixed: read-only textfile
}

sub _todo_mtime {
	my $self = shift;

	# The file-changed-on-disk - function requests this frequently:
	if ( defined( $self->{_cached_mtime_time} ) and ( $self->{_cached_mtime_time} > ( time - 60 ) ) ) {
		return $self->{_cached_mtime_value};
	}

	require HTTP::Date; # Part of LWP which is required for this module but not for Padre
	my ( $Content, $Result ) = $self->_request('HEAD');

	$self->{_cached_mtime_value} = HTTP::Date::str2time( $Result->header('Last-Modified') );
	$self->{_cached_mtime_time}  = time;

	return $self->{_cached_mtime_value};
}

sub exists {
	my $self = shift;
	return $self->size ? 1 : 0;
}

sub basename {
	my $self = shift;

	my $name = $self->{_file};
	$name =~ s/^.*\///;
	
	return $name;
}

sub dirname {
	my $self = shift;

	my $dir = $self->{_file};
	$dir =~ s/\/[^\/]*$//;
	
	return $dir;
}

sub read {
	my $self = shift;
	print STDERR $self->{_host}.': '.$self->{_file}.' --> '.$self->{_tmpfile}."\n";
	$self->{_ftp}->get($self->{_file},$self->{_tmpfile}) or warn $@;
	open my $tmpfh,$self->{_tmpfile};
	return join('',<$tmpfh>);
}

sub readonly {
	# Temporary until writing is implemented
	return 0;
}

sub write {
	my $self    = shift;
	my $content = shift;
	my $encode  = shift || ''; # undef encode = default, but undef will trigger a warning

	my $fh;
	if ( !open $fh, ">$encode", $self->{_tmpfile} ) {
		$self->{error} = $!;
		return 0;
	}
	print {$fh} $content;
	close $fh;
	
	$self->{_ftp}->put($self->{_tmpfile},$self->{_file}) or warn $@;

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

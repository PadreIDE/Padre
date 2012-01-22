package Padre::File::HTTP;

use 5.008;
use strict;
use warnings;

use Padre::Constant ();
use Padre::File     ();
use Padre::Logger;

our $VERSION = '0.94';
our @ISA     = 'Padre::File';

my $WRITE_WARNING_DONE = 0;

sub new {
	my $class = shift;

	# Don't add a new overall-dependency to Padre:
	eval { require LWP::UserAgent; };
	if ($@) {

		# TO DO: This should be an error popup to the user, not a shell window warning
		warn 'LWP::UserAgent is not installed, Padre::File::HTTP currently depends on it.';
		return;
	}

	my $self = bless { filename => $_[0], UA => LWP::UserAgent->new }, $class;

	# Using the config is optional, tests and other usages should run without
	my $config = eval { return Padre->ide->config; };
	if ( defined($config) ) {
		$self->{_timeout} = $config->file_http_timeout;
	} else {

		# Use defaults if we have no config
		$self->{_timeout} = 30;
	}

	$self->{protocol} = 'http'; # Should not be overridden
	$self->{UA}->timeout( $self->{_timeout} );
	$self->{UA}->env_proxy unless Padre::Constant::WIN32;
	return $self;
}

sub _request {
	my $self    = shift;
	my $method  = shift || 'GET';
	my $URL     = shift || $self->{filename};
	my $content = shift;

	TRACE( sprintf( Wx::gettext('Sending HTTP request %s...'), $URL ) ) if DEBUG;

	my $HTTP_req = HTTP::Request->new( $method, $URL, undef, $content );

	my $result = $self->{UA}->request($HTTP_req);

	if ( $result->is_success ) {
		if (wantarray) {
			return $result->content, $result;
		} else {
			return $result->content;
		}
	} else {
		if (wantarray) {
			return ( undef, $result );
		} else {
			return;
		}
	}
}

sub can_run {
	return ();
}

sub size {
	my $self = shift;
	my ( $content, $result ) = $self->_request('HEAD');
	return $result->header('Content-Length');
}

sub mode {
	my $self = shift;
	return 33024; # Currently fixed: read-only textfile
}

sub mtime {
	my $self = shift;

	# The file-changed-on-disk - function requests this frequently:
	if ( defined( $self->{_cached_mtime_time} ) and ( $self->{_cached_mtime_time} > ( time - 60 ) ) ) {
		return $self->{_cached_mtime_value};
	}

	require HTTP::Date; # Part of LWP which is required for this module but not for Padre
	my ( $content, $result ) = $self->_request('HEAD');

	$self->{_cached_mtime_value} = HTTP::Date::str2time( $result->header('Last-Modified') );
	$self->{_cached_mtime_time}  = time;

	return $self->{_cached_mtime_value};
}

sub exists {
	my $self = shift;
	my ( $content, $result ) = $self->_request('HEAD');
	return 1 if $result->code == 200;
	return ();
}

sub basename {
	my $self = shift;

	# Cut the protocol and hostname part or fail if this is no expected syntax:
	$self->{filename} =~ /https?\:\/\/.+?\/(.+)/i or return 'index.html';
	my $basename = $1;

	# Cut any arguments and anchor-parts
	$basename =~ s/[\#\?].+$//;

	# Cut the path including the last /
	$basename =~ s/^.+\///;

	# Return a HTTP default in case the URL was http://www.google.de/
	return $basename || 'index.html';
}

sub dirname {
	my $self = shift;

	# Cut the protocol and hostname part or fail if this is no expected syntax:
	$self->{filename} =~ /^(https?\:\/\/.+?\/)[^\/\#\?]+?([\#\?].*)?$/i or return $self->{filename};
	return $1;
}

sub servername {
	my $self = shift;

	# Cut the protocol and hostname part or fail if this is no expected syntax:
	$self->{filename} =~ /^https?\:\/\/(.+?)\/[^\/\#\?]+?([\#\?].*)?$/i or return undef;
	return $1;
}

sub read {
	my $self = shift;
	return scalar( $self->_request );
}

sub readonly {
	return 1;
}

sub write {
	my $self    = shift;
	my $content = shift;
	my $encode  = shift || ''; # undef encode = default, but undef will trigger a warning

	if ( !$WRITE_WARNING_DONE ) {
		Padre::Current->main->error(
			Wx::gettext(
				      "You are going to write a file using HTTP PUT.\n"
					. "This is highly experimental and not supported by most servers."
			)
		);
		$WRITE_WARNING_DONE = 1;
	}

	( $content, my $result ) = $self->_request( 'PUT', undef, $content );
	return 1 if $result->code == 200 or $result->code == 201;

	return 0;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

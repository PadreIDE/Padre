package Padre::Document::Perl::Starter::Style;

use 5.011;
use strict;
use warnings;
use Params::Util ();

our $VERSION    = '1.00';
our $COMPATIBLE = '0.97';

my %DEFAULT = (
	bin_perl     => '/usr/bin/perl',
	use_perl     => '',
	use_strict   => 1,
	use_warnings => 1,
	version_line => '',
);





######################################################################
# Constructors

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

sub from_file {
	my $class = shift;
	my $file  = shift;

	require Padre::Util;
	my $text = Padre::Util::slurp($file);

	return $class->from_text( $text, @_ );
}

sub from_document {
	my $class    = shift;
	my $document = shift;
	my $text     = $document->text_get;

	return $class->from_text( $text, @_ );
}

sub from_text {
	my $class = shift;
	my $text  = shift;
	my %style = @_ ? ( default => shift ) : ();

	if ( $text =~ /^\#\!(\N+)/ ) {
		$style{bin_perl} = $1;
	}

	# Capture the use/require usage as well as the number
	if ( $text =~ /^(use|require\s+[\d\.]+);/m ) {
		$style{use_perl} = $1;
	}

	if ( $text =~ /^use strict;/m ) {
		$style{use_strict} = 1;
	}

	if ( $text =~ /^use warnings;/m ) {
		$style{use_warnings} = 1;
	}
	
	# Capture several possible variants of the verion declaration
	if ( $text =~ /^(our\s+\$VERSION\s*=.+)/m ) {
		$style{version_line} = $1;
	}

	return $class->new(%style);
}





######################################################################
# Style Methods

sub bin_perl {
	$_[0]->_style('bin_perl');
}

sub use_perl {
	$_[0]->_style('use_perl');
}

sub use_strict {
	$_[0]->_style('use_strict');
}

sub use_warnings {
	$_[0]->_style('use_warnings');
}

sub version_line {
	$_[0]->_style('version_line');
}

sub _style {
	my $self = shift;
	my $name = shift;
	if ( defined $self->{$name} ) {
		return $self->{$name};
	}
	if ( $self->{default} ) {
		return $self->{default}->$name();
	}
	return $DEFAULT{$name};
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

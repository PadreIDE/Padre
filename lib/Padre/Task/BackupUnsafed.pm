package Padre::Task::BackupUnsafed;

use 5.008;
use strict;
use warnings;

use YAML::Tiny ();
use File::Spec ();

use Padre::Task     ();
use Padre::Constant ();
use Padre::Logger;

our $VERSION = '0.89';
our @ISA     = 'Padre::Task';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	return $self;
}





######################################################################
# Padre::Task Methods

# Fetch the state data at the last moment, to maximise accuracy.
sub prepare {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	# Save the list of open files
	require Padre::Current;
	$self->{changed} = [
		map {
			      warn $_->filename . "\t" 
				. $_->is_modified . "\t"
				. $_->is_new; ( $_->is_modified and !$_->is_new )
				? {
				filename => $_->filename,
				content  => $_->text_get
				}
				: ();
			} Padre::Current->main->documents
	];

	return 1;
}

sub run {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	my $yaml = YAML::Tiny->new;

	push @{$yaml}, @{ $self->{changed} };

	$yaml->write( File::Spec->catfile( Padre::Constant::CONFIG_DIR, 'unsafed.yml' ) );

	return 1;
}

sub finish {
	TRACE( $_[0] ) if DEBUG;
	my $self = shift;

	return 1;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

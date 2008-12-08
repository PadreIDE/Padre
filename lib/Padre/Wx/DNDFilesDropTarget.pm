package Padre::Wx::DNDFilesDropTarget;

use strict;
use warnings;

our $VERSION = '0.20';

use Wx::DND;
use base qw(Wx::FileDropTarget);

sub new {
	my ($class, $app) = @_;
	
	my $self = $class->SUPER::new( );
	$self->{APP} = $app;
	
	return $self;
}

sub OnDropFiles {
	my( $self, $x, $y, $files ) = @_;
	
	my $app = $self->{APP};

	#Wx::LogMessage( "Dropped files at ($x, $y)" );
	foreach my $i ( @$files ) {
		$app->setup_editor($i);
	}

	return 1;
}

1;

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

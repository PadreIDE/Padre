package Padre::Wx::Directory::Task;

# This is a simple flexible task that fetches lists of file names
# (but does not look inside of those files)

use 5.008;
use strict;
use warnings;
use Padre::Wx::Directory::Path ();

our $VERSION = '0.64';





######################################################################
# Constructor

sub new {
	my $self = shift->SUPER::new(@_);

	# Automatic project integration
	if ( exists $self->{project} ) {
		$self->{root} = $self->{project}->root;
	}

	return $self;
}





######################################################################
# Padre::Task Methods

sub run {
	my $self  = shift;
	my @files = ();
	my @queue = ( $self->{root} );

	# Recursively scan for files
	local *DIR;
	while ( @queue ) {
		my $directory = shift @queue;
		opendir DIR, $directory or die "opendir($directory): $!";
		my @buffer = readdir DIR;
		closedir DIR;

		
	}

	return 1;
}

1;

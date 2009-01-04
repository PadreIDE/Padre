package Padre::Current;

# A context object, for centralising the concept of what is "current"

use strict;
use warnings;
use Exporter     ();
use Params::Util qw{_INSTANCE};

our $VERSION   = '0.22';
our @ISA       = 'Exporter';
our @EXPORT_OK = '_CURRENT';





#####################################################################
# Exportable Functions

sub _CURRENT {
	_INSTANCE($_[0], 'Padre::Current') or Padre::Current->new;
}





#####################################################################
# Constructor

sub new {
	my $class = shift;
	bless { @_ }, $class;
}





#####################################################################
# Context Methods

sub document {
	my $self = ref($_[0]) ? $_[0] : $_[0]->new;
	unless ( exists $self->{document} ) {
		require Padre::Documents;
		$self->{document} = Padre::Documents->current;
	}
	return $self->{document};
}

1;

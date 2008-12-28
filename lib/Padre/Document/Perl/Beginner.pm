package Padre::Document::Perl::Beginner;

use strict;
use warnings;

sub new {
	return bless {}, shift;
}
sub error {
	return $_[0]->{error};
}


sub check {
	my ($self, $text) = @_;
	$self->{error} = '';
	
	
	if ($text =~ m{split([^;]+);}) {
		my $cont = $1;
		if ($cont =~ m{\@}) {
			$self->{error} = "The second parameter of split is a string, not an array";
			return;
		}
	}
	return 1;
}


1;

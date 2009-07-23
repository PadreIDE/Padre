package Padre::Document::Perl::Beginner;

use strict;
use warnings;

our $VERSION = '0.41';

=head1 NAME

Padre::Document::Perl::Beginner - naive implementation of some beginner specific error checking

=head1 SYNOPSIS

  use Padre::Document::Perl::Beginner;
  my $b = Padre::Document::Perl::Beginner->new;
  if (not $b->check($data)) {
      warn $b->error;
  }

=head1 DESCRIPTION

This is a naive implementation. It needs to be replaces by one using L<PPI>.

In Perl 5 there are lots of pitfals the unaware, especially
the beginner can easily fall in.
This module provides a method called C<check> that can check a perl script 
(provided as parameter as a single string) and recognize problematic code.

=head1 Examples

  split /,/, @data;

Here @data is in scalar context returning the number of elemenets. Spotted in this form:

  split /,/, @ARGV;


See L<http://padre.perlide.org/ticket/52> and L<http://www.perlmonks.org/?node_id=728569>


=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=head1 WARRANTY

There is no warranty whatsoever.

=cut

sub new {
	return bless {}, shift;
}

sub error {
	return $_[0]->{error};
}

sub check {
	my ( $self, $text ) = @_;
	$self->{error} = '';

	if ( $text =~ m{split([^;]+);} ) {
		my $cont = $1;
		if ( $cont =~ m{\@} ) {
			$self->{error} = "The second parameter of split is a string, not an array";
			return;
		}
	}
	if ( $text =~ /use\s+warning\s*;/ ) {
		$self->{error} = "You need to write use warnings (with an s at the end) and not use warning.";
		return;
	}

	return 1;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

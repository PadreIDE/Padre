package Padre::Document::Perl::Beginner;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.46';

=head1 NAME

Padre::Document::Perl::Beginner - naive implementation of some beginner specific error checking

=head1 SYNOPSIS

  use Padre::Document::Perl::Beginner;
  my $b = Padre::Document::Perl::Beginner->new;
  if (not $b->check($data)) {
      warn $b->error;
  }

=head1 DESCRIPTION

This is a naive implementation. It needs to be replaced by one using L<PPI>.

In Perl 5 there are lots of pitfals the unaware, especially
the beginner can easily fall in. While some might expect the perl 
compiler itself would catch those it does not (yet ?) do it. So we took the 
initiative and added a beginners mode to Padre in which these extra issues
are checked. Some are real problems that would trigger a an error anyway
we just make them a special case with a more specific error message.
(e.g. use warning; without the trailing s)
Others are valid code that can be useful in the hands of a master but that
are poisinous when written by mistake by someone who does not understand them.
(eg. if ($x = /value/) { } ).


This module provides a method called C<check> that can check a perl script 
(provided as parameter as a single string) and recognize problematic code.

=head1 Examples

See L<http://padre.perlide.org/ticket/52> and L<http://www.perlmonks.org/?node_id=728569>

=head1 Cases

=over 4

=cut


sub new {
	return bless {}, shift;
}

sub error {
	return $_[0]->{error};
}

sub check {
	my ( $self, $text ) = @_;
	$self->{error} = undef;

=item *

  split /,/, @data;

Here @data is in scalar context returning the number of elemenets. Spotted in this form:

  split /,/, @ARGV;

=cut

	if ( $text =~ m{split([^;]+);} ) {
		my $cont = $1;
		if ( $cont =~ m{\@} ) {
			$self->{error} = "The second parameter of split is a string, not an array";
			return;
		}
	}

=item *

  use warning;
  
s is missing at the end.

=cut

	if ( $text =~ /use\s+warning\s*;/ ) {
		$self->{error} = "You need to write use warnings (with an s at the end) and not use warning.";
		return;
	}

=item *

TBD.

=cut

	if ( $text =~ /map[\s\t\r\n]*\{.+?\}[\s\t\r\n]*\(.+?\)[\s\t\r\n]*\,/ ) {
		$self->{error} = "map (),x uses x also as list value for map.";
		return;
	}

=item *

Warn about Perl-standard package names being reused

  package DB;

=cut

	if ( $text =~ /package DB[\;\:]/ ) {
		$self->{error} = "This file uses the DB-namespace which is used by the Perl Debugger.";
		return;
	}

=item *

  $x = chomp $y;
  
=cut

	if ( $text =~ /\=[\s\t\r\n]*chomp\b/ ) {
		$self->{error} = "chomp doesn't return the chomped value, it modifies the variable given as argument.";
		return;
	}

=item *

TBD.

=cut

	if ( $text =~ /map[\s\t\r\n]*\{[\s\t\r\n]*(\$_[\s\t\r\n]*\=\~[\s\t\r\n]*)?s\// ) {
		$self->{error} = "Substitute (s///) doesn't return the changed value even if map.";
		return;
	}

=item *

  <@X>

=cut

	if ( $text =~ /\(\<\@\w+\>\)/ ) {
		$self->{error} = "(<\@Foo>) is Perl6 syntax and usually not valid in Perl5.";
		return;
	}

=item *

  if ($x = /bla/) {
  }

=cut

	if ( $text =~ /if[\s\t\r\n]*\(?[\$\s\t\r\n\w]+\=[\s\t\r\n\$\w]/ ) {
		$self->{error} = "A single = in a if-condition is usually a typo, use == or eq to compare.";
		return;
	}

=item *

Pipe | in open() not at the end or the beginning.

=cut

	if ( $text =~ /open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*(\,.+?)?\,?([\"\'])[^\2]+?\|[^\2]+?\2/ ) {
		$self->{error} = "Using a | char in open without a | at the beginning or end is usually a typo.";
		return;
	}

=item *

  open($ph, "|  something |");

=cut

	if ( $text =~ /open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*\,(.+?\,)?([\"\'])\|[^\2]+?\|\2/ ) {
		$self->{error} = "You can't use open to pipe to and from a command at the same time.";
		return;
	}

=item *

Regex starting witha a quantifyer

=cut

	if ( $text =~ /\=\~[\s\t\r\n]*\/\^?[\+\*\?\{]/ ) {
		$self->{error} =
			"A regular expression starting with a quantifier ( + * ? { ) doesn't make sense, you may want to escape it with a \\.";
		return;
	}

=item *

  } else if {

=cut

	if ( $text =~ /else[\s\t\r\n]+if/ ) {
		$self->{error} = "'else if' is wrong syntax, correct if 'elsif'.";
		return;
	}

=item *

 } elseif {
 	
=cut

	if ( $text =~ /elseif/ ) {
		$self->{error} = "'elseif' is wrong syntax, correct if 'elsif'.";
		return;
	}

	return 1;
}

=pod

=back

=head1 COPYRIGHT

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=head1 WARRANTY

There is no warranty whatsoever.

=cut

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

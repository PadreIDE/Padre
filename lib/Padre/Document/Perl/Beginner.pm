package Padre::Document::Perl::Beginner;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.47';

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
	my $class = shift;

	return bless {@_}, $class;
}

sub error {
	return $_[0]->{error};
}

sub _report {
	my $self    = shift;
	my $text    = shift;
	my @samples = @_;

	my $document = $self->{document};
	my $editor   = $document->{editor};

	my $prematch = $1 || '';
	my $error_start_position = length($prematch);

	my $line = $editor->LineFromPosition( $error_start_position );
	++$line; # Editor starts counting at 0

	# These are two lines to enable the translators to use argument numbers:
	$self->{error} = Wx::gettext( sprintf( 'Line %d: ', $line ) ) . Wx::gettext( sprintf( $text, @_ ) );

	return;
}

sub check {
	my ( $self, $text ) = @_;

	# TODO: Change this back to undef:
	$self->{error} = '';

=item *

  split /,/, @data;

Here @data is in scalar context returning the number of elemenets. Spotted in this form:

  split /,/, @ARGV;

=cut

	if ( $text =~ m/^(.*?)split([^;]+);/s ) {
		my $cont = $1;
		if ( $cont =~ m{\@} ) {
			$self->_report("The second parameter of split is a string, not an array");
			return;
		}
	}

=item *

  use warning;
  
s is missing at the end.

=cut

	if ( $text =~ /^(.*?)use\s+warning\s*;/s ) {
		$self->_report("You need to write use warnings (with an s at the end) and not use warning.");
		return;
	}

=item *

  map { $_; } (@items),$extra_item;

is the same as

  map { $_; } (@items,$extra_item);

but you usually want

  (map { $_; } (@items)),$extra_item;

which means: map all @items and them add $extra_item without map'ing it.

=cut

	if ( $text =~ /^(.*?)map[\s\t\r\n]*\{.+?\}[\s\t\r\n]*\(.+?\)[\s\t\r\n]*\,/s ) {
		$self->_report("map (),x uses x also as list value for map.");
		return;
	}

=item *

Warn about Perl-standard package names being reused

  package DB;

=cut

	if ( $text =~ /^(.*?)package DB[\;\:]/s ) {
		$self->_report("This file uses the DB-namespace which is used by the Perl Debugger.");
		return;
	}

=item *

  $x = chomp $y;
  print chomp $y;
  
=cut

	# TODO: Change this to
	#	if ( $text =~ /[^\{\;][\s\t\r\n]*chomp\b/ ) {
	# as soon as this module could set the cursor to the occurence line
	# because it may trigger a higher amount of false positives.
	if ( $text =~ /^(.*?)(print|[\=\.\,])[\s\t\r\n]*chomp\b/s ) {
		$self->_report("chomp doesn't return the chomped value, it modifies the variable given as argument.");
		return;
	}

=item *

  map { s/foo/bar/; } (@items);

This returns an array containing true or false values (s/// - return value).

Use

  map { s/foo/bar/; $_; } (@items);

to actually change the array via s///.

=cut

	if ( $text =~ /^(.*?)map[\s\t\r\n]*\{[\s\t\r\n]*(\$_[\s\t\r\n]*\=\~[\s\t\r\n]*)?s\//s ) {
		$self->_report("Substitute (s///) doesn't return the changed value even if map.");
		return;
	}

=item *

  <@X>

=cut

	if ( $text =~ /^(.*?)\(\<\@\w+\>\)/s ) {
		$self->_report("(<\@Foo>) is Perl6 syntax and usually not valid in Perl5.");
		return;
	}

=item *

  if ($x = /bla/) {
  }

=cut

	if ( $text =~ /^(.*?)if[\s\t\r\n]*\(?[\$\s\t\r\n\w]+\=[\s\t\r\n\$\w]/s ) {
		$self->_report("A single = in a if-condition is usually a typo, use == or eq to compare.");
		return;
	}

=item *

Pipe | in open() not at the end or the beginning.

=cut

	if ( ( $text =~ /^(.*?)open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*(\,.+?)?[\s\t\r\n]*\,[\s\t\r\n]*?([\"\'])(.*?)\|(.*?)\2/ )
		and ( length($4) > 0 )
		and ( length($5) > 0 ) )
	{
		print STDERR join(',',map { "[[$_]]"; }($1,$2,$3,$4,$5,$6))."\n";
		$self->_report("Using a | char in open without a | at the beginning or end is usually a typo.");
		return;
	}

=item *

  open($ph, "|  something |");

=cut

	if ( $text =~ /^(.*?)open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*\,(.+?\,)?([\"\'])\|.+?\|\2/s ) {
		$self->_report("You can't use open to pipe to and from a command at the same time.");
		return;
	}

=item *

Regex starting witha a quantifier such as 

  /+.../

=cut

	if ( $text =~ m/^(.*?)\=\~  [\s\t\r\n]*  \/ \^?  [\+\*\?\{] /xs ) {
		$self->_report(
			"A regular expression starting with a quantifier ( + * ? { ) doesn't make sense, you may want to escape it with a \\."
		);
		return;
	}

=item *

  } else if {

=cut

	if ( $text =~ /^(.*?)else[\s\t\r\n]+if/s ) {
		$self->_report("'else if' is wrong syntax, correct if 'elsif'.");
		return;
	}

=item *

 } elseif {
 	
=cut

	if ( $text =~ /^(.*?)elseif/s ) {
		$self->_report("'elseif' is wrong syntax, correct if 'elsif'.");
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

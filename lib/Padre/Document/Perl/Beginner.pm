package Padre::Document::Perl::Beginner;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.49';

=head1 NAME

Padre::Document::Perl::Beginner - naive implementation of some beginner specific error checking

=head1 SYNOPSIS

  use Padre::Document::Perl::Beginner;
  my $beginner = Padre::Document::Perl::Beginner->new;
  if (not $beginner->check($data)) {
      warn $beginner->error;
  }

=head1 DESCRIPTION

This is a naive implementation. It needs to be replaced by one using L<PPI>.

In Perl 5 there are lots of pitfalls the unaware, especially
the beginner can easily fall in. While some might expect the perl 
compiler itself would catch those it does not (yet ?) do it. So we took the 
initiative and added a beginners mode to Padre in which these extra issues
are checked. Some are real problems that would trigger an error anyway
we just make them a special case with a more specific error message.
(e.g. use warning; without the trailing s)
Others are valid code that can be useful in the hands of a master but that
are poisonous when written by mistake by someone who does not understand them.
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

	my $line = $editor->LineFromPosition($error_start_position);
	++$line; # Editor starts counting at 0

	# These are two lines to enable the translators to use argument numbers:
	$self->{error} = Wx::gettext( sprintf( 'Line %d: ', $line ) ) . Wx::gettext( sprintf( $text, @_ ) );

	return;
}

sub check {
	my ( $self, $text ) = @_;

	$self->{error} = undef;

	# Fast exits if there is nothing to check:
	return 1 if !defined($text);
	return 1 if $text eq '';

	my $config = Padre->ide->config;

	# Cut POD parts out of the text
	$text =~ s/(^|[\r\n])(\=(pod|item|head\d)\b.+?[\r\n]\=cut[\r\n])/$1.(" "x(length($2)))/seg;

	# TODO: Replace all comments by whitespaces, otherwise they could mix up some tests

=item *

  split /,/, @data;

Here @data is in scalar context returning the number of elemenets. Spotted in this form:

  split /,/, @ARGV;

=cut

	if ( $config->begerror_split and $text =~ m/^([\x00-\xff]*?)split([^;]+);/ ) {
		my $cont = $2;
		if ( $cont =~ m{\@} ) {
			$self->_report("The second parameter of split is a string, not an array");
			return;
		}
	}

=item *

  use warning;
  
s is missing at the end.

=cut

	if ( $config->begerror_warning and $text =~ /^([\x00-\xff]*?)use\s+warning\s*;/ ) {
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

	if ( $config->begerror_map and $text =~ /^([\x00-\xff]*?)map[\s\t\r\n]*\{.+?\}[\s\t\r\n]*\(.+?\)[\s\t\r\n]*\,/ ) {
		$self->_report("map (),x uses x also as list value for map.");
		return;
	}

=item *

Warn about Perl-standard package names being reused

  package DB;

=cut

	if ( $config->begerror_DB and $text =~ /^([\x00-\xff]*?)package DB[\;\:]/ ) {
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

	# (Ticket #675)

	if ( $config->begerror_chomp and $text =~ /^([\x00-\xff]*?)(print|[\=\.\,])[\s\t\r\n]*chomp\b/ ) {
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

	if (    $config->begerror_map2
		and $text =~ /^([\x00-\xff]*?)map[\s\t\r\n]*\{[\s\t\r\n]*(\$_[\s\t\r\n]*\=\~[\s\t\r\n]*)?s\// )
	{
		$self->_report("Substitute (s///) doesn't return the changed value even if map.");
		return;
	}

=item *

  <@X>

=cut

	if ( $config->begerror_perl6 and $text =~ /^([\x00-\xff]*?)\(\<\@\w+\>\)/ ) {
		$self->_report("(<\@Foo>) is Perl6 syntax and usually not valid in Perl5.");
		return;
	}

=item *

  if ($x = /bla/) {
  }

=cut

	if ( $config->begerror_ifsetvar and $text =~ /^([\x00-\xff]*?)if[\s\t\r\n]*\(?[\$\s\t\r\n\w]+\=[\s\t\r\n\$\w]/ ) {
		$self->_report("A single = in a if-condition is usually a typo, use == or eq to compare.");
		return;
	}

=item *

Pipe | in open() not at the end or the beginning.

=cut

	if ($config->begerror_pipeopen
		and ( $text
			=~ /^([\x00-\xff]*?)open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*(\,.+?)?[\s\t\r\n]*\,[\s\t\r\n]*?([\"\'])(.*?)\|(.*?)\3/
		)
		and ( length($4) > 0 )
		and ( length($5) > 0 )
		)
	{
		$self->_report("Using a | char in open without a | at the beginning or end is usually a typo.");
		return;
	}

=item *

  open($ph, "|  something |");

=cut

	if (    $config->begerror_pipe2open
		and $text =~ /^([\x00-\xff]*?)open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*\,(.+?\,)?([\"\'])\|.+?\|\3/ )
	{
		$self->_report("You can't use open to pipe to and from a command at the same time.");
		return;
	}

=item *

Regex starting witha a quantifier such as 

  /+.../

=cut

	if ( $config->begerror_regexq and $text =~ m/^([\x00-\xff]*?)\=\~  [\s\t\r\n]*  \/ \^?  [\+\*\?\{] /xs ) {
		$self->_report(
			"A regular expression starting with a quantifier ( + * ? { ) doesn't make sense, you may want to escape it with a \\."
		);
		return;
	}

=item *

  } else if {

=cut

	if ( $config->begerror_elseif and $text =~ /^([\x00-\xff]*?)else[\s\t\r\n]+if/ ) {
		$self->_report("'else if' is wrong syntax, correct if 'elsif'.");
		return;
	}

=item *

 } elseif {
 	
=cut

	if ( $config->begerror_elseif and $text =~ /^([\x00-\xff]*?)elseif/ ) {
		$self->_report("'elseif' is wrong syntax, correct if 'elsif'.");
		return;
	}

=item *

 close;
 	
=cut

	if ( $config->begerror_close and $text =~ /^(.*?[^>]?)close;/ ) { # don't match Socket->close;
		$self->_report("close; usually closes STDIN, STDOUT or something else you don't want.");
		return;
	}

	return 1;
}

=pod

=back

=head1 HOW TO ADD ANOTHER ONE

Please feel free to add as many checks as you like. This is done in three steps:

=head2 Add the test

Add one (or more) tests for this case to t/75-perl-beginner.t

The test should be successful when your supplied sample fails the check and
returns the correct errror message. As texts of error messages may change,
try to match a good part which allows identification of the message but
don't match the very exact text.

Tests could use either oneliners written as strings within the testfile or
external support files. There are samples for both ways in the test script.

=head2 Add the check

Add the check to the check-sub of this file (Document/Perl/Beginner.pm). There
are plenty samples here. Remember to add a sample (and maybe short description)
what would fail the test.

Run the test script to match your test case(s) to the new check.

=head2 Add the config option

Go to Config.pm, look for the beginner error checks configuration and add a new
setting for your new check there. It defaults to 1 (run the check), but a user
could turn it off by setting this to 0 within the Padre configuration file.

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

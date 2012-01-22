package Padre::Document::Perl::Beginner;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

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
the beginner can easily fall in. While some might expect the Perl
compiler itself would catch those it does not (yet ?) do it. So we took the
initiative and added a beginners mode to Padre in which these extra issues
are checked. Some are real problems that would trigger an error anyway
we just make them a special case with a more specific error message.
(e.g. C<use warning;> without the trailing s)
Others are valid code that can be useful in the hands of a master but that
are poisonous when written by mistake by someone who does not understand them.
(e.g. C<if ($x = /value/) { }> ).


This module provides a method called C<check> that can check a Perl script
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
	my $self     = shift;
	my $text     = shift;
	my $prematch = shift;
	my @samples  = @_;

	# The internal _text field is used instead of the document to make sure the
	# tests can also use it. We will also need to separate from the Padre document class
	# so this code can be factored out to a stand alone module

	#my $document = $self->{document};
	#my $editor   = $document->{editor};

	$prematch ||= '';
	my $error_start_position = length($prematch);

	#my $line = $editor->LineFromPosition($error_start_position);
	my @lines = split /[\r\n]/, substr( $self->{_text}, 0, $error_start_position ), -1;
	my $line = @lines || 1;

	#++$line; # Editor starts counting at 0

	# These are two lines to enable the translators to use argument numbers:
	$self->{error} = sprintf( Wx::gettext('Line %d: %s'), $line, sprintf( Wx::gettext($text), @_ ) );

	return;
}

sub check {
	my ( $self, $text ) = @_;

	$self->{error} = undef;

	$self->{_text} = $text;

	# Fast exits if there is nothing to check:
	return 1 if !defined($text);
	return 1 if $text eq '';

	my $config = Padre->ide->config;

	# Cut POD parts out of the text
	$text =~ s/(^|[\r\n])(\=(pod|item|head\d)\b.+?[\r\n]\=cut[\r\n])/$1.(" "x(length($2)))/seg;

	# TO DO: Replace all comments by whitespaces, otherwise they could mix up some tests

=item *

  split /,/, @data;

Here @data is in scalar context returning the number of elements. Spotted in this form:

  split /,/, @ARGV;

=cut

	if ( $config->lang_perl5_beginner_split and $text =~ m/^([\x00-\xff]*?)split([^;]+);/ ) {
		my $prematch = $1;
		my $cont     = $2;
		if ( $cont =~ m{\@} ) {
			$self->_report( "The second parameter of split is a string, not an array", $prematch );
			return;
		}
	}

=item *

  use warning;

s is missing at the end.

=cut

	if ( $config->lang_perl5_beginner_warning and $text =~ /^([\x00-\xff]*?)use\s+warning\s*;/ ) {
		$self->_report( "You need to write use warnings (with an s at the end) and not use warning.", $1 );
		return;
	}

=item *

  map { $_; } (@items),$extra_item;

is the same as

  map { $_; } (@items,$extra_item);

but you usually want

  (map { $_; } (@items)),$extra_item;

which means: map all C<@items> and them add C<$extra_item> without mapping it.

=cut

	if (    $config->lang_perl5_beginner_map
		and $text =~ /^([\x00-\xff]*?)map[\s\t\r\n]*\{.+?\}[\s\t\r\n]*\(.+?\)[\s\t\r\n]*\,/ )
	{
		$self->_report( "map (),x uses x also as list value for map.", $1 );
		return;
	}

=item *

Warn about Perl-standard package names being reused

  package DB;

=cut

	if ( $config->lang_perl5_beginner_debugger and $text =~ /^([\x00-\xff]*?)package DB[\;\:]/ ) {
		$self->_report( "This file uses the DB-namespace which is used by the Perl Debugger.", $1 );
		return;
	}

=item *

  $x = chomp $y;
  print chomp $y;

=cut

	# TO DO: Change this to
	#	if ( $text =~ /[^\{\;][\s\t\r\n]*chomp\b/ ) {
	# as soon as this module could set the cursor to the occurence line
	# because it may trigger a higher amount of false positives.

	# (Ticket #675)

	if ( $config->lang_perl5_beginner_chomp and $text =~ /^([\x00-\xff]*?)(print|[\=\.\,])[\s\t\r\n]*chomp\b/ ) {
		$self->_report( "chomp doesn't return the chomped value, it modifies the variable given as argument.", $1 );
		return;
	}

=item *

  map { s/foo/bar/; } (@items);

This returns an array containing true or false values (s/// - return value).

Use

  map { s/foo/bar/; $_; } (@items);

to actually change the array via s///.

=cut

	if (    $config->lang_perl5_beginner_map2
		and $text =~ /^([\x00-\xff]*?)map[\s\t\r\n]*\{[\s\t\r\n]*(\$_[\s\t\r\n]*\=\~[\s\t\r\n]*)?s\// )
	{
		$self->_report( "Substitute (s///) doesn't return the changed value even if map.", $1 );
		return;
	}

=item *

  <@X>

=cut

	if ( $config->lang_perl5_beginner_perl6 and $text =~ /^([\x00-\xff]*?)\(\<\@\w+\>\)/ ) {
		$self->_report( "(<\@Foo>) is Perl6 syntax and usually not valid in Perl5.", $1 );
		return;
	}

=item *

  if ($x = /bla/) {
  }

=cut

	# TODO if ( my $x = 23 ) {  should be OK I think, that is when we declare the variable with the if construct

	if (    $config->lang_perl5_beginner_ifsetvar
		and $text =~ m/\A([\x00-\xff]*?  ^[^#]*) if\b  \s*  (  \(\s*  (?<!my)\s*[\$\@\%]\w+  \s*=[^=~]  )/xsm )
	{
		$self->_report( "A single = in a if-condition is usually a typo, use == or eq to compare.", $1 );
		return;
	}

=item *

Pipe | in open() not at the end or the beginning.

=cut

	if ($config->lang_perl5_beginner_pipeopen
		and ( $text
			=~ /^([\x00-\xff]*?)open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*(\,.+?)?[\s\t\r\n]*\,[\s\t\r\n]*?([\"\'])(.*?)\|(.*?)\3/
		)
		and ( length($4) > 0 )
		and ( length($5) > 0 )
		)
	{
		$self->_report( "Using a | char in open without a | at the beginning or end is usually a typo.", $1 );
		return;
	}

=item *

  open($ph, "|  something |");

=cut

	if (    $config->lang_perl5_beginner_pipe2open
		and $text =~ /^([\x00-\xff]*?)open[\s\t\r\n]*\(?\$?\w+[\s\t\r\n]*\,(.+?\,)?([\"\'])\|.+?\|\3/ )
	{
		$self->_report( "You can't use open to pipe to and from a command at the same time.", $1 );
		return;
	}

=item *

Regular expression starting with a quantifier such as

  /+.../

=cut

	if ( $config->lang_perl5_beginner_regexq and $text =~ m/^([\x00-\xff]*?)\=\~  [\s\t\r\n]*  \/ \^?  [\+\*\?\{] /xs )
	{
		$self->_report(
			"A regular expression starting with a quantifier ( + * ? { ) doesn't make sense, you may want to escape it with a \\.",
			$1
		);
		return;
	}

=item *

  } else if {

=cut

	if ( $config->lang_perl5_beginner_elseif and $text =~ /^([\x00-\xff]*?)\belse\s+if\b/ ) {
		$self->_report( "'else if' is wrong syntax, correct if 'elsif'.", $1 );
		return;
	}

=item *

 } elseif {

=cut

	if ( $config->lang_perl5_beginner_elseif and $text =~ /^([\x00-\xff]*?)\belseif\b/ ) {
		$self->_report( "'elseif' is wrong syntax, correct if 'elsif'.", $1 );
		return;
	}

=item *

 close;

=cut

	if ( $config->lang_perl5_beginner_close and $text =~ /^(.*?[^>]?)close;/ ) { # don't match Socket->close;
		$self->_report( "close; usually closes STDIN, STDOUT or something else you don't want.", $1 );
		return;
	}

	return 1;
}

=pod

=back

=head1 HOW TO ADD ANOTHER ONE

Please feel free to add as many checks as you like. This is done in three steps:

=head2 Add the test

Add one (or more) tests for this case to F<t/75-perl-beginner.t>

The test should be successful when your supplied sample fails the check and
returns the correct error message. As texts of error messages may change,
try to match a good part which allows identification of the message but
don't match the very exact text.

Tests could use either one-liners written as strings within the test file or
external support files. There are samples for both ways in the test script.

=head2 Add the check

Add the check to the check-sub of this file (F<Document/Perl/Beginner.pm>). There
are plenty samples here. Remember to add a sample (and maybe short description)
what would fail the test.

Run the test script to match your test case(s) to the new check.

=head2 Add the configuration option

Go to F<Config.pm>, look for the beginner error checks configuration and add a new
setting for your new check there. It defaults to 1 (run the check), but a user
could turn it off by setting this to 0 within the Padre configuration file.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

#!/usr/bin/perl

use 5.014;
use strict;
use warnings;

# Turn on $OUTPUT_AUTOFLUSH
$| = 1;
use diagnostics;
use Data::Printer { caller_info => 1, colored => 1, };

my $wxSTC_STYLE_DEFAULT = text;
my $wxSTC_STYLE_BRACELIGHT;
my $wxSTC_STYLE_BRACEBAD;

my $wxSTC_PL_COMMENTLINE; #comment
my $wxSTC_PL_POD;
=pod

=head1 heading-1

=cut

my $wxSTC_PL_POD_VERB;
=pod

=over

=item * This is a bulleted list.

	#code is a pod verb
	my $wxSTC_PL_POD_VERB;

=back

=cut

my $wxSTC_PL_NUMBER = 1;

my $wxSTC_PL_WORD;
# use my sub for while else print return if chomp shift
say 'sample text';
print "sample text\n";
sub function {
	return;
}

my $wxSTC_PL_STRING = "string";
my $wxSTC_PL_CHARACTER = 'c';

my $wxSTC_PL_PUNCTUATION; # () [] {} 
my $wxSTC_PL_PREPROCESSOR; # what?
my $wxSTC_PL_OPERATOR; # + - * % ** . =~ x , ++ -- ||= != <=
my $wxSTC_PL_IDENTIFIER; #struct $variable @array %hash 

my $wxSTC_PL_SCALAR;
my @wxSTC_PL_ARRAY;
$wxSTC_PL_ARRAY[100]; # indexed
my %wxSTC_PL_HASH;
$wxSTC_PL_HASH{keyname};


my $wxSTC_PL_SYMBOLTABLE; # what?

my $wxSTC_PL_REGEX =~ m/ <:name>(pattern) /p;
my $wxSTC_PL_REGSUBST = s/^\s{1}//a;

my $wxSTC_PL_LONGQUOTE; # what?
my $wxSTC_PL_BACKTICKS = `back ticks`;

my $wxSTC_PL_DATASECTION; # see below

my $wxSTC_PL_HERE_DELIM = <<FOO;
sample text
FOO
my $wxSTC_PL_HERE_Q = <<'FOO';
sample text
FOO
my $wxSTC_PL_HERE_QQ = <<"FOO";
sample text
FOO
my $wxSTC_PL_HERE_QX = <<`FOO`;
sample text
FOO

my $wxSTC_PL_STRING_Q  = q( single quoted string literal );
my $wxSTC_PL_STRING_QQ = qq( double quoted string literal );
my $wxSTC_PL_STRING_QX = qx{ command };
my $wxSTC_PL_STRING_QR = qr/ sample text /;
my @wxSTC_PL_STRING_QW = qw( word list );

sub function_prototyped($$&) {
	
}

sub function_attrib : SomeAttributes(etc) {
	
}

format STDOUT =
@###   @.###   @##.###  @###   @###   ^####
42,   3.1415,  undef,    0, 10000,   undef
.


1;

__DATA__
sub foo::bar {23}
package baz;
sub dob {32}

__END__

=head1 LICENSE AND COPYRIGHT

Copyright 2008-2011 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl 5 itself.

The full text of the license can be found in the
LICENSE file included with this module.
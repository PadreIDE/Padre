#!/usr/bin/perl

use 5.014;
use strict;
use warnings;

# Turn on $OUTPUT_AUTOFLUSH
$| = 1;
use diagnostics;
use Data::Printer { caller_info => 1, colored => 1, };

my $STYLE_DEFAULT = text;
my $STYLE_BRACELIGHT;
my $STYLE_BRACEBAD;

my $PL_COMMENTLINE; #comment
my $PL_POD;
=pod

=head1 heading-1

=cut

my $PL_POD_VERB;
=pod

=over

=item * This is a bulleted list.

	#code is a pod verb
	my $PL_POD_VERB;

=back

=cut

my $PL_NUMBER = 1;

my $PL_WORD;
# use my sub for while else print return if chomp shift
say 'sample text';
print "sample text\n";
sub function {
	return;
}

my $PL_STRING = "string";
my $PL_CHARACTER = 'c';

my $PL_PUNCTUATION; # () [] {} 
my $PL_PREPROCESSOR; # not emitted by LexPerl, can we recycle it?
my $PL_OPERATOR; # + - * % ** . =~ x , ++ -- ||= != <=
my $PL_IDENTIFIER; #struct $variable @array %hash 

my $PL_SCALAR;
my @PL_ARRAY;
$PL_ARRAY[100]; # indexed
my %PL_HASH;
$PL_HASH{keyname};


my $PL_SYMBOLTABLE;
*Package::Foo::variable = 'blah';

my $PL_XLAT = tr/abc/xyz/;

my $PL_REGEX =~ m/ <:name>(pattern) /p;
my $PL_REGSUBST = s/^\s{1}//a;

my $PL_LONGQUOTE; # what?
my $PL_BACKTICKS = `back ticks`;

my $PL_DATASECTION; # see below

my $PL_HERE_DELIM = <<FOO;
sample text
FOO
my $PL_HERE_Q = <<'FOO';
sample text
FOO
my $PL_HERE_QQ = <<"FOO";
sample text
FOO
my $PL_HERE_QX = <<`FOO`;
sample text
FOO

my $PL_STRING_Q  = q( single quoted string literal );
my $PL_STRING_QQ = qq( double quoted string literal );
my $PL_STRING_QX = qx{ command };
my $PL_STRING_QR = qr/ sample text /;
my @PL_STRING_QW = qw( word list );

my $escaped = "Hello World\n";

sub function_prototyped($$&) {
	
}

sub function_attrib : SomeAttributes(etc) {
	
}

# what PL is lexing STDOUT?
format STDOUT =
@###   @.###   @##.###  @###   @###   ^####
42,   3.1415,  undef,    0, 10000,   undef
.

open( FILEHANDLE, '<' , 'data.txt' );
print FILEHANDLE "\r\n";


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
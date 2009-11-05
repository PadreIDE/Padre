#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 2;

use Padre::Document::Perl;

package main_mockup;

sub new { return bless {}, shift }

sub text_get {

	return <<'EOTEXT';
sub test1 {
}

sub test2 {}

#sub test3 {
#	my $self = shift;
#}

# sub test4 { }

&test2; # sub test5 {}

print "hello"; sub test6 {}

# hello sub test7 {}

sub test9 {} sub test10 {}

print sub test11 {}

$var =~ m#test#; sub test12 {}

$var2 = "testing the # character"; sub test13 {}

$var3 = "testing the \"#\" character again"; sub test14 {}

$var4 =~ s/change # to/ " /g; sub test15 {} $var4 =~ s/change # to/ " /g; sub test16 {}

$var5 = " s#change#string "; sub test17 {}

$var6 =~ s#sub test18 {}#sub test19 {}#

$var7 =~ s#sub test20 {}#sub #

$var8 =~ s#sub test21 {}#sub #; sub test22
{}

=head1

sub test23 {
	my $self = shift;
}

=cut

sub test24 {}

m{sub test25}

tr/sub test26//;

s(
	sub test27 {}
)()gx;

__END__
sub test28 {
	my $self = shift;
}
sub test29 {}


EOTEXT
}

package main;

my $main      = main_mockup->new;
my @functions = Padre::Document::Perl::get_functions($main);

my @expected = qw(test1 test2 test6 test9 test10 test12 test13 test14 test15 test16 test17 test22 test24);

is( scalar @functions, scalar @expected, "all valid subs should be detected" );

is_deeply( \@functions, [@expected], "find correct sub names" );

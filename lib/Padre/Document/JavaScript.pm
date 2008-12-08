package Padre::Document::JavaScript;

use 5.008;
use strict;
use warnings;
use Carp            ();
use Padre::Document ();
use YAML::Tiny      ();

our $VERSION = '0.20';
our @ISA     = 'Padre::Document';





#####################################################################
# Padre::Document::JavaScript Methods

#my $keywords;
#
#sub keywords {
#	unless ( defined $keywords ) {
#		$keywords = YAML::Tiny::LoadFile(
#			Padre::Util::sharefile( 'languages', 'perl5', 'javascript.yml' )
#		);
#	}
#	return $keywords;
#}

sub get_functions {
	my $self = shift;
	my $text = $self->text_get;
	return reverse sort $text =~ m{^function\s+(\w+(?:::\w+)*)}gm;
}

sub get_function_regex {
	my ( $self, $sub ) = @_;
	return qr{(^|\n)function\s+$sub\b};
}

sub comment_lines_str { return '//' }

1;

# Copyright 2008 Gabor Szabo and Fayland Lam
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

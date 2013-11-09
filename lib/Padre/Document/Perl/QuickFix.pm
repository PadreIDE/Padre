package Padre::Document::Perl::QuickFix;

use 5.008;
use strict;
use warnings;
use PPI             ();
use Padre::QuickFix ();

our $VERSION = '1.00';
our @ISA     = 'Padre::QuickFix';

# Returns the quick fix list
sub quick_fix_list {
	my ( $self, $document, $editor ) = @_;

	my @items = ();

	my $text = $editor->GetText;
	my $doc  = PPI::Document->new( \$text );
	$doc->index_locations;

	my @fixes = (
		'Padre::Document::Perl::QuickFix::StrictWarnings',
		'Padre::Document::Perl::QuickFix::IncludeModule',
	);

	foreach my $fix (@fixes) {
		(my $source = "$fix.pm") =~ s{::}{/}g;
		if (eval { require $source }) {
			push @items, $fix->new->apply( $doc, $document );
		} else {
			warn "failed to load $fix\n";
		}
	}


	return @items;
}

1;

__END__

=head1 NAME

Padre::Document::Perl::QuickFix - Padre Perl 5 Quick Fix 

=head1 DESCRIPTION

Perl 5 quick fix feature is implemented here

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

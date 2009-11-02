package Padre::QuickFixProvider::Perl;

use 5.008;
use strict;
use warnings;

use Padre::QuickFixProvider ();
use PPI                     ();

our $VERSION = '0.49';
our @ISA     = 'Padre::QuickFixProvider';

#
# Constructor.
# No need to override this
#
sub new {
	my ($class) = @_;

	# Create myself :)
	my $self = bless {}, $class;

	return $self;
}

#
# Returns the quick fix list
#
sub quick_fix_list {
	my ( $self, $document, $editor ) = @_;

	my @items = ();

	my $text = $editor->GetText;
	my $doc  = PPI::Document->new( \$text );
	$doc->index_locations;

	my @fixes = (
		'Padre::QuickFixProvider::Perl::StrictWarnings',
		'Padre::QuickFixProvider::Perl::IncludeModule',
	);

	foreach my $fix (@fixes) {
		eval "require $fix;";
		if ($@) {
			warn "failed to load $fix\n";
		} else {
			push @items, $fix->new->apply( $doc, $document );
		}
	}


	return @items;
}

1;

__END__

=head1 NAME

Padre::QuickFixProvider::Perl - Padre Perl 5 Quick Fix Provider

=head1 DESCRIPTION

Perl 5 quick fix feature is implemented here

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

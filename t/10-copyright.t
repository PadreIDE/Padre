use strict;
use warnings;

use Test::More;
use File::Find::Rule;

my @files = File::Find::Rule->name('*.pm')->file->in('lib');
plan tests => scalar @files;

# too simple way to check if we have copyright information on all files
# TODO: need to be improved

my $copyright = qr{# Copyright 2008-2009 The Padre development team as listed in Padre.pm\.\s*};
$copyright = qr{$copyright# LICENSE\s*};
$copyright = qr{$copyright# This program is free software; you can redistribute it and/or\s*};
$copyright = qr{$copyright# modify it under the same terms as Perl 5 itself.};

my $cp = qr{=head1 COPYRIGHT\s+};
$cp = qr{${cp}Copyright 2008-2009 The Padre development team as listed in Padre.pm\.\s*};
$cp = qr{${cp}This program is free software; you can redistribute\s*};
$cp = qr{${cp}it and/or modify it under the same terms as Perl itself.};


foreach my $file (@files) {
	my $content = slurp($file);
	ok( $content =~ qr{$copyright|$cp}, $file );
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die "Could not open '$file' $!'";
	local $/ = undef;
	return <$fh>;
}


use strict;
use warnings;

use Test::More;
use File::Find::Rule;

# Don't run tests for installs
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
}

my @files = File::Find::Rule->name('*.pm')->file->in('lib');
plan tests => ( scalar @files ) * 2;

# too simple way to check if we have copyright information on all files
# TODO: need to be improved

# Adding in a check that this year is in the copy right notice
my $this_year = (localtime)[5] + 1900;


# check we have a Copyright
my $copyright = qr{# Copyright 2008-\d{4} The Padre development team as listed in Padre.pm\.\s*};
$copyright = qr{$copyright# LICENSE\s*};
$copyright = qr{$copyright# This program is free software; you can redistribute it and/or\s*};
$copyright = qr{$copyright# modify it under the same terms as Perl 5 itself.};

my $cp = qr{=head1 COPYRIGHT(?: & LICENSE)?\s*};
$cp = qr{${cp}Copyright 2008-\d{4} The Padre development team as listed in Padre.pm\.\s*};
$cp = qr{${cp}This program is free software; you can redistribute\s*};
$cp = qr{${cp}it and/or modify it\s*under the same terms as Perl 5 itself.};


foreach my $file (@files) {
	my $content = slurp($file);
	ok( $content =~ qr{$copyright|$cp}, "Contains Copyright: $file" );
	ok( $content =~ qr{Copyright 2008-$this_year The Padre development team as listed in Padre.pm\.\s*},
		"Has 2008-$this_year in Copyright: $file"
	);
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die "Could not open '$file' $!'";
	local $/ = undef;
	return <$fh>;
}


use strict;
use warnings;
use Test::More;
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
use Test::Script;
use File::Find::Rule;

my @files = File::Find::Rule->file->name('*.pm')->in('lib');

plan( tests => scalar @files );

foreach my $file ( @files ) {
	my $module = $file;
	my $text = slurp($module);
	unlike($text, qr/(\r\n|\r)/m);
}

# Bail out if any of the tests failed
BAIL_OUT("Aborting test suite") if scalar grep {
	not $_->{ok}
} Test::More->builder->details;

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

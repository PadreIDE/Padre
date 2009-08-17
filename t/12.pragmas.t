#
# Tests all *.pm files for
# use 5.008;
# use strict;
# use warnings;
#

use strict;
use warnings;

use Test::More;
use File::Find::Rule;

my @files = File::Find::Rule->name('*.pm')->file->in('lib');
plan tests => scalar @files;

my $pragma = qr{use 5.008(005)?;\s*};
$pragma    = qr{${pragma}use strict;\s*};
$pragma    = qr{${pragma}use warnings;\s*};

foreach my $file ( @files ) {
	my $content = slurp($file);
	ok($content =~ qr{$pragma}, $file);
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die "Could not open '$file' $!'";
	local $/ = undef;
	return <$fh>;
}


use strict;
use warnings;
use Test::More;
BEGIN {
	unless ( $ENV{DISPLAY} or $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

use File::Find::Rule;
use t::lib::Padre;
use Padre::Util ();

my @files = File::Find::Rule->file->name('*.pm')->in('lib');

plan( tests => scalar @files );
foreach my $file ( @files ) {
	my $text = slurp($file);
	is(Padre::Util::newline_type($text), "UNIX");
}

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	binmode $fh;
	local $/ = undef;
	return <$fh>;
}

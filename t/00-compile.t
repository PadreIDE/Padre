use strict;
use warnings;
use Test::More;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

#use Test::NeedsDisplay ':skip_all';

use File::Find::Rule;
use File::Temp;

$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );

my $out = File::Spec->catfile($ENV{PADRE_HOME}, 'out.txt');
my $err = File::Spec->catfile($ENV{PADRE_HOME}, 'err.txt');

my @files = File::Find::Rule->file->name('*.pm')->in('lib');
plan tests => 2 * @files;
foreach my $file (@files) {
		system "$^X -c $file > $out 2>$err";
		my $out_data = slurp($out);
		is($out_data, '', "STDOUT of $file");

		my $err_data = slurp($err);
		is($err_data, "$file syntax OK\n", "STDERR of $file");
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

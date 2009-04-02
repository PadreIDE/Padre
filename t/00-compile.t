use strict;
use warnings;
use Test::Most;
BEGIN {
	if (not $ENV{DISPLAY} and not $^O eq 'MSWin32') {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}

#use Test::NeedsDisplay ':skip_all';
bail_on_fail;

use File::Find::Rule;
use File::Temp;
use POSIX qw(locale_h);

$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );

my $out = File::Spec->catfile($ENV{PADRE_HOME}, 'out.txt');
my $err = File::Spec->catfile($ENV{PADRE_HOME}, 'err.txt');

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');
plan tests => 2 * @files;
diag "Detected locale: " . setlocale(LC_CTYPE);

foreach my $file ( @files ) {
		my $module = $file;
		$module =~ s/[\/\\]/::/g;
		$module =~ s/\.pm$//;
#		if (($ENV{CPAN_SHELL_LEVEL} or $ENV{PERL5_CPAN_IS_RUNNING} or $ENV{PERL5_CPANPLUS_IS_RUNNING}) and $module eq 'Padre::CPAN') {
# always skip the CPAN testing as it talks too much on some systems
		if ($module eq 'Padre::CPAN') {
			Test::Most->builder->skip ("Cannot load CPAN shell under the CPAN shell") for 1..2;
			next;
		}
		system "$^X -e \"require $module; print 'ok';\" > $out 2>$err";
		my $err_data = slurp($err);
		is($err_data, '', "STDERR of $file");

		my $out_data = slurp($out);
		is($out_data, 'ok', "STDOUT of $file");
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

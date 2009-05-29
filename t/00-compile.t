use strict;
use warnings;
use Test::Most;
BEGIN {
	if ( not $ENV{DISPLAY} and not $^O eq 'MSWin32' ) {
		plan skip_all => 'Needs DISPLAY';
		exit 0;
	}
}
use Test::Script;
use File::Temp;
use File::Find::Rule;
use POSIX qw(locale_h);

#use Test::NeedsDisplay ':skip_all';
bail_on_fail;

$ENV{PADRE_HOME} = File::Temp::tempdir( CLEANUP => 1 );

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');

plan( tests => 2 * @files + 1 );
diag "Detected locale: " . setlocale(LC_CTYPE);

my $out = File::Spec->catfile($ENV{PADRE_HOME}, 'out.txt');
my $err = File::Spec->catfile($ENV{PADRE_HOME}, 'err.txt');

foreach my $file ( @files ) {
		my $module = $file;
		$module =~ s/[\/\\]/::/g;
		$module =~ s/\.pm$//;
		if ( $module eq 'Padre::CPAN' ) {
			foreach ( 1 .. 2 ) {
				Test::Most->builder->skip ("Cannot load CPAN shell under the CPAN shell");
			}
			next;
		}
		system "$^X -e \"require $module; print 'ok';\" > $out 2>$err";
		my $err_data = slurp($err);
		is($err_data, '', "STDERR of $file");

		my $out_data = slurp($out);
		is($out_data, 'ok', "STDOUT of $file");
}

#script_compiles_ok('dev.pl');
script_compiles_ok('script/padre');

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}
